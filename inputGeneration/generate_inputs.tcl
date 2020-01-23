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
source ${rootPath}/scripts/functions_file.tcl

#Gets data from OpenDB
exec ${rootPath}/OpenDB/build/src/swig/tcl/opendbtcl ${rootPath}/inputGeneration/run_opendb.tcl "${rootPath}" 2> ${rootPath}/inputGeneration/opendb_log.txt

#Gets data from OpenSTA
exec ${rootPath}/OpenSTA/app/sta -no_splash ${rootPath}/inputGeneration/run_opensta.tcl 2> ${rootPath}/inputGeneration/opensta_log.txt

#Opens the OpenDB report.
set fdb	[open "${rootPath}/inputGeneration/outdb.txt" r]
	
gets $fdb line1

close $fdb
file delete $fdb

#Gets buffer and flip-flop names.
set name_outpin_buf [lindex $line1 5]
set name_outpin_ff [lindex $line1 6]

#Opens the OpenSTA report.
set fsta	[open "${rootPath}/inputGeneration/outsta.txt" r]
	
gets $fsta line2
gets $fsta line3
gets $fsta line4
gets $fsta line5


close $fsta

#Gets multiple values (capacitance per unit length, resistance per unit length, pin capacitances...).
puts "c_sqr r_sqr inPin_buf, pin1_ff pin2_ff"
set lefcappsqr [lindex $line1 0]
set lefrespsqr [lindex $line1 1]
set exportText "set bufPinIn [lindex $line1 2]\n"
append exportText "set ffPinD [lindex $line1 3]\n"
append exportText "set ffPinClk [lindex $line1 4]\n"
append exportText "set bufPinOut [lindex $line1 5]\n"
append exportText "set ffPinQ [lindex $line1 6]\n"
puts $line1
puts "capacitance values"
append exportText "set bufName [lindex $line2 0]\n"
append exportText "set bufPinInCapacitance [lindex $line3 0]\n"
puts $line2
puts $line3
puts $line4
#Gets flip-flop name and pin capacitances.
append exportText "set ffName [string trimright [lindex $line4 0] /[lindex $line1 3]]\n"
append exportText "set ffPinDCapacitance [lindex $line5 0]\n"
append exportText "set ffPinClkCapacitance [lindex $line5 1]\n"
puts $line5

file delete $fsta

#Opens the liberty file in order to obtain the units.
set libfile [ open "$libpath" ]
#Boolean flags that check if we have found all the units we need.
set resistanceUnitFlag 0
set capacitanceUnitFlag 0
set timeUnitFlag 0
#For each line of the liberty file...
while {[gets $libfile libLine] >= 0} {
	#Check if a substring is present on the line. If yes, splits the line and obtains the unit.
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

#Sets the base unit as ns. If a value is ps, set a multiplier as 1000.
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

#Sets the base unit as pf. If a value is ff, set a multiplier as 1000. Also updates the capacitance per unit length value if needed, since it is fixed on pf.
append exportText "set capacitanceUnit ${capacitanceUnit}\n"
if { $capacitanceUnit == "FF" } {
	append exportText "set cap_unit 1000\n"
	append exportText "set capacitancePerUnitLength [truncateNum [format %.12f [expr ( $lefcappsqr * 1000 )]]]\n"
	set cap_unit 1000
} elseif { $capacitanceUnit == "PF" } {
	append exportText "set cap_unit 1\n"
	append exportText "set capacitancePerUnitLength ${lefcappsqr}\n"
	set cap_unit 1
} else {
	puts "Unsupported capacitance unit (not PF or FF)."
}

#Sets the base unit as ohm. Updates the resistance per unit length if needed, since it is fixed on ohm.
append exportText "set resistanceUnit ${resistanceUnit}\n"
if { $resistanceUnit == "KOHM" } {
	append exportText "set resistancePerUnitLength [truncateNum [format %.12f [expr ( $lefrespsqr / 1000 )]]]\n"
} elseif { $capacitanceUnit == "PF" } {
	append exportText "set resistancePerUnitLength ${lefrespsqr}\n"
} else {
	puts "Unsupported resistance unit (not KOHM or OHM)."
}

#Generates the slew list, a list that goes from slewInter to maxSlew in slewInter intervals.
set slewString ""
set slewbase $slewInter
while { $slewbase <= $maxSlew } {
	set slewNumber [format %.12f $slewbase ]
	set slewNumber [truncateNum $slewNumber]
	append slewString "${slewNumber} "
	set slewbase [expr double( $slewbase + $slewInter )]
}
set slewString [string trimright $slewString " "]
append exportText "set inputSlewList \"$slewString\"\n"

#Creates the base load variable, which defines when the load interval needs to change.
set baseLoad [expr $final_cap_interval * $cap_unit]
append exportText "set baseLoad $baseLoad\n"

#Creates the load list, a list that has outloadnum + 1 (0) elements. If the current load value is lower than baseLoad, we use the initial_cap_interval as an interval (currentvalue + initial_cap_interval); if not, we use the final_cap_interval. 
set loadCounter 0
set loadString ""
set currentLoadValue 0.0
while { $loadCounter <= $outLoadNum } {
	set loadNumber [format %.12f ${currentLoadValue}]
	set loadNumber [truncateNum $loadNumber]
	append loadString "${loadNumber} "
	if { $currentLoadValue < $baseLoad } {
		set currentLoadValue [expr double( $currentLoadValue + double( $initial_cap_interval * $cap_unit ) )]
	} else {
		set currentLoadValue [expr double( $currentLoadValue + double( $final_cap_interval * $cap_unit ) )]
	}
	incr loadCounter
}

set loadString [string trimright $loadString " "]
append exportText "set loadList \"$loadString\"\n"

#Exports the automatic inputs file.
set newInputs [open "${rootPath}/automaticInputs.tcl" w]
puts $newInputs $exportText
close $newInputs
