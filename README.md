# CharacterizationScripts
Generates lookup tables for buffered and non-buffered wire segments delimited by flip-flops. The lookup tables are used as building blocks for clock tree construction and store information about delay, power, output slew and input capacitance of the wire segments.

These scripts also uses an OpenSTA binary, you should follow these [steps](https://github.com/The-OpenROAD-Project/OpenSTA/blob/master/README.md) in order to create one while inside the OpenSTA folder of this repository.

To generate the lookup tables, follow these steps:

* Build a new OpenSTA binary as explained above.
* Run the run_characterization.tcl script (may need execute permissions).
* Get the resulting LUT files from scripts/exported_luts
