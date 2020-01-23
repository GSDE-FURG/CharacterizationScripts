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
source ../manualInputs.tcl
<<<<<<< Updated upstream

=======
set verilog "../buffs_dff.v"
>>>>>>> Stashed changes

proc get_pincapmax {pin_nm} {
	#Uses OpenSTA to generate a report on the pin capacitance. It results in one line that can be in a few different formats depending on the liberty file.
	report_pin $pin_nm > pin.rpt
	set pin_rpt	[open "./pin.rpt" r]
	set line [read $pin_rpt]
#puts [lindex $line 1]
#puts	[get_property [get_lib_cells -of_objects [get_cells -of_objects [lindex $line 1] ]	] full_name]
	#One format is when there is only one capacitance in the liberty file, thus, the 3rd word in the pin report will be a number.
	if { [ string is double -strict [lindex $line 3] ] } {	
		set pinCap [lindex $line 3]
	} elseif {[string first ":" [lindex $line 3] ] != -1} {	
		#However, that word could be an interval (string contains ":"). If so, we have to get the upper limit of the pin capacitance.
		set pinCap [lindex [split [lindex $line 3] ":"] 1]
	} else {
		#Another format is when there is a fall capacitance and a rise capacitance. In this case, we will return the higher one of the two.
		set r_cap [lindex $line 4]
		set f_cap [lindex $line 6]

		if {[string first ":" r_cap ] != -1} {	
			#These values can also can be an interval (string contains ":"). 
			puts "$r_cap $c_cap"
			set r_cap [lindex [split $r_cap ":"] 1]
   			set f_cap [lindex [split $f_cap ":"] 1]
		}
		
		if {$r_cap > $f_cap} {
			set pinCap $r_cap
		} else {
			set pinCap $f_cap
		}
	}

	#Closes and deletes the pin report file and returns the pin capacitance.
	close $pin_rpt
	file delete pin.rpt

	return $pinCap
}

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
<<<<<<< Updated upstream

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
#END OF PROCEDURES
###################################################################

=======

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
#END OF PROCEDURES
###################################################################

>>>>>>> Stashed changes
read_liberty $libpath

read_verilog $verilog  
#verilog with the gates necessary to evaluate pin capacitance
link_design top

set masters [getMasters]
set instances [getInstances]

#read the output file of OPENDB and takes the name of buf_pin
set f	[open "./outdb.txt" r]
	
gets $f line
set buf_pin [lindex $line 2]
set ff_pin1 [lindex $line 3]
set ff_pin2 [lindex $line 4]
	
close $f

#gets the capacitance of the pins for all buffers in buf_list and create a list with the capacitances
for {set i 0} {$i < [llength $masters]} {incr i} {
	for {set j 0} {$i < [llength [split $bufferList " "]]} {incr j} {
		if { [lindex $bufferList $j] == [lindex $masters $i] } {
			set pin ""
    			append pin [lindex $instances $i] "/" $buf_pin
    			#puts $pin
    			lappend inPinCap [get_pincapmax $pin]
			break
		}
	}
}
#puts $inPinCap

for {set i 0} {$i < [llength $masters]} {incr i} {
	if {[lindex $masters $i] == $ff_name } {
		set ff_name1 [lindex $instances $i]
		set ff_name2 [lindex $instances $i]
		append ff_name1 "/" $ff_pin1
		append ff_name2 "/" $ff_pin2

		set capff [get_pincapmax $ff_name1]
		#puts $capff
		lappend capff [get_pincapmax $ff_name2]
		#puts $capff
		break
	}

}


set fp [open outsta.txt w]

puts $fp "$bufferList"
puts $fp "$inPinCap"
puts $fp "$ff_name1 $ff_name2"
puts $fp "$capff"

close $fp

exit
