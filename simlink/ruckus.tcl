# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load reusable, simulator-neutral simulation components. Test-only HDL under
# test/ is supplied explicitly by the tests/simlink runners and is never part
# of a normal SURF import.
loadSource -lib surf -sim_only -dir "$::DIR_PATH/sim"

# The interchangeable backend directories. Each one declares the same VHDL
# entity and architecture names (RogueTcpStream, RogueTcpMemory, RogueSideBand)
# in library surf, so exactly one may be in the project at a time. Single source
# of truth for both the validity check and the sibling purge below.
set simBackendList {ghdl vcs xsim}

# Select the simulator backend. ruckus exports RUCKUS_SIM_BACKEND for every
# target that actually runs a simulator: "make xsim" and "make gui" request
# xsim, "make vcs" requests vcs, and system_ghdl.mk requests ghdl. Every other
# Vivado target (bit, syn, dcp, prom, mcs, pdi, msim, batch, interactive,
# sources) leaves it unset and falls back to xsim, the only simulator a
# persisted Vivado project can launch on its own. That keeps bit/syn/dcp/gui/
# xsim in agreement, so the common target switch costs no add/remove churn.
#
# GHDLFLAGS is still honored ahead of that default because it is the one signal
# that is guaranteed present in a GHDL analysis run: SURF's own Makefile exports
# it unconditionally, so "make analysis" stays on the ghdl backend even against
# a ruckus predating the RUCKUS_SIM_BACKEND export. Handing GHDL the xsim
# backend would be fatal rather than merely wrong, because that backend pulls in
# SystemVerilog DPI leaves that GHDL cannot parse.
#
# VCS_VERSION is deliberately NOT sniffed. Site setup scripts commonly source
# Vivado and VCS in one shell, so VCS_VERSION is set even for a pure Vivado
# user, which made "make bit" persist the vcs backend while "make gui"
# persisted xsim into the same project, colliding in library surf.
if { [info exists ::env(RUCKUS_SIM_BACKEND)] } {
   set simBackend $::env(RUCKUS_SIM_BACKEND)
} elseif { [info exists ::env(GHDLFLAGS)] } {
   set simBackend "ghdl"
} else {
   set simBackend "xsim"
}

# Validate before touching the project. An unsupported value would otherwise
# purge every real backend first and only then fail inside loadSource, leaving a
# persisted project with no backend at all.
if { [lsearch -exact ${simBackendList} ${simBackend}] < 0 } {
   puts "\n\n\n\n\n********************************************************"
   puts "simlink/ruckus.tcl: RUCKUS_SIM_BACKEND=${simBackend} is not a SimLink backend"
   puts "Supported backends: ${simBackendList}"
   puts "********************************************************\n\n\n\n\n"
   exit -1
}

# Purge the sibling backends from sim_1 before loading the selected one. The
# Vivado project persists across make targets (vivado/project.tcl re-opens an
# existing .xpr and vivado/sources.tcl re-runs for every target), so switching
# backends would otherwise leave two copies of RogueTcpStream(RogueTcpStream) in
# library surf and fail with "[filemgmt 20-1318] Duplicate Design Unit". Guarded
# on VIVADO_VERSION because get_files/remove_files are Vivado-only; the GHDL,
# Design Compiler, and Genus flows set it to -1.0 and re-analyze from scratch
# with no project to clean. The [info exists] test matters because the
# standalone system_vcs.mk flow never defines VIVADO_VERSION at all.
if { [info exists ::env(VIVADO_VERSION)] && $::env(VIVADO_VERSION) > 0.0 } {
   # Match on the file's directory, anchored on the last two path components
   # (for example "simlink/vcs"). An absolute pattern cannot be used here: the
   # .xpr stores paths relative to $PPRDIR and can reach this repository through
   # a different symlink prefix than [file normalize] resolves to, so an
   # absolute pattern silently matches nothing even when the stale files are
   # present. Anchoring two components also keeps a project that merely lives
   # under some directory named "vcs" from matching everything in sim_1.
   set simlinkTail [file tail $::DIR_PATH]
   # Enumerate sim_1 membership rather than the Rogue*.vhd base names, so the
   # backend-specific SystemVerilog DPI leaves under xsim/ are purged too.
   set simFiles [get_files -quiet -of_objects [get_filesets sim_1]]
   foreach other ${simBackendList} {
      if { ${other} eq ${simBackend} } {
         continue
      }
      set staleFiles ""
      foreach simFile ${simFiles} {
         if { [string match "*/${simlinkTail}/${other}" [file dirname ${simFile}]] } {
            lappend staleFiles ${simFile}
         }
      }
      # -fileset is explicit because remove_files defaults to the current source
      # fileset (sources_1), where these simulation-only files do not live. No
      # -quiet, so a genuine removal failure is reported instead of silently
      # leaving a duplicate design unit behind.
      if { [llength ${staleFiles}] > 0 } {
         puts "simlink/ruckus.tcl: removing stale ${other} backend sources from sim_1"
         remove_files -fileset sim_1 ${staleFiles}
      }
   }
}

# Load the selected backend
loadSource -lib surf -sim_only -dir "$::DIR_PATH/${simBackend}"
