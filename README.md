# CharacterizationScripts
Generates lookup tables for buffered and non-buffered wire segments delimited by flip-flops. The lookup tables are used as building blocks for clock tree construction and store information about delay, power, output slew and input capacitance of the wire segments.

These scripts also uses an OpenSTA and OpenDB binary, you should follow [these](https://github.com/The-OpenROAD-Project/OpenSTA/blob/master/README.md) and [these](https://github.com/The-OpenROAD-Project/OpenDB/blob/master/README.md) steps in order to create one while inside their respective folders in this repository.

To generate the lookup tables, follow these steps:

* Edit manualInputs.tcl with a lib and lef file (you can also edit other parameters).
* Build a new OpenSTA binary as explained above.
* Build a new OpenDB binary as explained above.
* Run the run_characterization.tcl script (may need execute permissions).
* Get the resulting LUT files (same folder as the run_characterization.tcl script).
