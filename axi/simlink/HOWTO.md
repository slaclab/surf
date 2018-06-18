# Software-Firmware co-simulation with VCS and Rogue

## Instantiate `RogueStreamSimWrap`

The firmware will need an instance of `RogueStreamSimWrap` per Virtual Channel / TDEST.

For cases where a PGP2b interface is being emulated, you can use `RoguePgpSim` instead.
This will instantiate 4 `RogueStreamSimWrap` instances, one per VC. It will also
instantiate a 5th instance specifically for OpCodes.

Example:

``` VHDL
SIM_GEN : if (SIMULATION_G) generate
   DESTS : for i in 1 downto 0 generate
    U_RogueStreamSimWrap_1 : entity work.RogueStreamSimWrap
         generic map (
            TPD_G               => TPD_G,
            DEST_ID_G           => i,
            USER_ID_G           => 1,
            COMMON_MASTER_CLK_G => true,
            COMMON_SLAVE_CLK_G  => true,
            AXIS_CONFIG_G       => AXIS_CONFIG_C)
         port map (
            clk         => ethClk,            -- [in]
            rst         => ethRst,            -- [in]
            sAxisClk    => ethClk,            -- [in]
            sAxisRst    => ethRst,            -- [in]
            sAxisMaster => rssiIbMasters(i),  -- [in]
            sAxisSlave  => rssiIbSlaves(i),   -- [out]
            mAxisClk    => ethClk,            -- [in]
            mAxisRst    => ethRst,            -- [in]
            mAxisMaster => rssiObMasters(i),  -- [out]
            mAxisSlave  => rssiObSlaves(i));  -- [in]
   end generate DESTS;
end generate SIM_GEN;
```