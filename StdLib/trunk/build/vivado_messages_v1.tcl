##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

set AllowMultiDriven [expr {[info exists ::env(ALLOW_MULTI_DRIVEN)] && [string is true -strict $::env(ALLOW_MULTI_DRIVEN)]}]  

# Messages Suppression: INFO
set_msg_config -suppress -id {Synth 8-256}; # SYNTH: done synthesizing module
set_msg_config -suppress -id {Synth 8-113}; # SYNTH: binding component instance 'RTL_Inst' to cell 'PRIMITIVE'
set_msg_config -suppress -id {Synth 8-226}; # SYNTH: default block is never used
set_msg_config -suppress -id {Synth 8-312}; # SYNTH: ignoring "unsynthesizable construct" message due to assert error checking
set_msg_config -suppress -id {Synth 8-4472};# SYNTH: Detected and applied attribute shreg_extract = no
set_msg_config -suppress -id {Synth 8-637}; # SYNTH: synthesizing blackbox instance .... [required for upgrading {Synth 8-63} to an ERROR]
set_msg_config -suppress -id {Synth 8-638}; # SYNTH: synthesizing module .... [required for upgrading {Synth 8-63} to an ERROR]

set_msg_config -suppress -id {HDL 9-1061};  # SIM: Parsing VHDL file 
set_msg_config -suppress -id {Runs 36-5};   # SIM: Copied auxiliary file
set_msg_config -suppress -id {VRFC 10-163}; # SIM: Analyzing VHDL file
set_msg_config -suppress -id {VRFC 10-165}; # SIM: Analyzing VERILOG file
set_msg_config -suppress -id {Simtcl 6-16}; # SIM: Simulation closed 
set_msg_config -suppress -id {Simtcl 6-17}; # SIM: Simulation restarted 

set_msg_config -suppress -id {Drc 23-20}; # DRC: writefirst - Synchronous clocking for BRAM

# Messages Suppression: WARNING
set_msg_config -suppress -id {Designutils 20-1318};# DESIGN_UTILS: Multiple VHDL modules with the same architecture name
set_msg_config -suppress -id {Common 17-301};# DESIGN_INIT: Failed to get a license: Internal_bitstream
set_msg_config -suppress -id {Pwropt 34-142};# Post-Place Power Opt: power_opt design has already been performed within this design hierarchy. Skipping

# Messages Suppression: CRITICAL_WARNING
# TBD Place holder

# Messages Suppression: ERROR
# TBD Place holder

# Messages: Change from WARNING to ERROR
set_msg_config -id {Synth 8-3512} -new_severity ERROR;# SYNTH: Assigned value in logic is out of range 

set_msg_config -id {Synth 8-153}  -new_severity ERROR;# SYNTH: Case statement has an input that will never be executed
set_msg_config -id {Synth 8-63}   -new_severity ERROR;# SYNTH: RTL assertion
set_msg_config -id {VRFC 10-664}  -new_severity ERROR;# SIM:   expression has XXX elements ; expected XXX

# Messages: Change from WARNING to CRITICAL_WARNING
set_msg_config -id {Vivado 12-508} -new_severity "CRITICAL WARNING";# XDC: No pins matched 
set_msg_config -id {Synth 8-3330}  -new_severity "CRITICAL WARNING";# SYNTH: an empty top module top detected
set_msg_config -id {Synth 8-3919}  -new_severity "CRITICAL WARNING";# SYNTH: Null Assignment in logic

# Messages: Change from CRITICAL_WARNING to WARNING
set_msg_config -id {Vivado 12-4430} -new_severity {Warning};# Modifying [get_drc_checks REQP-52]
set_msg_config -id {Vivado 12-1387} -new_severity {Warning};# No valid object(s) found for set_false_path constraint

# TBD Place holder

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Vivado 12-1411} -new_severity ERROR;# SYNTH: Cannot set LOC property of differential pair ports
set_msg_config -id {HDL 9-806}      -new_severity ERROR;# SYNTH: Syntax error near *** (example: missing semicolon)
set_msg_config -id {Opt 31-80}      -new_severity ERROR;# IMPL: Multi-driver net found in the design
set_msg_config -id {Route 35-14}    -new_severity ERROR;# IMPL: Multi-driver net found in the design

# Check if Multi-Driven Nets are allowed
if { ${AllowMultiDriven} == 1 } {
    set_msg_config -id {Synth 8-3352} -new_severity INFO;# SYNTH: multi-driven net
} else {
    set_msg_config -id {Synth 8-3352} -new_severity ERROR;	
}

set_msg_config -id {Timing 38-3} -new_severity INFO; #User defined clocks are common and should be info, not warning.

##set_msg_config -id {Route 35-39}    -new_severity ERROR;# IMPL: The design did not meet timing requirements. 
## NOTE: we don't change this message to ERROR severity because we want to impl_1 to finish 
## and print CheckTiming procedure's statement. 
##
## Here's an example of this terminal print statement:
##
## *******************************************************
## ********************************************************
## ********************************************************
## The design did not meet timing or unable to route:
##         Setup: Worst Negative Slack (WNS): -5.121338 ns
##         Setup: Total Negative Slack (TNS): -12800.591797 ns
##         Hold: Worst Hold Slack (WHS): 0.045176 ns
##         Hold: Total Hold Slack (THS): 0.000000 ns
##         Pulse Width: Total Pulse Width Negative Slack (TPWS): 0.000000 ns
##         Routing: Number of Failed Nets: 0
## ********************************************************
## ********************************************************
## ********************************************************

# DRC: Change from ERROR to WARNING
set_property SEVERITY {Warning} [get_drc_checks {REQP-52}]; # DRC: using the GTGREFCLK port on a MGT  (GTP7 & GTX7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-44}]; # DRC: using the GTGREFCLK port on a MGT  (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-46}]; # DRC: using the GTGREFCLK port on a QPLL (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-56}]; # DRC: using the GTGREFCLK port on a QPLL (GTX7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-49}]; # DRC: using the GTGREFCLK port on a QPLL (GTP7)
set_property SEVERITY {Warning} [get_drc_checks {REQP-1753}]; # DRC: using the GTGREFCLK port on CPLL (GTH7)
set_property SEVERITY {Warning} [get_drc_checks {UCIO-1}];  # DRC: using the XADC's VP/VN ports

# DRC: Change from CRITICAL_WARNING to WARNING
set_property SEVERITY {Warning} [get_drc_checks NSTD-1];  # DRC: I/O standard (IOSTANDARD) value 'DEFAULT', instead of a user assigned specific value

# Messages: Change from ERROR to CRITICAL_WARNING
# TBD Place holder

# Target specific messages script
SourceTclFile ${VIVADO_DIR}/messages.tcl
