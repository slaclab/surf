# Post .DCP generation hack to make it work with both Ultrascale and Ultrascale+

1) Open the .DCP with Vivado
```bash
vivado surf/ethernet/GigEthCore/lvdsUltraScale/ip/GigEthLvdsUltraScaleCore.dcp
```

2) Change VCO freqnecy from 625MHz to 1250MHz because Ultrascale+ VCO(min. freq) = 800MHz

```tcl
set_property CLKFBOUT_MULT_F 4.000 [get_cells U0/core_clocking_i/mmcme3_adv_inst]
set_property CLKOUT0_DIVIDE_F 10.000 [get_cells U0/core_clocking_i/mmcme3_adv_inst]
set_property CLKOUT1_DIVIDE 4 [get_cells U0/core_clocking_i/mmcme3_adv_inst]
set_property CLKOUT2_DIVIDE 2 [get_cells U0/core_clocking_i/mmcme3_adv_inst]
```

3) Save the changes
```tcl
write_checkpoint surf/ethernet/GigEthCore/lvdsUltraScale/ip/GigEthLvdsUltraScaleCore.dcp -force
```
