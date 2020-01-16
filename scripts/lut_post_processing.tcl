#! /usr/bin/tclsh

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

#Imports the configuration file.
source ../automaticInputs.tcl
source ../manualInputs.tcl

#Starts a timer for the current computation.
puts "Post-processing of the lut file."
set initialTime [clock seconds]	

cd exported_luts

#Creates 5 arrays where the data for a specific configuration will be stored.
set opt1List ""
array set opt1Power {}
array set opt1inCap {}
array set opt1inSlew {}
array set totSol {}

#Iterates through each possible wirelength.
foreach setupWirelength $wirelengthList {
	#Opens the lut file representing that wirelength.
	set lutFile [open "./${setupWirelength}.lut" r]
	
	#For each line in the lut file...
	while {[gets $lutFile configInfo] >= 0} {
		
		#Gets the current load, wirelength, input slew and input capacitance value and creates a key.
		set power [lindex $configInfo 0]
		set load [lindex $configInfo 1]
		set delay [lindex $configInfo 2]
		set dist [lindex $configInfo 3]
		set outSlew [lindex $configInfo 4]
		set inSlew [lindex $configInfo 5]
		set inCap [lindex $configInfo 6]
		set sol [lindex $configInfo 7]

		set opt1 "${dist}-${outSlew}-${load}-${inCap}"

		#Appends the current delay to the delay array, if there is one. If not, a new key-value combination is created.
		
		if {![info exists opt1Delay($opt1)]} {
		    set opt1Delay($opt1) $delay 
		    set opt1List "$opt1List $opt1"
		} else {
		    set opt1Delay($opt1) "$opt1Delay($opt1) $delay"
		}

		#Appends the current power to the power array, if there is one. If not, a new key-value combination is created. Delay is also used as a key.

		if {![info exists opt1Power($opt1-${delay})]} {
		    set opt1Power($opt1-${delay}) $power
		} else {
		    set opt1Power($opt1-${delay}) "$opt1Power($opt1-${delay}) $power"
		}

		#Appends the current slew to the slew array, if there is one. If not, a new key-value combination is created. Delay and power are used in the key.

		if {![info exists opt1inSlew($opt1-${delay}-${power})]} {
		    set opt1inSlew($opt1-${delay}-${power}) $inSlew
		} else {
		    set opt1inSlew($opt1-${delay}-${power}) "$opt1inSlew($opt1-${delay}-${power}) $inSlew"
		}

		#Gets the full key that represents the current solution. 

		set cur "${opt1}-${delay}-${power}-${inSlew}"

		#Stores the current solution in the total solution array. Prints an error in case there is another solution with the same key.

		if {![info exists totSol($cur)]} {
		    set totSol($cur) $sol
		} else {
		    puts "ERROR!!: overlapping solutions"
		}	
	}
}

#A list containing multipliers that are used when the number of values of a key is higher than 3.
set selPoints "0.1 0.5 0.9"

#Text data for the new lut file.
set outputText ""

#Sorts the data for the solutions.
set opt1List [lsort -uniq $opt1List]

