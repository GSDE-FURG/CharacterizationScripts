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

source ${rootPath}/manualInputs.tcl
source ${rootPath}/scripts/functions_file.tcl

proc getMasters {} {
#code to return all masters present in the verilog file.
	set x [get_cells]
	set i 0
	set cell_list ""
	while {[lindex $x $i] != ""} {
		set a [get_name [get_lib_cells -of_objects [lindex $x $i]]] 
		lappend cell_list $a
		set i [expr {$i + 1}]
	}
	return $cell_list
}

proc getInstances {} {
#code to return all instances present in the verilog file.
	set x [get_cells]
	set i 0
	set cell_list ""
	while {[lindex $x $i] != ""} {
		set a [get_full_name [lindex $x $i]]     
		#--> returns the name of instance
		lappend cell_list $a
		set i [expr {$i + 1}]
	}
	return $cell_list
}

proc getFFs {} {
	set names [all_registers -cells]
	#puts $names
	set n [llength $names]
	set ffname [get_property [lindex $names 0] full_name]

	set input_pins [all_registers -data_pins]
	#puts $input_pins
	set ffinputpin [get_property [lindex $input_pins 0] lib_pin_name]

	set ckput_pins [all_registers -clock_pins]
	#puts $ckput_pins
	set ffckpin [get_property [lindex $ckput_pins 0] lib_pin_name]

	set output_pins [all_registers -output_pins]
	#puts $output_pins
	set ffoutpin [get_property [lindex $output_pins 0] lib_pin_name]

	set finalpins "$ffname $ffinputpin $ffckpin $ffoutpin"
	#puts $finalpins
	return $finalpins
}

#END OF PROCEDURES
###################################################################

read_liberty $libpath

read_verilog "${rootPath}/${verilog}"  
#verilog with the gates necessary to evaluate pin capacitance
link_design top

set masters [getMasters]
set instances [getInstances]

#read the output file of OPENDB and takes the name of buf_pin
set f	[open "${rootPath}/inputGeneration/outdb.txt" r]
	
gets $f line
set buf_pin [lindex $line 2]
set ff_pin1 [lindex $line 3]
set ff_pin2 [lindex $line 4]
	
close $f

#gets the capacitance of the pins for all buffers in bufferList and create a list with the capacitances
for {set i 0} {$i < [llength $masters]} {incr i} {
	for {set j 0} {$i < [llength [split $bufferList " "]]} {incr j} {
		if { [lindex $bufferList $j] == [lindex $masters $i] } {
			set pin ""
    			append pin [lindex $instances $i] "/" $buf_pin
    			#puts $pin
    			lappend inPinCap [get_pincapmax $pin $rootPath ]
			break
		}
	}
}
#puts $inPinCap

set ffextract true

if {!$ffextract} {
	for {set i 0} {$i < [llength $masters]} {incr i} {
		if {[lindex $masters $i] == $ff_name } {
			set ff_name1 [lindex $instances $i]
			set ff_name2 [lindex $instances $i]
			append ff_name1 "/" $ff_pin1
			append ff_name2 "/" $ff_pin2

			set capff [get_pincapmax $ff_name1 $rootPath ]
			#puts $capff
			lappend capff [get_pincapmax $ff_name2 $rootPath ]
			#puts $capff

			#Change ff_name so that it uses the liberty name.
			set ff_name1 $ff_name
			set ff_name2 $ff_name
			append ff_name1 "/" $ff_pin1
			append ff_name2 "/" $ff_pin2

			break
		}
	}
} else {
	set ff_data [getFFs]
	set ff_name1 [lindex $ff_data 0]
	set ff_name2 [lindex $ff_data 0]

	append ff_name1 "/" [lindex $ff_data 1]
	append ff_name2 "/" [lindex $ff_data 2]

	set capff [get_pincapmax $ff_name1]
	#puts $capff
	lappend capff [get_pincapmax $ff_name2]
	#puts $capff
}


set fp [open "${rootPath}/inputGeneration/outsta.txt" w]

puts $fp "$bufferList"
puts $fp "$inPinCap"
puts $fp "$ff_name1 $ff_name2"
puts $fp "$capff"

close $fp

exit