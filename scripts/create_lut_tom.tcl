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

proc find_parent_dir { dir } {
	#Returns the parent directory (one folder above) of the provided path.
	if { $dir == "." } {
		return ".."
	} else {
		set path [file split $dir]
		set path_len [llength $path]
		if { $path_len == 1 } {
			return "."
		} else {
			set path_len2 [expr $path_len - 2]
			return [eval file join [lrange $path 0 $path_len2]]
		}
	}
}

set rootPath [file dirname $::argv0 ] 
set rootPath [find_parent_dir [find_parent_dir $rootPath ] ]

#Imports the configuration file and the functions file.
source ${rootPath}/automaticInputs.tcl
source ${rootPath}/manualInputs.tcl
source ${rootPath}/scripts/functions_file.tcl

#OpenSTA configurations.
set sta_report_default_digits 6
set sta_crpr_enabled 1
#set_units -capacitance $capacitanceUnit -resistance $resistanceUnit -time $timeUnit -voltage V -current uA -power mw
set power_default_signal_toggle_rate 2
set sdc_version 2.0

#Reads the liberty file (OpenSTA function).
read_liberty "$libpath"

#Creates a folder where the new LUT files are placed.
if {![file exists "${rootPath}/scripts/exported_luts"]} {
	exec mkdir "${rootPath}/scripts/exported_luts"
} else {
	exec rm -rf "${rootPath}/scripts/exported_luts"
	exec mkdir "${rootPath}/scripts/exported_luts"
}

