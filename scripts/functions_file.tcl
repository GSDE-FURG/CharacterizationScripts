
# Authors: Rafael Schvittz and Marcelo Danigno 
#
# BSD 3-Clause License
#
# Copyright (c) 2020, Federal University of Rio Grande
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#File containing the implementation for each function used in characterization. Also contains boolean control variables.

set setIOasPorts 1
set bigVerilogs 1

proc truncateNum {num} {
	#Returns a string with any leading 0s removed.
	while {1} {
		set stringchar [string index $num end]
		if { ${stringchar} == "0" } {
			set num [ string range $num 0 [expr ( [string length $num] - 2 ) ] ]
		} elseif {${stringchar} == "." } {
			#If a decimal point is found: remove it and instantly return the string.
			set num [ string range $num 0 [expr ( [string length $num] - 2 ) ] ]
			return $num
		} else {
			return $num
		}
	}
}

proc dec2bin i {
    #Returns a list that represents a decimal number in binary, e.g. dec2bin 10 => 1 0 1 0 
    set res {} 
    set whitespace " "
    while {$i>0} {
        set res [expr {$i%2}]$whitespace$res
        set i [expr {$i/2}]
    }
    if {$res == {}} {set res 0}
    return $res
}

proc get_pincapmax {pin_nm reportPath} {
	#Uses OpenSTA to generate a report on the pin capacitance. It results in one line that can be in a few different formats depending on the liberty file.
	global sta_report_default_digits

	set libPinNm [[sta::get_pin_warn "pin" $pin_nm] liberty_port]
	set line [sta::port_capacitance_str $libPinNm $sta_report_default_digits]
	
	#One format is when there is only one capacitance in the liberty file, thus, the 1st word in the pin report will be a number.
	if { [ string is double -strict [lindex $line 0] ] } {	
		set pinCap [lindex $line 0]
	} elseif {[string first ":" [lindex $line 0] ] != -1} {	
		#However, that word could be an interval (string contains ":"). If so, we have to get the upper limit of the pin capacitance.
		set pinCap [lindex [split [lindex $line 0] ":"] 1]
	} else {
		#Another format is when there is a fall capacitance and a rise capacitance. In this case, we will return the higher one of the two.
		set r_cap [lindex $line 1]
		set f_cap [lindex $line 3]

		if {[string first ":" $r_cap ] != -1} {	
			#These values can also can be an interval (string contains ":"). 
			set r_cap [lindex [split $r_cap ":"] 1]
   			set f_cap [lindex [split $f_cap ":"] 1]
		}
		
		if {$r_cap > $f_cap} {
			set pinCap $r_cap
		} else {
			set pinCap $f_cap
		}
	}

	return $pinCap
}

proc get_power {inst_nm type reportPath} {
	#Returns the power for a specific instance using OpenSTA functions.
	set corner [sta::parse_corner keys]
	set inst_nm [sta::get_instances_error "-instances" $inst_nm]
	set pwr_list [sta::instance_power $inst_nm $corner]

	#Return the value based on the parameters used when the function was called. (switching, internal, leakage or total power)
	if {$type == "internal"} {
		return [lindex $pwr_list 0]
	} elseif {$type == "switching"} {
		return [lindex $pwr_list 1]
	} elseif {$type == "leakage"} {
		return [lindex $pwr_list 2]
	} elseif {$type == "total"} {
		return [lindex $pwr_list 3]
	} elseif {$type == "sum"} {
		return [expr [lindex $pwr_list 0] + [lindex $pwr_list 1] + [lindex $pwr_list 2] ]
	}
}