#For each key combination (${dist}-${outSlew}-${load}-${inCap})...
foreach opt1 $opt1List {
	#Checks if the number of solutions is lower than 3
	if {[llength $opt1Delay($opt1)] <= [llength $selPoints]} {
		#If it is lower than 3, put all of them in the output text file.
		foreach cDelay $opt1Delay($opt1) {
			#Iterates in the delay array in order to obtain the other values.
			#Gets the power value, also used as a key for slew.
			set cPower [lindex [lsort -real -increasing $opt1Power($opt1-${cDelay})] 0]
			#Gets the slew value, used to create the total key for totSol
			set cInSlew [lindex $opt1inSlew($opt1-${cDelay}-${cPower}) end]
			#Gets the rest of the informating necessary to re-create the line.
			set cur "$opt1-${cDelay}-${cPower}-${cInSlew}"
			set cSol $totSol($cur)
			regsub -all {\-} $opt1 " " temp 
			set cInCap [lindex $temp 3]
			set cLoad [lindex $temp 2]
			set cOutSlew [lindex $temp 1]
			set cDist [lindex $temp 0]
			#Recreates the line and put it in the resulting concat.lut file.
			set output "${cPower} ${cLoad} ${cDelay} ${cDist} ${cOutSlew} ${cInSlew} ${cInCap} ${cSol}"
			append outputText "$output\n"
        	}
	} else {
    		#If it is higher than 3, create 3 custom indexes from the selPoints list.		
        	foreach loc $selPoints {
        	#Gets the solution index based a multiplier (number in selPoints).
		set idx [expr int(floor($loc*1.0*[llength $opt1Delay($opt1)]))]
		#Gets the delay value from that index. From here the computations are the same as above.
		set cDelay [lindex $opt1Delay($opt1) $idx]
		#Gets the power value, also used as a key for slew.	
		set cPower [lindex [lsort -real -increasing $opt1Power($opt1-${cDelay})] 0]
		#Gets the slew value, used to create the total key for totSol
		set cInSlew [lindex $opt1inSlew($opt1-${cDelay}-${cPower}) end]
		#Gets the rest of the informating necessary to re-create the line.
		set cur "$opt1-${cDelay}-${cPower}-${cInSlew}"
		set cSol $totSol($cur)
		regsub -all {\-} $opt1 " " temp 
		set cInCap [lindex $temp 3]
		set cLoad [lindex $temp 2]
		set cOutSlew [lindex $temp 1]
		set cDist [lindex $temp 0]
		#Recreates the line and put it in the resulting concat.lut file.
		set output "${cPower} ${cLoad} ${cDelay} ${cDist} ${cOutSlew} ${cInSlew} ${cInCap} ${cSol}"
		append outputText "$output\n"
        }
    }
}

#Exports the text data to a file. (Also trims any leading "\n")
set concatFile [ open "concat.lut" w ]
set outputText [ string trimright $outputText "\n" ]
puts $concatFile "$outputText"
close $concatFile

#Opens the new file.
set concatText [ open "concat.lut" r ]

#Line index is a new variable that defines the reference between the two new files that will be created: lut.txt and sol_list.txt
set lineIndex 0

# Minimun and Maximun wirelength, load and slew are created for the new lut.txt file.
set minWirelength 99999
set maxWirelength -1
set minCapacitance 99999
set maxCapacitance -1
set minSlew 99999
set maxSlew -1

#If the current outputSlew is higher than this value, skips the current line.
set skew_limit [expr 0.200 * $time_unit]

#Text data for sol_list.txt and lut.txt
set solutionTextFile ""
set convertedText ""

