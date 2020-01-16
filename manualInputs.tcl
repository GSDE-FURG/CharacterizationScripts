#Full path to liberty file.
set libpath "full path"

#Full path to lef file.
set lef_file "full path"

#Verilog that uses buffers and flip-flops (leave as-is).
set verilog "buffs_dff.v"

#To calculate the capacitance and resistance per unit length of a wire. Uses the mean from min_layer and max_layer.
set min_layer "metal4"
set max_layer "metal6"

#List of buffers to use in the characterization.
set bufferList "BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16 BUF_X32"

#Max Slew for the simulation, also defines a slew limit (2*maxSlew). Value in nS.
set maxSlew 0.060

#Slew interval and initial value. Value in nS.
set slewInter 0.005

#Cap interval and initial value. Value in fF. 
set initial_cap_interval 0.001

#New cap interval when the total load hits this value.
set final_cap_interval 0.005

#Number of different loads to be tested.
set outLoadNum 34

#Wirelengths to be tested. Separated by whitespace.
set wirelengthList "20"

#Characterization unit to be used.
set setupCharacterizationUnit 20