proc computeOutputSlew {inPin outPin currentInputSlew} {
	global slewInter
	global setIOasPorts
	#With the input slew set, we see its effects on the output pin (input of the rightmost FF).
	if { $setIOasPorts == 1 } {
		set object [sta::get_property_object_type "port" $outPin 1]
		set tr	[sta::port_property $object "actual_rise_transition_max"]
		set tf [sta::port_property $object "actual_fall_transition_max"]
	} else {
		set tr	[get_property -object_type pin $outPin actual_rise_transition_max]
		set tf [get_property -object_type pin $outPin actual_fall_transition_max]
	}
	#Computes the mean value between the rise and fall times of the output pin.
	set trans [expr ( ( $tr + $tf ) / 2 ) ]
	#Does some post-processing on the value and returns it.
	
	set outSlew [expr int(( $trans + $slewInter/2)/$slewInter)*$slewInter]
	return $outSlew
}

proc computeDelay {outPin} {
	#Uses OpenSTA to get the arrival time of a specific pin.
	global sta_report_default_digits
	set sigVertices [[sta::get_port_pin_error "pin" $outPin] vertices]
	set clockSig [[sta::clock_iterator] next]
	set riseTimes [$sigVertices "arrivals_clk_delays" rise $clockSig "rise" $sta_report_default_digits] 
	set riseValue [lindex $riseTimes 0]
	set rise2 [lindex $riseTimes 1]
	if {$rise2 > $riseValue} {
		set riseValue $rise2
	}
	return [format "%.3f" $riseValue ]
}

proc computeInputCapacitance {isPureWire currentLoad currentSolution currentWirelength solutionCounter reportPath} {
	global capacitancePerUnitLength
	global baseLoad
	global initial_cap_interval
	global cap_unit
	global final_cap_interval
	global bufPinIn
	global setupCharacterizationUnit

	#Wirelength for the leftmost net
	set netWirelength 0

	if { $isPureWire == 1 } {
		#In a pure-wire solution, the inputcapacitance is the sum of the current load with the capacitance of the net.
		set inPinCap $currentLoad
		set inNetCap [ expr $capacitancePerUnitLength * $currentWirelength ]
	} else {
		#In other solutions, the inputcapacitance is the sum of the pin capacitance of the leftmost buffer with the capacitance of the net. The wirelength of the net is obtained by using the currentSolution variable, which represents wire segments with their wirelength.  
		foreach instance $currentSolution {
			if { [ string is integer -strict $instance ] == 0 } {
				#Current segment is not a number (wire), which means it is the buffer that we have to get the pin capacitance from.
				set inPinCap [ get_pincapmax "buf_${solutionCounter}_0/${bufPinIn}" ${reportPath}] 
				break
			} else {
				#Current segment is a number (wire), which represents the wirelength of the leftmost net.
				set netWirelength $instance
			}
		}
		set inNetCap [ expr $capacitancePerUnitLength * $netWirelength ]
	}
	set inCap [ expr $inPinCap + $inNetCap ]
	#Does some post-processing on the value and returns it.
	if { $inCap <= $baseLoad } { 
		set inCap [ expr int(($inCap + ($initial_cap_interval/2)*$cap_unit)/($initial_cap_interval*$cap_unit))*($initial_cap_interval*$cap_unit) ]
	} else {
		set inCap [ expr int(($inCap + ($final_cap_interval/2)*$cap_unit)/($final_cap_interval*$cap_unit))*($final_cap_interval*$cap_unit) ]
	}
	return $inCap
}

proc computeWirePower {solutionCounter reportPath} {
	global setupWirelength
	global setupCharacterizationUnit
	global setIOasPorts
	
	if { $setIOasPorts == 1 } {
		return 0
	} else {
		#Computes the wire power (switching power). For that we use a spef file with load = 0.
		read_spef "${reportPath}/sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}l0.spef"
		set wirePower [ get_power "ffin_${solutionCounter}" switching ${reportPath}]
	}
	return $wirePower
}

