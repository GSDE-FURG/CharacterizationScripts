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

#Finds the root path of the characterization scripts.
set rootPath [file dirname [file normalize [info script]]]
set rootPath [find_parent_dir [find_parent_dir $rootPath]]

#Gets the text data from the current manualInputs.tcl file.
set old_manualInputsFile [open "${rootPath}/manualInputs.tcl" r]
set old_manualInputs [read $old_manualInputsFile]
close $old_manualInputsFile

#Gets the text data from the new, predefined, manualInputs.tcl file.
set new_manualInputsFile [open "${rootPath}/tests/lut_compare/test_manualInputs.tcl" r]
set new_manualInputs [read $new_manualInputsFile]
close $new_manualInputsFile

#Overwrite the old manualInputs.tcl with the new one. Also adds the path for the liberty and lef files.
set overwriteOldFile [open "${rootPath}/manualInputs.tcl" w]
puts $overwriteOldFile "#Full path to liberty file.\nset libpath \"${rootPath}/tests/lut_compare/example1_slow.lib\"\n\n"
puts $overwriteOldFile "#Full path to lef file.\nset lef_file \"${rootPath}/tests/lut_compare/NangateOpenCellLibrary.mod.lef\"\n\n"
puts $overwriteOldFile $new_manualInputs
close $overwriteOldFile

#Runs the characterization.
exec ${rootPath}/run_characterization.tcl

#Gets the difference between the old and new look-up tables.
set lut_diff [exec diff ${rootPath}/tests/lut_compare/golden_lut.txt ${rootPath}/lut.txt]
set sol_diff [exec diff ${rootPath}/tests/lut_compare/golden_sol_list.txt ${rootPath}/sol_list.txt]

#Overwrites the manualInputs.tcl with the old, used defined, data.
set overwriteOldFile [open "${rootPath}/manualInputs.tcl" w]
puts $overwriteOldFile $old_manualInputs
close $overwriteOldFile

#If there are no differences, the characterization still presents the same results.
if { ($lut_diff == "") && ($sol_diff == "") } {
	puts "GREEN: Files have no differences."
	return 0
} else {
	puts "RED: Files have differences."
	return 1
}
