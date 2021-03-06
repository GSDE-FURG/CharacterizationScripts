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

source ${rootPath}/manualInputs.tcl

proc createVerilog {buf_list buf_inpin buf_outpin ff_name ff_inpin ff_ckpin ff_outpin rootPath} {

	#header of the verilog file
	set text "module top (clk, out);\n"
	append text "input clk;\n"
	append text "output out;\n\n"
	#generation of all buffers on verilog file
	for {set i 0} {$i < [llength $buf_list]} {incr i} {
		append text "[lindex $buf_list $i] a$i (.$buf_inpin (dummy), .$buf_outpin (out));\n"
	}

	append text "$ff_name a$i (.$ff_inpin (dummy), .$ff_ckpin (clk), .$ff_outpin (out));\n\n"

	append text "endmodule"

set fp [open "${rootPath}/buffs_dff.v" w]

puts $fp $text

close $fp
}




#SCRIPT

# Open database and load LEF
set db [dbDatabase_create]

set lib [odb_read_lef $db $lef_file]

if {$lib == "NULL"} {
    puts "Failed to read LEF file"
    exit 1
}

set tech [$lib getTech]
set layers [$tech getLayers]
set gates [$lib getMasters]

#here is a search to find the $min_layer and max_layer indexes in the layers list
set min_index 0
set max_index 0
foreach i $layers {
    if { [$i getName] == $min_layer} {
	break
	}
    incr min_index
}

foreach i $gates {
    if { [$i getName] == [lindex $bufferList 0] } {
	set a [$i getMTerms]
	set input_pin_buf [[lindex $a 0] getName]
	set output_pin_buf [[lindex $a 1] getName]
	puts "BUF name: [$i getName] found!"
	puts "Input pin: $input_pin_buf"
	puts "Output pin: $output_pin_buf"
	break
    }	
}
set ffsource false
#false determines the stable execution, true is using the isSequential function of OpenDB
if { !$ffsource } {
	foreach i $gates {
	   if { [$i getName] == $ff_name} {
		set a [$i getMTerms]
		set input1_pin_ff [[lindex $a 0] getName]
		set input2_pin_ff [[lindex $a 1] getName]
		set output_pin_ff [[lindex $a 2] getName]
		puts "DFF name: [$i getName] found!" 
		puts "Input pins: $input1_pin_ff $input2_pin_ff"
		puts "Output pin: $output_pin_ff"
		break
	   }
	}
} else {
	foreach i $gates {
	   if { [$i isSequential]} {
		set a [$i getMTerms]
		set input1_pin_ff [[lindex $a 0] getName]
		set input2_pin_ff [[lindex $a 1] getName]
		set output_pin_ff [[lindex $a 2] getName]
		puts "FF name: [$i getName] found!" 
		puts "Input pins: $input1_pin_ff $input2_pin_ff"
		puts "Output pin: $output_pin_ff"
		break
	    }
	}
}

foreach i $layers {
    if { [$i getName] == $max_layer} {
	break
	}
    incr max_index
}


createVerilog $bufferList $input_pin_buf $output_pin_buf $ff_name $input1_pin_ff $input2_pin_ff $output_pin_ff $rootPath


#definition and extraction of r_sqr and c_sqr of max_layer and min_layer
set minlayer [lindex $layers $min_index]
set min_capacitance [$minlayer getCapacitance] 
set min_resistance [$minlayer getResistance] 

if {($min_capacitance == 0) || ($min_resistance == 0) } {
	puts "WARNING: The minimum layer defined DID NOT PRESENT any value for C or R!"
	puts "Please revise the LEF file."
	puts "ABORTING OPERATION"
	return 0
}

set maxlayer [lindex $layers $max_index]
set max_capacitance [$maxlayer getCapacitance] 
set max_resistance [$maxlayer getResistance] 

if {($max_capacitance == 0) || ($max_resistance == 0) } {
	puts "WARNING: The maximum layer defined DID NOT PRESENT any value for C or R!"
	puts "ABORTING OPERATION"
	puts "Please revise the LEF file."
	return 0
}


puts "$min_capacitance $min_resistance $max_capacitance $max_resistance"


#mean of max_layer and min_layer values (c_sqr and r_sqr)
set c_sqr [expr {($min_capacitance + $max_capacitance)/2}]
set r_sqr [expr {($min_resistance + $max_resistance)/2}]

puts "$c_sqr $r_sqr"

set fp [open "${rootPath}/inputGeneration/outdb.txt" w]

puts $fp "$c_sqr $r_sqr $input_pin_buf $input1_pin_ff $input2_pin_ff $output_pin_buf $output_pin_ff"

close $fp


