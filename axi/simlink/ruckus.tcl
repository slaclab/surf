# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

# Select the simulator backend. Prefer the backend explicitly requested by the
# ruckus make target (make xsim/gui -> xsim, make vcs -> vcs). Fall back to
# environment sniffing for older ruckus. Note: sniffing VCS_VERSION alone is
# unreliable because users commonly source both Vivado and VCS in one setup
# script, so VCS_VERSION is set even during a Vivado xsim run.
if {[info exists ::env(RUCKUS_SIM_BACKEND)]} {
   set simBackend $::env(RUCKUS_SIM_BACKEND)
} elseif {[info exists ::env(GHDLFLAGS)]} {
   set simBackend "ghdl"
} elseif {[info exists ::env(VCS_VERSION)]} {
   set simBackend "vcs"
} else {
   set simBackend "xsim"
}

# When re-generating an existing Vivado project, purge sibling-backend sources
# so switching backends doesn't leave duplicate RogueTcp* entities in sim_1.
# Only remove when present, to avoid needless add/remove churn in the project.
# Guard on VIVADO_VERSION because get_files/remove_files are Vivado-only; GHDL
# re-analyzes from scratch and has no persistent project to clean.
if {$::env(VIVADO_VERSION) > 0.0} {
   foreach other {ghdl vcs xsim} {
      if {${other} ne ${simBackend}} {
         set staleFiles [get_files -quiet [file normalize "$::DIR_PATH/${other}/*"]]
         if {[llength ${staleFiles}] > 0} {
            remove_files -quiet ${staleFiles}
         }
      }
   }
}

# Load the selected backend
loadSource -lib surf -sim_only -dir "$::DIR_PATH/${simBackend}"