proc computePower {solutionCounter isPureWire currentSolution currentLoad currentWirePower reportPath} {
	global setupWirelength
	global setupCharacterizationUnit
	global setIOasPorts
	global bigVerilogs
	global inputSlewList

	set buffCounter 0
	set totPower 0
	if { $bigVerilogs == 1 } {
		set currentWirePower [ get_power "testbuf_[string map {. d} ${currentLoad}]" switching ${reportPath}]
	} elseif { $setIOasPorts == 1 } {
		set_load $currentLoad out1
		set currentWirePower [ get_power "buf_1_0" switching ${reportPath}]
	}
	#If the current solution is pure wire, we only consider the wire power. However, if not, we add the total power of each buffer in the current solution.
	if { $isPureWire != 1 } {
		foreach instance $currentSolution {
			if { [ string is integer $instance ] == 0 } {
				set totalPower [ get_power "buf_${solutionCounter}_${buffCounter}" sum ${reportPath}]
				set totPower [ expr $totPower + $totalPower ]				
				incr buffCounter
			}
		}
	}
	#Add the wire power and the power for each buffer (if there is one) and returns the total power result.
	return [expr $totPower + $currentWirePower]
}

proc incrementBufferTopologies { instanceBufferType } {
	#Used to increment the instanceBufferType variable. It is used to change the type of buffer used in the current solution. Ex: {{1 0} {3 1}} changes into {{1 0} {3 2}}
	global bufferList
	
	set currentIndex 0
	#For pure-wire solutions, the instanceBufferType is blank, se we do not have to change the type of buffer used (there is none).
	if { [ llength $instanceBufferType ] == 0 } {
		return 0
	}
	while { 1 } {
		#Since instanceBufferType is a list of lists, here we change increment the value of instanceBufferType[currentIndex][1]
		lset instanceBufferType " $currentIndex  1 " [ expr [ lindex [ lindex $instanceBufferType $currentIndex ] 1 ] + 1 ]

		#If this value is higher than the number of possible buffers, we change the current buffer to 0 and increment another one.
		#Ex: If there are two buffer types and two buffers in the current solution ->
		#{{1 0} {3 0}} -> {{1 0} {3 1}} -h> {{1 1} {3 0}} -> {{1 1} {3 1}}
		#The arrow with the h in the middle represents when the number of possible buffers had an overflow, resulting in an increment in the next buffer.
		if { [ lindex [ lindex $instanceBufferType $currentIndex ] 1 ] >= [ llength  $bufferList ] } {
			lset instanceBufferType " $currentIndex  1 " 0
			incr currentIndex
		} else {
			#If no overflows occur, we can return the new buffer types.
			return $instanceBufferType
		}
		#If there is an overflow in the currentIndex variable, that means we tested all possible buffer types for the current topology
		if { $currentIndex >= [ llength $instanceBufferType ] } {
			return 0		
		}
	}
}

proc createSolutionTopology { solutionCounter } {
	global setupWirelength
	global setupCharacterizationUnit

	set isPureWire 1
	#Gets a set of bits that represent the current solution.
	set binaryTopology [dec2bin $solutionCounter]
	#Since dec2bin ignores leading 0s, here we add them based on the number of possible topologies.
	set leadingZero "0 "
	while { [ llength $binaryTopology ] < [expr $setupWirelength / $setupCharacterizationUnit ]} {
		set binaryTopology $leadingZero$binaryTopology
	}
	set currentWirelength 20
	set currentSolutionTopology {}
	set bufferCounter 0
	#Iterates through the current binary topology (i.e. a bit set). 1 represents a buffer, while 0 represents a wire segment.
	foreach node $binaryTopology {
		if { $node == 0 } {
			#Wire segment, increments the currentWirelength.
			set currentWirelength [expr $currentWirelength + $setupCharacterizationUnit ]
		} else {
			#Buffer, appends to the currentSolutionTopology the currentWirelength preceding the buffer and the buffer name.
			append currentSolutionTopology "$currentWirelength buf_${solutionCounter}_${bufferCounter} "
			set currentWirelength 20
			#If there is a buffer, the solution is no longer pure-wire.
			set isPureWire 0
			incr bufferCounter
		}
	}
	#If there are any left-over wire segments, here we append them to the currentSolutionTopology.
	if { $currentWirelength > $setupCharacterizationUnit } {
		set currentWirelength [expr $currentWirelength - $setupCharacterizationUnit ]
		append currentSolutionTopology "$currentWirelength"
	}
	#Creates buffer configurations. Gets the position of each buffer in the current solution and a counter that specifies the current buffer (based on the buffer list) that is there.
	set instanceBufferType {}
	set bufferIndex 0
	foreach instance $currentSolutionTopology {
		if { [ string is integer $instance ] == 0 } {
			#If the current instance is not a number (wire segment) it is a buffer. Add it to the instanceBufferType variable together with the smallest buffer (index 0).
			set bufferInfo "$bufferIndex 0"
			lappend instanceBufferType $bufferInfo 
		}
		incr bufferIndex
	}
	#Returns a list with all new supporting data structures.
	return [list $currentSolutionTopology $instanceBufferType $isPureWire]
}

