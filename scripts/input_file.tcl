set cap_unit 1000
set capacitanceUnit "FF"
set capacitancePerUnitLength 1.774000e-01

set resistanceUnit "KOHM"
set resistancePerUnitLength 3.571429e-03 

set maxSlew 0.060
set slewInter 0.005

set inputSlewList "0.005 0.01 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.06"

set baseLoad [expr 0.005 * $cap_unit]
set initial_cap_interval 0.001
set final_cap_interval 0.005

set loadList "0 1 2 3 4 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150"

set bufferList "BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16 BUF_X32"
set bufName [ lindex $bufferList 0 ]

set bufPinIn "A"
set bufPinOut "Z"
set bufPinInCapacitance 12.270698

set ffName "DFF_X1"
set ffPinQ "Q"	
set ffPinD "D"
set ffPinClk "CK"
set ffPinDCapacitance 1.092061
set ffPinClkCapacitance 0.890272

set wirelengthList "20 40"
set setupCharacterizationUnit 20
set libpath "../example1_slow.lib"

