LLR - 09APRIL2014
After generating the original DCP file from coregen/XauiGthUltraScaleCore.xci, performed the following TCL commands in the DCP to generate a modified DCP file:

# Removed the timing constants
reset_timing

# Remove the IO Lock Constraints
set_property is_loc_fixed false [get_ports [list  xaui_rx_l0_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l1_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l2_p]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l3_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l0_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l1_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l2_p]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l3_p]]

set_property is_loc_fixed false [get_ports [list  xaui_rx_l0_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l1_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l2_n]]
set_property is_loc_fixed false [get_ports [list  xaui_rx_l3_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l0_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l1_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l2_n]]
set_property is_loc_fixed false [get_ports [list  xaui_tx_l3_n]]

# Removed the IO location Constraints
set_property package_pin "" [get_ports [list  xaui_rx_l0_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l1_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l2_p]]
set_property package_pin "" [get_ports [list  xaui_rx_l3_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l0_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l1_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l2_p]]
set_property package_pin "" [get_ports [list  xaui_tx_l3_p]]

set_property package_pin "" [get_ports [list  xaui_rx_l0_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l1_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l2_n]]
set_property package_pin "" [get_ports [list  xaui_rx_l3_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l0_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l1_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l2_n]]
set_property package_pin "" [get_ports [list  xaui_tx_l3_n]]

# Removed the Placement Constraints
set_property is_bel_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_loc_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_bel_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_loc_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_bel_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_loc_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_bel_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]]
set_property is_loc_fixed false [get_cells [list {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]]

unplace_cell  [get_cells [list  {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[3].GTHE3_CHANNEL_PRIM_INST}] -filter {((is_primitive==true && primitive_level!="INTERNAL")  && (loc!=""))}]
unplace_cell  [get_cells [list  {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[2].GTHE3_CHANNEL_PRIM_INST}] -filter {((is_primitive==true && primitive_level!="INTERNAL")  && (loc!=""))}]
unplace_cell  [get_cells [list  {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}] -filter {((is_primitive==true && primitive_level!="INTERNAL")  && (loc!=""))}]
unplace_cell  [get_cells [list  {U0/XauiGthUltraScaleCore_gt_i/inst/gen_gtwizard_gthe3_top.XauiGthUltraScaleCore_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[0].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}] -filter {((is_primitive==true && primitive_level!="INTERNAL")  && (loc!=""))}]

