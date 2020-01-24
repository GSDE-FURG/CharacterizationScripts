

#script for testing the exampleinputs1.tcl
#defines an OpenDB execution using a LEF file
#examines if r_cap and c_cap are extracted correctly
proc find_parent_dir { dir } {
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


#returns the directory where the script is located
set current_dir [file dirname [file normalize [info script]]]

#gets the directory that is 2 folders up from current_dir
set base_dir [find_parent_dir [find_parent_dir $current_dir]]

set OPENDB_dir [file join $base_dir "OpenDB/build/src/swig/tcl/opendbtcl"]

#puts $OPENDB_dir
set uut [file join $base_dir "inputGeneration/run_opendb.tcl"]
#puts $uut
exec $OPENDB_dir "$uut" "${base_dir}" 2> "${base_dir}/inputGeneration/opendb_log.txt"

set fexist [ file exist "${base_dir}/inputGeneration/opendb_log.txt" ]
#puts $fexist

if {$fexist ==1} {

	set fp [ open "${base_dir}/inputGeneration/outdb.txt" r]
	gets $fp line

	if { [ string trim $line ] != ""} {
   		set c_cap [ lindex $line 0]
   		set r_cap [ lindex $line 1]

   		if {  [string length $r_cap] != 0  &&  [string length $c_cap] != 0  } {
			puts "GREEN: Values obtained correctly."
   			return 0
   		} else{
			puts "RED: Error when obtaining r_sqr and c_sqr."
   			return 1
   		}

   	} else {
		puts "RED: Error when obtaining r_sqr and c_sqr."
   		return 1
   	}
} else {
	puts "RED: Error when obtaining r_sqr and c_sqr."
	return 1
}