while {[gets $concatText line]>=0} {

	#Gets the current outputSlew and inputSlew values.
	set outputSlew [lindex $line 4]
	set inputSlew [lindex $line 5]

	#Checks if the current outputSlew is higher than the skew limit or if the outputSlew is empty. If so, skips the current line.
	if {$outputSlew > $skew_limit || $outputSlew eq ""} {
		continue
	}

	#Computations for outputSlew. Converts the current value into a multiple of 5ps. Also sets a new minSlew or maxSlew value if needed.
	set outputSlew [format %.0f [expr ($outputSlew/( $slewInter * $time_unit ))]]
	if {$outputSlew < $minSlew} {
		set minSlew $outputSlew
	}
	if {$outputSlew > $maxSlew} {
		set maxSlew $outputSlew
	}
	#Computations for inputSlew. Converts the current value into a multiple of 5ps. Also sets a new minSlew or maxSlew value if needed.
	set inputSlew  [format %.0f [expr ($inputSlew/( $slewInter * $time_unit ))]]
	if {$inputSlew < $minSlew} {
		set minSlew $inputSlew
	}
	if {$inputSlew > $maxSlew} {
		set maxSlew $inputSlew
	}

	#Computations for power. Converts the current value into mW if needed (cap_unit != 1).
    	set power [format %.7f [expr [lindex $line 0] * $cap_unit] ]
    
	#Computation for load. Converts the current value to match the outLoadNum value. Also sets a new minCapacitance or maxCapacitance if needed.
	set loadValue     [lindex $line 1]
	if {$loadValue < [expr $baseLoad]} {
		set loadValue [format %.0f [expr $loadValue/( $initial_cap_interval * $cap_unit )]]
	} else {
		set loadValue [expr [format %.0f [expr $loadValue /( $final_cap_interval*$cap_unit )]]+4]
	}
	if {$loadValue < $minCapacitance} {
		set minCapacitance $loadValue
	}
	if {$loadValue > $maxCapacitance} {
		set maxCapacitance $loadValue
	}

	#Computations for delay. Converts the current value into a multiple of 1ps.
	set delay [format %.0f [expr [lindex $line 2]/(0.001*$time_unit)]]
	
	#Computations for wirelength. Converts the current value into a multiple of 10um. Also sets a new minWirelength or maxWirelength if needed.
	set wirelength [format %.0f [expr [lindex $line 3]/20]]
	if {$wirelength < $minWirelength} {
		set minWirelength $wirelength
	}
	if {$wirelength > $maxWirelength} {
		set maxWirelength $wirelength
	}

	#Computations for input capacitance. Converts the current value based on the load (load intervals). Also sets a new minCapacitance or maxCapacitance if needed.
	set inputCapacitance [lindex $line 6]
	if {$inputCapacitance < [expr $baseLoad]} {
		set inputCapacitance [format %.0f [expr $inputCapacitance/($initial_cap_interval*$cap_unit)]]
	} else {
		set inputCapacitance [expr [format %.0f [expr $inputCapacitance/($final_cap_interval*$cap_unit)]]+4]
	}

	if {$inputCapacitance < $minCapacitance} {
		set minCapacitance $inputCapacitance
	}
	if {$inputCapacitance > $maxCapacitance} {
		set maxCapacitance $inputCapacitance
	}

	#Gets the current solution and checks if it is pure-wire.
	set solutionText [lindex $line 7]
	set isPureWire 1
	if {[regexp "BUF" $solutionText]} {
		set isPureWire 0
	}

	#Computes each the distance of wire segment on comparison with the total wirelength. Each segment in the text will be divided by the total wirelength then exported to the end of the line in the lut file. Only for buffered solutions.
	set segmentList ""
	set totalWirelength [lindex $line 3]
	if {$isPureWire == 0} {
		#Splits the solution text, tranforming it into a list: 20,BUF,40 -> [20 BUF 40] (Change code here? We only have to remove any BUF string in the list)
		set solutionList [split $solutionText ","]
		set segmentDistance 0.0
		foreach segment $solutionList {
			#For each node in the new list, check if is a Buffer. If no: Add the wirelength of the segment to the segmentDistance variable.
			if {![regexp {BUF} $segment]} {
				set segmentDistance [expr $segmentDistance + $segment]
			} else {
				#If yes: Append the current segment to a list and resets the segmentDistance variable.
				lappend segmentList $segmentDistance
				set segmentDistance 0.0
			}
		}
		#With the list created, divide each value with the total wirelength. 
		set currentIndex 0
		foreach segment $segmentList {
			lset segmentList $currentIndex [expr [lindex $segmentList $currentIndex] / $totalWirelength]
			incr currentIndex
		}
	}
	#Appends text data for the sol_list.txt and lut.txt files. sol_list.txt will have the line index and the solution.
	#lut.txt will have the line index, wirelength, load, output slew, power, input capacitance, input slew, if the solution is pure-wire or not and, if the solution is not pure-wire, a list (variable length) of wire segment distances (values from 0 to 1, 1 means the wire segment is the size of the total wirelength, 0.5 means it is half...). 
	append solutionTextFile "${lineIndex} ${solutionText}\n"
	append convertedText "${lineIndex} ${wirelength} ${loadValue} ${outputSlew} ${power} ${delay} ${inputCapacitance} ${inputSlew} ${isPureWire} ${segmentList}\n"
	
	#Increments the line index.
	incr lineIndex
}

#Exports the text data to the sol_list.txt file. Also removes any leading "\n".
set solutionsFile [ open ../../sol_list.txt w ]
set solutionTextFile [ string trimright $solutionTextFile "\n" ]
puts $solutionsFile "$solutionTextFile"
close $solutionsFile

#Exports the text data to the lut.txt file. Also adds a header with the minimun and maximun wirelength, capacitance and slew.
set lutFile [open ../../lut.txt w]
set outputLutText "$minWirelength $maxWirelength $minCapacitance $maxCapacitance $minSlew $maxSlew\n"
append outputLutText "$convertedText"
#Removes any leading "\n".
set outputLutText [ string trimright $outputLutText "\n" ]
puts $lutFile $outputLutText
close $lutFile

#Ends the timer for the current computation.
set finalTime [ expr ( [clock seconds] - $initialTime ) ]
puts "End of post-processing. Runtime = $finalTime seconds."
