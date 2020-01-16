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

exec ../OpenDB/build/src/swig/tcl/opendbtcl run_opendb.tcl 2> erro.txt
#puts "finished OPENDB"

exec ../OpenSTA/app/sta run_opensta.tcl 2> erro2.txt

#puts "finished OPENSTA"

set fdb	[open "./outdb.txt" r]
	
gets $fdb line1

close $fdb
file delete $fdb

set name_outpin_buf [lindex $line1 5]
set name_outpin_ff [lindex $line1 6]

set fsta	[open "./outsta.txt" r]
	
gets $fsta line2
gets $fsta line3
gets $fsta line4
gets $fsta line5


close $fsta

puts "c_sqr r_sqr inPin_buf, pin1_ff pin2_ff"
set lefcappsqr [lindex $line1 0]
set lefrespsqr [lindex $line1 1]
set exportText "set bufPinIn [lindex $line1 2]\n"
append exportText "set ffPinD [lindex $line1 3]\n"
append exportText "set ffPinClk [lindex $line1 4]\n"
append exportText "set bufPinOut [lindex $line1 5]\n"
append exportText "set ffPinQ [lindex $line1 6]\n"
#...
puts $line1
puts "capacitance values"
append exportText "set bufName [lindex $line2 0]\n"
append exportText "set bufPinInCapacitance [lindex $line3 0]\n"
puts $line2
puts $line3
#ff names
puts $line4
append exportText "set ffName [string trimright [lindex $line4 0] /[lindex $line1 3]]\n"
append exportText "set ffPinDCapacitance [lindex $line5 0]\n"
append exportText "set ffPinClkCapacitance [lindex $line5 1]\n"
#ff pinD pinCK
puts $line5

file delete $fsta
set libfile [ open "$libpath" ]
set resistanceUnitFlag 0
set capacitanceUnitFlag 0
set timeUnitFlag 0
while {[gets $libfile libLine] >= 0} {
	if {[string first "pulling_resistance_unit" $libLine ] != -1} {
		set resistanceString [ split $libLine "\"" ]
		set resistanceUnit [string toupper [string range [lindex $resistanceString 1 ] 1 end]]
		set resistanceUnitFlag 1
	} elseif {[string first "capacitive_load_unit" $libLine ] != -1} {
		set capacitanceString [ split $libLine { , \) } ]
		set capacitanceUnit  [string toupper [lindex $capacitanceString 9 ]]
		set capacitanceUnitFlag 1
	} elseif {[string first "time_unit" $libLine ] != -1} {
		set timeString [ split $libLine "\"" ]
		set timeUnit  [string toupper [string range [lindex $timeString 1 ] 1 end]]
		set timeUnitFlag 1
	}
	if { $resistanceUnitFlag && $capacitanceUnitFlag && $timeUnitFlag } {
		break
	}
}

append exportText "set timeUnit ${timeUnit}\n"
if { $timeUnit == "PS" } {
	append exportText "set time_unit 1000\n"
	set cap_unit 1000
} elseif { $timeUnit == "NS" } {
	append exportText "set time_unit 1\n"
	set cap_unit 1
} else {
	puts "Unsupported time unit (not NS or PS)."
}

append exportText "set capacitanceUnit ${capacitanceUnit}\n"
if { $capacitanceUnit == "FF" } {
	append exportText "set cap_unit 1000\n"
	append exportText "set capacitancePerUnitLength [expr ( $lefcappsqr * 1000 )]\n"
	set cap_unit 1000
} elseif { $capacitanceUnit == "PF" } {
	append exportText "set cap_unit 1\n"
	append exportText "set capacitancePerUnitLength ${lefcappsqr}\n"
	set cap_unit 1
} else {
	puts "Unsupported capacitance unit (not PF or FF)."
}

append exportText "set resistanceUnit ${resistanceUnit}\n"
if { $resistanceUnit == "KOHM" } {
	append exportText "set resistancePerUnitLength [expr ( $lefrespsqr / 1000 )]\n"
} elseif { $capacitanceUnit == "PF" } {
	append exportText "set resistancePerUnitLength ${lefrespsqr}\n"
} else {
	puts "Unsupported resistance unit (not KOHM or OHM)."
}


set maxSlew 0.060
set slewInter 0.005
set slewString ""
set slewbase $slewInter
while { $slewbase <= $maxSlew } {
	append slewString "[format %.3f $slewbase ] "
	set slewbase [expr ( $slewbase + $slewInter )]
}
set slewString [string trimright $slewString " "]
append exportText "set inputSlewList \"$slewString\"\n"


set baseLoad [expr $final_cap_interval * $cap_unit]
append exportText "set baseLoad $baseLoad\n"

set loadCounter 0
set loadString ""
set currentLoadValue 0
while { $loadCounter <= $outLoadNum } {
	append loadString "[expr int( $currentLoadValue )] "
	if { $currentLoadValue < $baseLoad } {
		set currentLoadValue [expr ( $currentLoadValue + ( $initial_cap_interval * $cap_unit ) )]
	} else {
		set currentLoadValue [expr ( $currentLoadValue + ( $final_cap_interval * $cap_unit ) )]
	}
	incr loadCounter
}

set loadString [string trimright $loadString " "]
append exportText "set loadList \"$loadString\"\n"

set newInputs [open "../automaticInputs.tcl" w]
puts $newInputs $exportText
close $newInputs
