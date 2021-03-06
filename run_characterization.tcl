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

#Starts a timer for the whole computation.
puts "Starting characterization..."
set initialTime [clock seconds]	

#Saves the current path (path of the run_characterization script).
set rootPath [file dirname [file normalize [info script]]]

#Gets the flags from the functions_file.
source ${rootPath}/scripts/functions_file.tcl

#Computes the automatic inputs.
exec ${rootPath}/inputGeneration/generate_inputs.tcl "${rootPath}" > ${rootPath}/inputGeneration/input_generation_log.txt

if { $bigVerilogs } {
	#Generates verilog and spef files for a given wirelength and characterization unit. Also creates a log that shows the run-time for each configuration.
	exec ${rootPath}/scripts/create_verilog_spef_tom.tcl "${rootPath}" > ${rootPath}/scripts/verilog_spef_log.txt

	#Creates the .LUT files. Also creates a log that shows the run-time for each configuration.
	exec ${rootPath}/OpenSTA/app/sta -no_splash "${rootPath}/scripts/create_lut_tom.tcl" > ${rootPath}/scripts/lut_log.txt
} else {
	#Generates verilog and spef files for a given wirelength and characterization unit. Also creates a log that shows the run-time for each configuration.
	exec ${rootPath}/scripts/create_verilog_spef.tcl "${rootPath}" > ${rootPath}/scripts/verilog_spef_log.txt

	#Creates the .LUT files. Also creates a log that shows the run-time for each configuration.
	exec ${rootPath}/OpenSTA/app/sta -no_splash "${rootPath}/scripts/create_lut.tcl" > ${rootPath}/scripts/lut_log.txt
}

#Post-processing of the lut file.
exec ${rootPath}/scripts/lut_post_processing.tcl "${rootPath}" > ${rootPath}/scripts/lut_post_processing_log.txt

#Ends the timer for the current computation. 
set finalTime [ expr ( [clock seconds] - $initialTime ) ]
puts "End of characterization. Runtime = $finalTime seconds."