proc updateBufferTopologies { currentSolutionTopology instanceBufferType solutionCounter } {
	#Uses OpenSTA in order to update the type of cells in the design. Without this, the new buffer types (from incrementBufferTopologies) would have no effect.
	global bufferList
	set currentSolution $currentSolutionTopology
	set bufferCounter 0
	foreach bufferModification $instanceBufferType {
		#For each tuple in the instanceBufferType variable, we obtain their respective values and utilize an OpenSTA function to update the old cell (in currentSolutionTopology) with the new cell (obtained from the second index in the instanceBufferType, which represents a new cell in the bufferList).
		set modificationIndex [ lindex $bufferModification 0 ]
		set bufferNameIndex [ lindex $bufferModification 1 ]
		#We also update the currentSolution variable with the type of each buffer (instead of the instance name) to use when transforming the solution in text form for the LUT file.
		lset currentSolution $modificationIndex [ lindex $bufferList $bufferNameIndex ]
		replace_cell [ lindex $currentSolutionTopology $modificationIndex ] [ lindex $bufferList $bufferNameIndex ] 
		incr bufferCounter
	}
	return $currentSolution
}

proc transformCurrentSolution { solutionCounter } {
	global setupWirelength
	global setupCharacterizationUnit
	global bufferList

	set isPureWire 1
	set topology [split "$solutionCounter" {}]
	set currentSolutionTopology {}
	set currentWirelength 20
	#Checks the topology (ex: 0 1 2) and transforms it to wire segments and buffers (ex: 20 BUF_X1 BUF_X2)
	foreach node $topology {
		if { $node == 0 } {
			#Wire segment, increments the currentWirelength.
			set currentWirelength [expr $currentWirelength + $setupCharacterizationUnit ]
		} else {
			#Buffer, appends to the currentSolutionTopology the currentWirelength preceding the buffer and the buffer name.
			append currentSolutionTopology "$currentWirelength [lindex $bufferList [expr $node - 1]] "
			set currentWirelength 20
			#If there is a buffer, the solution is no longer pure-wire.
			set isPureWire 0
		}
	}
	#If there are any left-over wire segments, here we append them to the currentSolutionTopology.
	if { $currentWirelength > $setupCharacterizationUnit } {
		set currentWirelength [expr $currentWirelength - $setupCharacterizationUnit ]
		append currentSolutionTopology "$currentWirelength"
	}

	return [list $currentSolutionTopology $isPureWire]
}

proc updateListTopology { binaryTopology instanceBufferType } {
	global bufferList

	#Transforms [0 1 0 1] and {{1,2} {3,3}} into [0 3 0 4] 
	set currentSolution $binaryTopology
	foreach bufferModification $instanceBufferType {
		set modificationIndex [ lindex $bufferModification 0 ]
		set bufferNameIndex [ lindex $bufferModification 1 ]
		lset currentSolution $modificationIndex [ expr $bufferNameIndex + 1 ]
	}
	
	return $currentSolution
}
