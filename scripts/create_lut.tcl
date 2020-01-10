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

#OpenSTA configurations.
set sta_report_default_digits 6
set sta_crpr_enabled 1
set power_default_signal_toggle_rate 2
set sdc_version 2.0

#Imports the configuration file and the functions file.
source input_file.tcl
source functions_file.tcl

#Reads the liberty file (OpenSTA function).
read_liberty $libpath

#Creates a folder where the new LUT files are placed.
if {![file exists "exported_luts"]} {
	exec mkdir "exported_luts"
} else {
	exec rm -rf "exported_luts"
	exec mkdir "exported_luts"
}

#Iterates through all possible wirelengths.
foreach setupWirelength $wirelengthList {

	#If a lut file already exists, delete it.
	if {[file exist "exported_luts/${setupWirelength}.lut"]} {
		exec rm -rf "exported_luts/${setupWirelength}.lut"
	} 

	#Starts a timer for the current computation.
	puts "Extracting LUT for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}."
	set initialTime [clock seconds]	

	#Reads the verilog file, elaborates the design and creates a clock.
	read_verilog "sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.v"
	link_design "sol_w${setupWirelength}u${setupCharacterizationUnit}"
	create_clock [get_ports clk]  -period 1  -waveform {0 0.5}

	#The number of possible topologies for a wirelength and characterization unit is 2^(wl/cu).
	set numberOfTopologies [ expr 2 ** [expr $setupWirelength / $setupCharacterizationUnit ] ]

	#VAriables creates to store each line of the resulting LUT file.
	set outputData {}
	set outputText ""

	#SolutionCounter defines what is the current topology when transformed in binary.
	#For example, if numberOfTopologies is 4, there are 2 nodes where a buffer can be placed.
	#SolutionCounter = 0 represents no buffers (00), 1 represents 1 buffer close to the rightmost FF (01), 2 represents 1 buffer close to the leftmost FF (10) and 3 represents two buffers (11).
	set solutionCounter 0

	while { $solutionCounter < $numberOfTopologies  } {
		#Creates a list of useful variables. Such as...
		set solutionList [createSolutionTopology $solutionCounter]
		#currentSolutionTopology: A list that defines wire segments and buffers.
		set currentSolutionTopology [ lindex $solutionList 0 ]
		#instanceBufferType: A list that contains a tuple of: the index of a buffer in currentSolutionTopology and, the index of the buffer type (to be used with the bufferList input).
		set instanceBufferType [ lindex $solutionList 1 ]
		#isPureWire: A boolean variable that defines if the current solution is a pure-wire (no buffers) or not.
		set isPureWire [ lindex $solutionList 2 ]

		#Creates a variable with the name of the output pin of the leftmost FF and input pin of the rightmost FF.
		set outPin "ffout_${solutionCounter}/${ffPinD}"
		set inPin "ffin_${solutionCounter}/${ffPinQ}"

		#We can also compute the wirepower here to save some run-time.
		set currentWirePower [computeWirePower $solutionCounter]

		#Boolean variable that defines when all possible buffer types were tested.
		set buffersUpdate 1

		while { $buffersUpdate != 0 } {
			#Changing buffer topology and updates the buffer types with OpenSTA. EX: changes "20 buf_1_0 20 buf_1_0" and {{1 0} {3 1}} into "20 BUF_X1 20 BUF_X2".
			set currentSolution [updateBufferTopologies $currentSolutionTopology $instanceBufferType $solutionCounter]

			#Creates the solution in text form. Ex: "20,BUF_X1".
			set solutionText ""
			foreach instance $currentSolution {
				set solutionText "${solutionText}${instance}," 
			}
			set solutionText [ string trim $solutionText "," ]

			#Iterates through each inputslew and load.
			foreach currentLoad $loadList {
				#Load = 0 is only used to create the spef files and to compute the wire power.
				if { $currentLoad == 0 } { continue }

				#Reads the spef file for the current load.
				read_spef "sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}l${currentLoad}.spef"
				
				#Computes the input capacitance for the current configuration.
				set currentInputCapacitance [ computeInputCapacitance $isPureWire $currentLoad $currentSolution $setupWirelength $solutionCounter]
	
				foreach currentInputSlew $inputSlewList {
					
					#Uses OpenSTA in order to set a slew on the input pin (output of the leftmost FF). We also have to reload the spef file in order to make these changes have an effect.
					set_assigned_transition -rise $currentInputSlew $inPin
					set_assigned_transition -fall $currentInputSlew $inPin
					read_spef "sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}l${currentLoad}.spef"
					#Computes the outputSlew for the current configuration, also tests if it is higher than a fixed value (2*maxSlew), and, if it is, it skips the current inputSLew value.
					set currentOutputSlew [ computeOutputSlew $inPin $outPin $currentInputSlew ]
					if { $currentOutputSlew > [ expr 2 * $maxSlew ] } { continue }

					#Computes the delay for the current configuration.
					set currentDelay [ computeDelay $outPin ]
					
					#Computes the power for the current configuration. 
					set currentPower [ computePower $solutionCounter $isPureWire $currentSolution $currentLoad $currentWirePower]
					
					#Appends the data for the current configuration in a dictionary. It consists of two keys: solutionText and currentInputSlew, and one value: the text data for the LUT file. If there already is a value for the current keys, the text data is appended to te current value.
					if { [ dict exists $outputData $solutionText $currentInputSlew ] } {
						dict set outputData $solutionText $currentInputSlew "[dict get $outputData $solutionText $currentInputSlew]$currentPower $currentLoad $currentDelay $setupWirelength $currentOutputSlew $currentInputSlew $currentInputCapacitance $solutionText\n"
					} else {
						dict set outputData $solutionText $currentInputSlew "$currentPower $currentLoad $currentDelay $setupWirelength $currentOutputSlew $currentInputSlew $currentInputCapacitance $solutionText\n"
					}
				}
			}

			#Updates the buffer topology.ex: {{1 0} {3 1}} changes into {{1 0} {3 2}}. If all topologies for a specific solution were tested, buffersUpdate receives 0, which means the current topology is fully tested.
			set buffersUpdate [ incrementBufferTopologies $instanceBufferType ]
			set instanceBufferType $buffersUpdate 
		}

		#Increment the solutionCounter, changing the solution topology. Ex: "20 buf 20" turns into "20 buf 20 buf".
		incr solutionCounter
	}
	#Opens the new LUT file.
	set lutFile [ open "exported_luts/${setupWirelength}.lut" w ]
	#Iterates through all solutions and inputSlews. Then, appends the text data to a new variable. 
	dict for {solutionKey slewTextDict} $outputData {
		foreach {slewKey textData} $slewTextDict {
			append outputText "${textData}"
		}
	}
	#Exports the text data to the LUT file then closes it.
	puts $lutFile $outputText
	close $lutFile

	#Ends the timer for the current computation.
	set finalTime [ expr ( [clock seconds] - $initialTime ) ]
	puts "LUT extracted for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}. Runtime = $finalTime seconds."
}	

#Leaves OpenSTA.
exit

