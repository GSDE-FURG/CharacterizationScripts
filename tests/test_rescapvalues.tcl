

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


#retorna o diretório do script que está sendo executado
set current_dir [file dirname [file normalize [info script]]]

#a função find_parent_dir faz um comando "cd .." no diretório
set base_dir [find_parent_dir $current_dir]

#por fim, entramos na pasta "data" que seria uma outra pasta que está no mesmo nível da pasta em que está o script
#ex:: caminho do script --> /home/gsde/tcl
#caminho da pasta data ---> /home/gsde/data
set data_dir [file join $base_dir "inputGeneration"]
#puts $data_dir

set OPENDB_dir [file join $base_dir "OpenDB/build/src/swig/tcl/opendbtcl"]

#puts $OPENDB_dir
set uut [file join $data_dir "run_opendb.tcl"]
#puts $uut
exec $OPENDB_dir "$uut" 2> opendb_log.txt

set fexist [ file exist [ file join $current_dir "outdb.txt"] ]
#puts $fexist

if {$fexist ==1} {

	set fp [ open outdb.txt r]
	gets $fp line

	if { [ string trim $line ] != ""} {
   		set c_cap [ lindex $line 0]
   		set r_cap [ lindex $line 1]

   		if {  [string length $r_cap] != 0  &&  [string length $c_cap] != 0  } {
   			return 0
   		} else{
   			return 1
   		}

   	} else {
   		return 1
   	}
} else {
	return 1
}