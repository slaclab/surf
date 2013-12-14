
# Messages Suppression: INFO
set_msg_config -suppress -id {Synth 8-256};# SYNTH: done synthesizing module
set_msg_config -suppress -id {Synth 8-113};# SYNTH: binding component instance 'RTL_Inst' to cell 'PRIMITIVE'
set_msg_config -suppress -id {Synth 8-226};# SYNTH: default block is never used
set_msg_config -suppress -id {Synth 8-312};# SYNTH: "ignoring unsynthesizable construct" due to assert error checking
set_msg_config -suppress -id {Synth 8-4472};# SYNTH: Detected and applied attribute shreg_extract = no

# Messages Suppression: WARNING
set_msg_config -suppress -id {Designutils 20-1318};# DESIGN_UTILS: Multiple VHDL modules with the same architecture name

# Messages Suppression: CRITICAL_WARNING
# TBD Place holder

# Messages: Change from WARNING to ERROR
set_msg_config -id {Synth 8-3512} -new_severity ERROR;# SYNTH: Assigned value in logic is out of range 
set_msg_config -id {Synth 8-3919} -new_severity ERROR;# SYNTH: Null Assignment in logic

# Messages: Change from WARNING to CRITICAL_WARNING
set_msg_config -id {Vivado 12-508} -new_severity "CRITICAL WARNING";# XDC: No pins matched 

# Messages: Change from CRITICAL_WARNING to WARNING
# TBD Place holder

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Synth 8-3352} -new_severity ERROR;# SYNTH: multi-driven net
set_msg_config -id {Vivado 12-1411} -new_severity ERROR;# SYNTH: Cannot set LOC property of differential pair ports

# Messages: Change from ERROR to WARNING
# TBD Place holder

# Messages: Change from ERROR to CRITICAL_WARNING
# TBD Place holder

# Set the messaging limit
set_param messaging.defaultLimit 10000
