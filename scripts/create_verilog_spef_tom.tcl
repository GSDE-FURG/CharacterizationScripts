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

set rootPath [lindex $argv 0]

#Imports the configuration file and the functions file (required for dec2bin).
source ${rootPath}/automaticInputs.tcl
source ${rootPath}/manualInputs.tcl
source ${rootPath}/scripts/functions_file.tcl

#Indexes for net Data. It is used when obtaining information from the net with lindex. Helps a bit with readability.
set netNameIndex 0
set firstPinIndex 1
set lastPinIndex 2
set wirelengthIndex 3
set pinCapacitanceIndex 4

#Iterates through each possible wirelength. One verilog file is created for each.
foreach setupWirelength $wirelengthList {

	#Starts a timer for the current computation.
	puts "Creating Verilog/SPEFs for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}."
	set initialTime [clock seconds]	

	#Creates a new folder for the current configuration.
	if {![file exists "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}"]} {
		exec mkdir "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}"
	} else {
		exec rm -rf "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}"
		exec mkdir "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}"
	}
	
	#Max number of solutions, the solution counter, the list of topologies (set of bits, 0 = wire segment, 1 = buffer) and a list of wires to create de verilog file.
	set numberOfTopologies [ expr 2 ** [expr $setupWirelength / $setupCharacterizationUnit ] ]
	set solutionCounter 0
	set topologyList {}
	set wireVector {}
	set inputVector {}
	set outputVector {}
	

	#Creates a list of net Data. This has information based on each created net (wirelength, name and pins). It is used when creating the spef files.
	set createdNets {}
	
	#Gets the solutions (set of bits) for the current wirelength.
	while { $solutionCounter < $numberOfTopologies  } {
		set binaryTopology [dec2bin $solutionCounter]
		#Since dec2bin ignores leading 0s, here we add them based on the number of possible topologies.
		set leadingZero "0 "
		while { [ llength $binaryTopology ] < [expr $setupWirelength / $setupCharacterizationUnit ]} {
			set binaryTopology $leadingZero$binaryTopology
		}
		
		lappend topologyList $binaryTopology

		#In order to know what nodes are buffers, here we create a reference to them with instanceBufferType. It has the index to the node in the binaryTopology and bufferIndex to the current buffer type in bufferList.
		set instanceBufferType {}
		set bufferIndex 0
		foreach number $binaryTopology {
			if { $number != 0 } {
				#If the current instance is not 0 it is a buffer. 
				set bufferInfo "$bufferIndex 0"
				lappend instanceBufferType $bufferInfo 
			}
			incr bufferIndex
		}
		
		#Since the current topology already when to the topologyList, we can try different sizes of buffers by incrementing the bufferIndex in instanceBufferType. Returns 0 if all topologies were tested.
		set instanceBufferType [incrementBufferTopologies ${instanceBufferType}]
		while { $instanceBufferType != 0 } {
			#Transforms the instanceBufferType and binaryTopology into a new topology.
			set binaryTopology [updateListTopology ${binaryTopology} ${instanceBufferType}]
			lappend topologyList $binaryTopology
			set instanceBufferType [incrementBufferTopologies ${instanceBufferType}]
		}
		
		incr solutionCounter
	}
	
	set moduleText "module sol_w${setupWirelength}u${setupCharacterizationUnit}(";

	#Creates variables that are used to characterize the current net (and store text data).
	set solutionCounter 0
	set solutionText ""
	set currentNetName ""
	set currentFirstPin ""
	set currentLastPin ""

	#Iterates through each solution. Each has one input FF and a output FF. This segment also defines the wires and creates the text data.
	foreach topology $topologyList {
		foreach loadValue $loadList {
			if { $loadValue == 0 } {continue}
			set loadValue [ string map {"." "d"} $loadValue ]
			foreach slewValue $inputSlewList {
				set slewValue [ string map {"." "d"} $slewValue ]
				#solutionCounter is what is used to define each different circuit. It is a number that represents the current topology (ex: [1 0 3] -> 103)
				set solutionCounter [string map {" " ""} [join $topology " "] ]

				#wireCounter defines what wire is being created. For each new buffer, a new wire is created and updated in the wireVector.
				set wireCounter 0

				append solutionText "\tassign net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter} = in${solutionCounter}_${loadValue}_${slewValue} ;\n\t"
				lappend inputVector "in${solutionCounter}_${loadValue}_${slewValue}" 
				append moduleText "in${solutionCounter}_${loadValue}_${slewValue}, "
				set currentFirstPin "in${solutionCounter}_${loadValue}_${slewValue}"
				set currentNetName "net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}"

				#Since wireCounter was created above, insert the first wire in the wireVector.
				lappend wireVector $currentNetName

				#Iterates through the current topology (i.e. a bit set). When a node is != 0, a new buffer is created (and, consequently, a new wire).
				set nodesWithoutBuf 0
				foreach node $topology {
					if { $node != 0 } {
						#Creates a buffer in the verilog file.

						#We also need to increment this counter since, technically, a wire segment did exist between the first pin and the buffer.
						incr nodesWithoutBuf

						#Definition for the BUF name is buf_solutionCounter_wireCounter
						append solutionText "[lindex $bufferList [expr $node - 1]] buf_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}"
						append solutionText "( .${bufPinIn}(net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}"

						#Define the name of the last pin and save the information of the net for future computations.
						set currentLastPin "buf_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}:${bufPinIn}"
						set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} [ expr ($nodesWithoutBuf * $setupCharacterizationUnit) ] ${bufPinInCapacitance}"
						lappend createdNets $currentNet	

						#Since a new wire was created, we need to define a new first pin.
						set currentFirstPin "buf_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}:${bufPinOut}"

						#Since wireCounter was changed, wireVector has to be updated with the new wire.
						incr wireCounter
						lappend wireVector "net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}"
						
						#Finishes a buffer in the verilog file. Updating the output pin of the current buffer with the new wire.
						append solutionText "), .${bufPinOut}(net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}) );\n\t"

						#With the new data above, we can save the name of the new net.
						set currentNetName "net_${solutionCounter}_${loadValue}_${slewValue}_${wireCounter}"

						#Clears the nodesWithoutBuf counter, since the wirelength for this new segment is still 0.
						set nodesWithoutBuf 0
					} else {

						#Pure wire segment
						incr nodesWithoutBuf
					}
				} 
				
				#Define the name of the last pin and saves the information of the net for future computations.
				set currentLastPin "out${solutionCounter}_${loadValue}_${slewValue}"
				set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} [ expr ($nodesWithoutBuf * $setupCharacterizationUnit) ] 0"
				lappend createdNets $currentNet	

				#In this step, we add the data for the last port of the solution.
				append solutionText "assign out${solutionCounter}_${loadValue}_${slewValue} = ${currentNetName} ;\n\n"
				lappend outputVector "out${solutionCounter}_${loadValue}_${slewValue}" 
				append moduleText "out${solutionCounter}_${loadValue}_${slewValue}, "
				
				#Move to the next solution (another bitset that represents a collection of buffers).
			}
		}
	}

	foreach loadValue $loadList {
		if { $loadValue == 0 } {continue}
		set loadValue [ string map {"." "d"} $loadValue ]
		#Segment for a test net. Used as power for pure-wire solutions.
		append solutionText "\tassign testnet_1_${loadValue} = testin_${loadValue} ;\n\t"
		lappend inputVector "testin_${loadValue}" 
		append moduleText "testin_${loadValue}, "
		set currentFirstPin "testin_${loadValue}"
		set currentNetName "testnet_1_${loadValue}"
		#Since wireCounter was created above, insert the first wire in the wireVector.
		lappend wireVector $currentNetName

		#Definition for the BUF name is buf_solutionCounter_wireCounter
		append solutionText "[lindex $bufferList 0] testbuf_${loadValue}"
		append solutionText "( .${bufPinIn}(testnet_1_${loadValue}"

		#Define the name of the last pin and save the information of the net for future computations.
		set currentLastPin "testbuf_${loadValue}:${bufPinIn}"
		set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} ${setupWirelength} ${bufPinInCapacitance}"
		lappend createdNets $currentNet	

		#Since a new wire was created, we need to define a new first pin.
		set currentFirstPin "testbuf_${loadValue}:${bufPinOut}"

		#Since wireCounter was changed, wireVector has to be updated with the new wire.
		incr wireCounter
		lappend wireVector "testnet_2_${loadValue}"
		
		#Finishes a buffer in the verilog file. Updating the output pin of the current buffer with the new wire.
		append solutionText "), .${bufPinOut}(testnet_2_${loadValue}) );\n\t"

		#With the new data above, we can save the name of the new net.
		set currentNetName "testnet_2_${loadValue}"

		#Define the name of the last pin and saves the information of the net for future computations.
		set currentLastPin "testout_${loadValue}"
		set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} 0 0"
		lappend createdNets $currentNet	

		#In this step, we add the data for the last port of the solution.
		append solutionText "assign testout_${loadValue} = ${currentNetName} ;\n\n"
		lappend outputVector "testout_${loadValue}" 
		append moduleText "testout_${loadValue}, "
	}
		
	#Creates the definition of the wires for the verilog file.
	set wireText "\n\twire "

	#Iterates through all the wires created in the previous step. In verilog, wires can be defined in multiple lines/definitions or a single line. This uses the later.
	foreach net $wireVector {
		append wireText "${net} , ";
	}
	
	#Removes the leading " , " and adds some new lines. 
	set wireText [ string trimright $wireText " , " ]
	append wireText ";\n\n"

	#Removes the leading " , " and adds some new lines for the header of the verilog file.
	set moduleText [ string trimright $moduleText ", " ]
	append moduleText ");\n\n"

	#Creates the definition of the inputs for the verilog file.
	set inputText "\tinput "
	
	#Iterates through all the inputs.
	foreach input $inputVector {
		append inputText "${input} , ";
	}
	
	#Removes the leading " , " and adds a new line.
	set inputText [ string trimright $inputText " , " ]
	append inputText ";\n"

	#Creates the definition of the outputs for the verilog file.
	set outputText "\toutput "

	#Iterates through all the outputs.
	foreach output $outputVector {
		append outputText "${output} , ";
	}

	#Removes the leading " , " and adds a new line.
	set outputText [ string trimright $outputText " , " ]
	append outputText ";\n"

	#Joins together all data (header, inputs, outputs, wires, cells and endmodule).
	set outputText "${moduleText}${inputText}${outputText}${wireText}${solutionText}endmodule"

	#Exports the text data to a file. Naming format is the same as the module name.
	set verilogFile [ open "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.v" w ]
	puts $verilogFile "$outputText"
	close $verilogFile

	# SPEF FILE

	
	#Input and Outputs are Ports.
	#Starts the text data for the current SPEF file. This segment of code represents the header (first 14 lines) and the high level ports (clk, inputs and outputs).
	set spefHeaderText "*SPEF \"IEEE 1481-1998\"\n*DESIGN \""; 
	append spefHeaderText "sol_w${setupWirelength}u${setupCharacterizationUnit}\"\n"
	set systemTime [clock seconds]
	append spefHeaderText "*DATE \"[clock format $systemTime -format "%Y-%m-%d %H:%M:%S"]\"\n*VENDOR \"NONE\"\n*PROGRAM \"CharacterizationScripts\"\n*VERSION \"beta3\"\n*DESIGN_FLOW \"PIN_CAP NONE\" \"NAME_SCOPE LOCAL\"\n"
	append spefHeaderText "*DIVIDER /\n*DELIMITER :\n*BUS_DELIMITER \[\]\n*T_UNIT 1 PS\n*C_UNIT 1 ${capacitanceUnit}\n*R_UNIT 1 ${resistanceUnit}\n"
	append spefHeaderText "*L_UNIT 1 HENRY\n\n*PORTS\n\nclk I\n"
	foreach input $inputVector {
		append spefHeaderText "${input} I\n";
	}
	foreach output $outputVector {
		append spefHeaderText "${output} O\n";
	}
	append spefHeaderText "\n"

	#Creates a list of D_NETs. Each D_NET contains information about a specific net.
	set D_NETData {}
	set currentD_NET ""

	foreach currentNetInfo $createdNets {

		#Creates the text data for each specific segment of the D_NET: header, CONN, CAP and RES.
		set D_NETsegment ""
		set CAPsegment ""
		
		#Creates variables for the net name, the capacitance value / 7 and the resistance value / 8. This division is because we will devide the net in 8 segments in the CAP and RES segments.
		set currentNetName [ lindex $currentNetInfo $netNameIndex ]
		set CAPvalue [ format "%.7f" [ expr ( ( $capacitancePerUnitLength * [ lindex $currentNetInfo $wirelengthIndex ] ) / 7 ) ] ]
		set RESvalue [ expr ( ( $resistancePerUnitLength * [ lindex $currentNetInfo $wirelengthIndex ] ) / 8 ) ]

		# The D_NET segment has the net name and the total capacitance.
		set D_NETsegment "*D_NET ${currentNetName} [ format "%.7f" [ expr ( $capacitancePerUnitLength * [ lindex $currentNetInfo $wirelengthIndex ]) ] ] \n\n"

		#For the CAP segment, we use the pi model to represent the capacitances. These are grounded capacitances and are based only on the wirelength and capacitance per unit length. We also split the wire segment in 8, thus creating 8 capacitances and 7 resistances.
		set CAPsegment "*CAP\n1 [ lindex $currentNetInfo $firstPinIndex ] ${CAPvalue} \n"
		append CAPsegment "2 ${currentNetName}:1 ${CAPvalue} \n3 ${currentNetName}:2 ${CAPvalue} \n"
		append CAPsegment "4 ${currentNetName}:3 ${CAPvalue} \n5 ${currentNetName}:4 ${CAPvalue} \n"
		append CAPsegment "6 ${currentNetName}:5 ${CAPvalue} \n7 ${currentNetName}:6 ${CAPvalue} \n"
		append CAPsegment "8 [ lindex $currentNetInfo $lastPinIndex ] 0 \n\n"
		
		#In the CONN segment, only input pins from a buffer have a load capacitance. *P is used for ports and *I is used for pins.
		if {[string first "in" [ lindex $currentNetInfo $firstPinIndex ] ] != -1} {
			#Pin has "in", meaning it is a port.
			set CONNsegment "*CONN\n*P [ lindex $currentNetInfo $firstPinIndex ] I *L 0\n"
		} else {
			set CONNsegment "*CONN\n*I [ lindex $currentNetInfo $firstPinIndex ] O *L 0\n"
		}
		if {[string first "out" [ lindex $currentNetInfo $lastPinIndex ] ] != -1} {
			#Pin has "out", meaning it is a port.
			append CONNsegment "*P [ lindex $currentNetInfo $lastPinIndex ] O *L 0 \n\n" 
		} else {
			#Input pin from a buffer.
			append CONNsegment "*I [ lindex $currentNetInfo $lastPinIndex ] I *L [ lindex $currentNetInfo $pinCapacitanceIndex ] \n\n" 
		}

		#The RES segment has all the pins that were defined in the CAP segment and defines a resistance between them.
		set RESsegment "*RES\n1 [ lindex $currentNetInfo $firstPinIndex ] ${currentNetName}:1 ${RESvalue} \n"
		append RESsegment "2 ${currentNetName}:1 ${currentNetName}:2 ${RESvalue} \n"
		append RESsegment "3 ${currentNetName}:2 ${currentNetName}:3 ${RESvalue} \n"
		append RESsegment "4 ${currentNetName}:3 ${currentNetName}:4 ${RESvalue} \n"
		append RESsegment "5 ${currentNetName}:4 ${currentNetName}:5 ${RESvalue} \n"
		append RESsegment "6 ${currentNetName}:5 ${currentNetName}:6 ${RESvalue} \n"
		append RESsegment "7 ${currentNetName}:6 [ lindex $currentNetInfo $lastPinIndex ] ${RESvalue} \n*END\n\n" 
		
		#Saves the net info to a list.
		set currentD_NET "$D_NETsegment$CONNsegment$CAPsegment$RESsegment"
		lappend D_NETData $currentD_NET
	}

	#Concatenates all text data for the spef file.
	set outputText "$spefHeaderText \n"
	foreach D_NETText $D_NETData {
		append outputText "$D_NETText \n"
	}

	#Exports the text data to a file. Naming format is the same as the module name.
	set spefFile [ open "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.spef" w ]
	puts $spefFile "$outputText"
	close $spefFile


	#Ends the timer for the current computation.
	set finalTime [ expr ( [clock seconds] - $initialTime ) ]
	puts "Verilog/SPEFs created for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}. Runtime = $finalTime seconds."
}
