
# false path constraints to async inputs coming directly to synchronizer

set_false_path -to [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/gb0/*_dom_ch_reg/D }]
set_false_path -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/rxclk_r_reg/D}]

set_false_path -from [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/gb0/loop0[*].dataout_reg[*]/D }]
set_false_path -from [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/gb0/loop0[*].dataout_reg[*]/D }]
set_false_path -from [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/rxdh*/D }]

set_false_path -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/iserdes_m/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/iserdes_s/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/oserdes_m/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */SALT_IDELAY_CTRL_Inst/RST }]

set_false_path -from [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/gb0/read_enable_dom_ch_reg/D}] 
set_false_path -from [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/gb0/read_enabler_reg/D}]

set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]
set_false_path -to [get_pins -hier -filter { name =~ */*crossDomainSyncReg_reg*/PRE } ]
set_false_path -to [get_pins -hier -filter { name =~ */TX_ENABLE.SaltTx_Inst/SERDES_Inst/*/syncRst_reg/PRE } ]
set_false_path -to [get_pins -hier -filter { name =~ */RX_ENABLE.SaltRx_Inst/SERDES_Inst/*/syncRst_reg/PRE } ]
