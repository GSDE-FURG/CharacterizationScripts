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

#Imports the configuration file and the functions file (required for dec2bin).
source input_file.tcl
source functions_file.tcl

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
	if {![file exists "sol_w${setupWirelength}u${setupCharacterizationUnit}"]} {
		exec mkdir "sol_w${setupWirelength}u${setupCharacterizationUnit}"
	} else {
		exec rm -rf "sol_w${setupWirelength}u${setupCharacterizationUnit}"
		exec mkdir "sol_w${setupWirelength}u${setupCharacterizationUnit}"
	}
	
	#Max number of solutions, the solution counter, the list of topologies (set of bits, 0 = wire segment, 1 = buffer) and a list of wires to create de verilog file.
	set numberOfTopologies [ expr 2 ** [expr $setupWirelength / $setupCharacterizationUnit ] ]
	set solutionCounter 0
	set topologyList {}
	set wireVector {}

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
		
		incr solutionCounter
	}

	#Starts the header for the exported verilog file. sol = solution. w = wirelength. u = characterization unit. Also defines the inputs (clock signal).
	set outputText "module sol_w${setupWirelength}u${setupCharacterizationUnit}(clk);\n";
	append outputText "\n\tinput clk;\n"

	#Creates variables that are used to characterize the current net (and store text data).
	set solutionCounter 0
	set solutionText ""
	set currentNetName ""
	set currentFirstPin ""
	set currentLastPin ""

	#Iterates through each solution. Each has one input FF and a output FF. This segment also defines the wires and creates the text data.
	foreach topology $topologyList {
		#wireCounter defines what wire is being created. For each new buffer, a new wire is created and updated in the wireVector.
		set wireCounter 0

		#Creates the text data for the cells. In this first step, solutionText has data for the first FF in the solution. 
		#Definition for the FF name is ff{in/out}_solutionCounter
		#Definition for the wires is net_solutionCounter_wireCounter
		append solutionText "\t${ffName} ffin_${solutionCounter}( .${ffPinD}(dummy), .${ffPinClk}(clk), ."
		append solutionText "${ffPinQ}(net_${solutionCounter}_${wireCounter}) );\n\t";
		
		#Saves the information for the first pin (output of the FF) and the current net name.
		set currentFirstPin "ffin_${solutionCounter}:${ffPinQ}"
		set currentNetName "net_${solutionCounter}_${wireCounter}"

		#Since wireCounter was created above, insert the first wire in the wireVector.
		lappend wireVector $currentNetName

		#Iterates through the current topology (i.e. a bit set). When a node has 1, a new buffer is created (and, consequently, a new wire).
		set nodesWithoutBuf 0
		foreach node $topology {
			if { $node == 1 } {

				#Creates a buffer in the verilog file.

				#We also need to increment this counter since, technically, a wire segment did exist between the first pin and the buffer.
				incr nodesWithoutBuf

				#Definition for the BUF name is buf_solutionCounter_wireCounter
				append solutionText "${bufName} buf_${solutionCounter}_${wireCounter}"
				append solutionText "( .${bufPinIn}(net_${solutionCounter}_${wireCounter}"

				#Define the name of the last pin and save the information of the net for future computations.
				set currentLastPin "buf_${solutionCounter}_${wireCounter}:${bufPinIn}"
				set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} [ expr ($nodesWithoutBuf * $setupCharacterizationUnit) ] ${bufPinInCapacitance}"
				lappend createdNets $currentNet	

				#Since a new wire was created, we need to define a new first pin.
				set currentFirstPin "buf_${solutionCounter}_${wireCounter}:${bufPinOut}"

				#Since wireCounter was changed, wireVector has to be updated with the new wire.
				incr wireCounter
				lappend wireVector "net_${solutionCounter}_${wireCounter}"
				
				#Finishes a buffer in the verilog file. Updating the output pin of the current buffer with the new wire.
				append solutionText "), .${bufPinOut}(net_${solutionCounter}_${wireCounter}) );\n\t"

				#With the new data above, we can save the name of the new net.
				set currentNetName "net_${solutionCounter}_${wireCounter}"

				#Clears the nodesWithoutBuf counter, since the wirelength for this new segment is still 0.
				set nodesWithoutBuf 0
			} else {

				#Pure wire segment
				incr nodesWithoutBuf
			}
		} 

		#Define the name of the last pin and saves the information of the net for future computations.
		set currentLastPin "ffout_${solutionCounter}:${ffPinD}"
		set currentNet "${currentNetName} ${currentFirstPin} ${currentLastPin} [ expr ($nodesWithoutBuf * $setupCharacterizationUnit) ] ${ffPinDCapacitance}"
		lappend createdNets $currentNet	

		#In this step, we add the data for the last FF of the solution.
		append solutionText "${ffName} ffout_${solutionCounter}( .${ffPinD}(net_${solutionCounter}_${wireCounter}"
		append solutionText "), .${ffPinClk}(clk), .${ffPinQ}(dummy) );\n\n"

		#Move to the next solution (another bitset that represents a collection of buffers).
		incr solutionCounter
		
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

	#Joins together all data (header, wires, cells and endmodule).
	append outputText "${wireText} ${solutionText}endmodule"

	#Exports the text data to a file. Naming format is the same as the module name.
	set verilogFile [ open "sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.v" w ]
	puts $verilogFile "$outputText"
	close $verilogFile

	#Iterates through all the load values defined in the load list. For each of these values, and for a specific configuration (wirelength/characterization unit), a new SPEF file will be created.
	foreach loadValue $loadList {

		#Starts the text data for the current SPEF file. This segment of code represents the header (first 14 lines) and the high level ports (clk).
		set spefHeaderText "*SPEF \"IEEE 1481-1998\"\n*DESIGN \""; 
		append spefHeaderText "sol_w${setupWirelength}u${setupCharacterizationUnit}l${loadValue}\"\n"
		set systemTime [clock seconds]
		append spefHeaderText "*DATE \"[clock format $systemTime -format "%Y-%m-%d %H:%M:%S"]\"\n*VENDOR \"NONE\"\n*PROGRAM \"CharacterizationScripts\"\n*VERSION \"beta1\"\n*DESIGN_FLOW \"PIN_CAP NONE\" \"NAME_SCOPE LOCAL\"\n"
		append spefHeaderText "*DIVIDER /\n*DELIMITER :\n*BUS_DELIMITER \[\]\n*T_UNIT 1 PS\n*C_UNIT 1 ${capacitanceUnit}\n*R_UNIT 1 ${resistanceUnit}\n"
		append spefHeaderText "*L_UNIT 1 HENRY\n\n*PORTS\n\nclk I\n\n"

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
			
			#If the net has the output FF, we have to do some extra calculations in order to obtain the correct final load.
			if {[string first "ffout_" [ lindex $currentNetInfo $lastPinIndex ] ] != -1} {
				# An output FF (ffout_ substring) found in the -> last pin <- segment of currentNetInfo

				# The D_NET segment has the net name and the total capacitance.
				set D_NETsegment "*D_NET ${currentNetName} [ format "%.7f" [ expr ( $capacitancePerUnitLength * [ lindex $currentNetInfo $wirelengthIndex ]) ] ] \n\n"

				#For the CAP segment, we use the pi model to represent the capacitances. These are grounded capacitances and are based only on the wirelength and capacitance per unit length. We also split the wire segment in 8, thus creating 8 capacitances and 7 resistances.
				
				set CAPsegment "*CAP\n1 [ lindex $currentNetInfo $firstPinIndex ] ${CAPvalue} \n"
				append CAPsegment "2 ${currentNetName}:1 ${CAPvalue} \n3 ${currentNetName}:2 ${CAPvalue} \n"
				append CAPsegment "4 ${currentNetName}:3 ${CAPvalue} \n5 ${currentNetName}:4 ${CAPvalue} \n"
				append CAPsegment "6 ${currentNetName}:5 ${CAPvalue} \n7 ${currentNetName}:6 ${CAPvalue} \n"
				#Since this segment is the end of the net, we can obtain the desired final load value by adding said value and subtracting the (already included) pin capacitance.  
				append CAPsegment "8 [ lindex $currentNetInfo $lastPinIndex ] [ expr ( $loadValue - $ffPinDCapacitance) ] \n\n"
			} else {
				set D_NETsegment "*D_NET ${currentNetName} [ format "%.7f" [ expr ( $capacitancePerUnitLength * [ lindex $currentNetInfo $wirelengthIndex ]) ] ] \n\n"
				set CAPsegment "*CAP\n1 [ lindex $currentNetInfo $firstPinIndex ] ${CAPvalue} \n"
				append CAPsegment "2 ${currentNetName}:1 ${CAPvalue} \n3 ${currentNetName}:2 ${CAPvalue} \n"
				append CAPsegment "4 ${currentNetName}:3 ${CAPvalue} \n5 ${currentNetName}:4 ${CAPvalue} \n"
				append CAPsegment "6 ${currentNetName}:5 ${CAPvalue} \n7 ${currentNetName}:6 ${CAPvalue} \n"
				append CAPsegment "8 [ lindex $currentNetInfo $lastPinIndex ] 0 \n\n"
				#If the net ends with a buffer, the capacitance of the input pin of the buffer (end of the net) is set as 0.
			}

			#In the CONN segment, only input pins have a load capacitance.
			set CONNsegment "*CONN\n*I [ lindex $currentNetInfo $firstPinIndex ] O *L 0\n*I [ lindex $currentNetInfo $lastPinIndex ] I *L [ lindex $currentNetInfo $pinCapacitanceIndex ] \n\n" 

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

		#Exports the text data to a file. Naming format is the same as the module name. l = load value for the current spef file.
		set spefFile [ open "sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}l${loadValue}.spef" w ]
		puts $spefFile "$outputText"
		close $spefFile
	}

	#Ends the timer for the current computation.
	set finalTime [ expr ( [clock seconds] - $initialTime ) ]
	puts "Verilog/SPEFs created for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}. Runtime = $finalTime seconds."
}