#Iterates through all possible wirelengths.
foreach setupWirelength $wirelengthList {

	#If a lut file already exists, delete it.
	if {[file exist "${rootPath}/scripts/exported_luts/${setupWirelength}.lut"]} {
		exec rm -rf "${rootPath}/scripts/exported_luts/${setupWirelength}.lut"
	} 

	#Starts a timer for the current computation.
	puts "Extracting LUT for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}."
	set initialTime [clock seconds]	

	#Reads the verilog file, elaborates the design.
	read_verilog "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.v"
	link_design "sol_w${setupWirelength}u${setupCharacterizationUnit}"

	#If inputs and outputs are ports, there is only one spef file that we need to read.
	read_spef "${rootPath}/scripts/sol_w${setupWirelength}u${setupCharacterizationUnit}/sol_w${setupWirelength}u${setupCharacterizationUnit}.spef"

	#Creates a virtual clock that sets a the arrival times to all inputs and outputs as 0. Needed to compute delay calculations.
	create_clock -period 1 -waveform {0 0.5} -name virtual
	set_input_delay -clock virtual 0 [all_inputs]
	set_output_delay -clock virtual 0 [all_outputs]

	#Set a resistance to the inputs so that the delay isn't 0.
	set_drive [expr double(${setupWirelength} * ${resistancePerUnitLength})] [all_inputs]

	#The number of possible topologies for a wirelength and characterization unit is 2^(wl/cu).
	set numberOfTopologies [ expr 2 ** [expr $setupWirelength / $setupCharacterizationUnit ] ]

	#Variables created to store each unique solution (combination of multiple variables) and to store the text data for the lut file. Their structure is as follows:
	#outputTextData: a dict where key = solutionText (ex: 20,BUF_X2) and values = every line that has the same buffer topology.	
	#uniqueSolutionList: a dict where key = unique solution key (combination of multiple variables) and value = the indexes for a specific line in outputTextData
	set uniqueSolutionList {}
	set outputTextData {}

	#For each parallel circuit in the verilog file, we have one input port and one output port. Thus, we can iterate over all input ports to get each specific circuit.
	set solutionsToTest [all_inputs]

	foreach inputPort $solutionsToTest {
		#Transform the name of the port into a name we can use. Port_xxyy -> in00
		set inPin [get_property -object_type port $inputPort full_name]
	
		#Gets the solutionCounter from the numbers in the name of the input port. These are used to identify the circuit.
		if {[string first "test" $inPin ] != -1} {continue}
		set solutionCounter [string trimleft $inPin "in"]

		#With this, we can set the output port, the solution (ex: 20 BUF_X2) and if the circuit is a pure-wire.
		set outPin "out${solutionCounter}"
		set solutionList [ transformCurrentSolution $solutionCounter ]
		set currentSolution [ lindex $solutionList 0 ]
		set isPureWire [ lindex $solutionList 1 ]

		#Creates the solution in text form. Ex: "20,BUF_X1".
		set solutionText ""
		foreach instance $currentSolution {
			set solutionText "${solutionText}${instance}," 
		}
		set solutionText [ string trim $solutionText "," ]

		set lineIndex 0

		#Iterates through each inputslew and load.
		foreach currentLoad $loadList {
			#Load = 0 is only used to create the spef files and to compute the wire power.
			if { $currentLoad == 0 } { continue }

			set_load $currentLoad $outPin
			
			#Computes the input capacitance for the current configuration.
			set currentInputCapacitance [ computeInputCapacitance $isPureWire $currentLoad $currentSolution $setupWirelength $solutionCounter "${rootPath}/scripts"]

			foreach currentInputSlew $inputSlewList {
				
				#Uses OpenSTA in order to set a slew on the input port.
				set_assigned_transition -rise $currentInputSlew $inPin
				set_assigned_transition -fall $currentInputSlew $inPin

				#Computes the outputSlew for the current configuration, also tests if it is higher than a fixed value (2*maxSlew), and, if it is, it skips the current inputSLew value.
				set currentOutputSlew [ computeOutputSlew $inPin $outPin $currentInputSlew ]
				if { $currentOutputSlew > [ expr 2 * $maxSlew ] } { continue }

				#Computes the delay for the current configuration.
				set currentDelay [ computeDelay $outPin ]
				
				#Computes the power for the current configuration. 
				set currentPower [ computePower $solutionCounter $isPureWire $currentSolution $currentLoad 0 "${rootPath}/scripts"]

				#Creates a key that represents the current solution. Composed of load, delay, wirelength, outputslew, inputslew and inputcap.
				set solutionKey "$currentLoad-$currentDelay-$setupWirelength-$currentOutputSlew-$currentInputSlew-$currentInputCapacitance"
				
				#Checks if there is another configuration that had the same solutionKey. If there was, keep the one with lower power.
				if { [ dict exists $uniqueSolutionList $solutionKey ] } {
					#In order to obtain the previous power value, we first have to obtain the indexes from the uniqueSolutionList dict.
					set valueIndex [ lindex [dict get $uniqueSolutionList $solutionKey] 1 ]
					set solutionIndex [ lindex [dict get $uniqueSolutionList $solutionKey] 0 ]
					#Gets the line for the previous computation.
					set currentValue [ lindex [dict get $outputTextData $solutionIndex] $valueIndex ]
					set previousPower [ lindex $currentValue 0 ]
					if { $previousPower > $currentPower } {
						#If the current power value is lower the the previous one, we need to eplace the old values with the information for the current line.
						dict set uniqueSolutionList $solutionKey "$solutionText $lineIndex" 
						#Also, we have to empty the information of the last line. Erasing it would mess up the references for the lineIndex.
						set textLines [dict get $outputTextData $solutionIndex ]
						lset textLines $valueIndex ""
						dict set outputTextData $solutionIndex "$textLines"
						#Updates outputTextData with the new line. Also increments the lineIndex.
						dict lappend outputTextData $solutionText "$currentPower $currentLoad $currentDelay $setupWirelength $currentOutputSlew $currentInputSlew $currentInputCapacitance $solutionText "
						incr lineIndex
					}
				} else {
					#If there is no value for the current key, create one: a list that consists of the solutionText and the index of the line for the current buffer topology.
					dict set uniqueSolutionList $solutionKey "$solutionText $lineIndex"
					#Updates outputTextData with the new line. Also increments the lineIndex.
					dict lappend outputTextData $solutionText "$currentPower $currentLoad $currentDelay $setupWirelength $currentOutputSlew $currentInputSlew $currentInputCapacitance $solutionText "
					incr lineIndex
					
				}
			}
		}
		
	}

	#Opens the new LUT file.
	set lutFile [ open "${rootPath}/scripts/exported_luts/${setupWirelength}.lut" w ]
	#Creates two new variables to store the text data. outputList will store the data in a list, in order to sort it based on the inputSlew. outputText will store the raw text data. 
	set outputText ""
	set outputList ""
	foreach {solution lines} $outputTextData {
			#Creates the list with each line for the current solution.
			foreach lineData $lines {
				append outputList $lineData
			}
			#Groups the values by 8 (-stride) and sort them based on the 5th value (inputSlew).
			set outputList [ lsort -stride 8 -index 5 $outputList ]
			#For each one of the 8 values, define a name for each of them and add them to outputText variable.
			foreach {currentPower currentLoad currentDelay setupWirelength currentOutputSlew currentInputSlew currentInputCapacitance solutionText} $outputList {
				append outputText "$currentPower $currentLoad $currentDelay $setupWirelength $currentOutputSlew $currentInputSlew $currentInputCapacitance $solutionText\n"
			}
			
			#Empty outputList for the next solution.
			set outputList ""
	}

	#Exports the text data to the LUT file then closes it. Also removes any leading "\n".
	set outputText [ string trimright $outputText "\n" ]
	puts $lutFile $outputText
	close $lutFile

	#Ends the timer for the current computation.
	set finalTime [ expr ( [clock seconds] - $initialTime ) ]
	puts "LUT extracted for: Wirelength ${setupWirelength} , Characterization Unit ${setupCharacterizationUnit}. Runtime = $finalTime seconds."
}	

#Leaves OpenSTA.
exit

