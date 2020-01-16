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


#here are the inputs necessary to run OPENSTA
read_liberty "$libpath"

read_verilog "../$verilog"  

#verilog with the gates necessary to evaluate pin capacitance
link_design top


proc get_pincapmax {pin_nm} { #pin_nm is the name of an instance in verilog description and the respective node. ex: BUF_X1/A
	
	report_pin $pin_nm > pin.rpt
	set pin_rpt [open "./pin.rpt" r]
	set line [read $pin_rpt]
	if { [ string is integer -strict [lindex $line 3] ] } {
		set pinCap [lindex $line 3]

		close $pin_rpt
		file delete pin.rpt

		return $pinCap
	} else {
		set r_cap [lindex $line 4]
		set f_cap [lindex $line 6]

		close $pin_rpt
		file delete pin.rpt
		

		

		if {$r_cap > $f_cap} {
			return $r_cap
		} else {
			return $f_cap
		}
		
	}
}





#read the output file of OPENDB and takes the name of buf_pin
set f	[open "./outdb.txt" r]
	
gets $f line
set buf_pin [lindex $line 2]
set ff_pin1 [lindex $line 3]
set ff_pin2 [lindex $line 4]
	
close $f

#gets the capacitance of the pins for all buffers in bufferList and create a list with the capacitances
foreach i $bufferList {
    set pin ""
    append pin $i "/" $buf_pin
    #puts $pin
    lappend inPinCap [get_pincapmax $pin]
}
puts $inPinCap

set ff_name1 "DFF_X1"
set ff_name2 "DFF_X1"
append ff_name1 "/" $ff_pin1
append ff_name2 "/" $ff_pin2

set capff [get_pincapmax $ff_name1]
puts $capff
lappend capff [get_pincapmax $ff_name2]
puts $capff

set fp [open outsta.txt w]

puts $fp "$bufferList"
puts $fp "$inPinCap"
puts $fp "$ff_name1 $ff_name2"
puts $fp "$capff"

close $fp

exit
