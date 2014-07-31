
# Custom Procedure Script

###############################################################
#### General Functions ########################################
###############################################################

proc VivadoRefresh { vivadoHlsProject } {
   close_project
   open_project ${vivadoHlsProject}
}

# Custom TLC source function
proc SourceTclFile { filePath } {
   set src_rc [catch { 
      puts "source ${filePath}"
      source ${filePath}
   } _RESULT] 
   if {$src_rc} { 
      return false;
   } else {
      return true;
   }
}

# Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}