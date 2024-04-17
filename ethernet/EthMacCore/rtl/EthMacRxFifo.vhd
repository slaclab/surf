-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Outbound FIFO buffers
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxFifo is
   generic (
      TPD_G             : time                   := 1 ns;
      SYNTH_MODE_G      : string                 := "inferred";
      MEMORY_TYPE_G     : string                 := "block";
      DROP_ERR_PKT_G    : boolean                := true;
      INT_PIPE_STAGES_G : natural                := 1;
      PIPE_STAGES_G     : natural                := 1;
      FIFO_ADDR_WIDTH_G : positive range 9 to 16 := 11;
      PRIM_COMMON_CLK_G : boolean                := false;
      PRIM_CONFIG_G     : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C;
      BYP_EN_G          : boolean                := false;
      BYP_COMMON_CLK_G  : boolean                := false;
      BYP_CONFIG_G      : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C;
      VLAN_EN_G         : boolean                := false;
      VLAN_SIZE_G       : positive               := 1;
      VLAN_COMMON_CLK_G : boolean                := false;
      VLAN_CONFIG_G     : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C);
   port (
      -- Clock and Reset
      sClk         : in  sl;
      sRst         : in  sl;
      -- Status/Config (sClk domain)
      phyReady     : in  sl;
      rxFifoDrop   : out sl;
      pauseThresh  : in  slv(15 downto 0);
      -- Primary Interface
      mPrimClk     : in  sl;
      mPrimRst     : in  sl;
      sPrimMaster  : in  AxiStreamMasterType;
      sPrimCtrl    : out AxiStreamCtrlType;
      mPrimMaster  : out AxiStreamMasterType;
      mPrimSlave   : in  AxiStreamSlaveType;
      -- Bypass interface
      mBypClk      : in  sl;
      mBypRst      : in  sl;
      sBypMaster   : in  AxiStreamMasterType;
      sBypCtrl     : out AxiStreamCtrlType;
      mBypMaster   : out AxiStreamMasterType;
      mBypSlave    : in  AxiStreamSlaveType;
      -- VLAN Interfaces
      mVlanClk     : in  sl;
      mVlanRst     : in  sl;
      sVlanMasters : in  AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
      sVlanCtrl    : out AxiStreamCtrlArray(VLAN_SIZE_G-1 downto 0);
      mVlanMasters : out AxiStreamMasterArray(VLAN_SIZE_G-1 downto 0);
      mVlanSlaves  : in  AxiStreamSlaveArray(VLAN_SIZE_G-1 downto 0));
end EthMacRxFifo;

architecture rtl of EthMacRxFifo is

   constant MAX_THRESH_SLV_C : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

   constant VALID_THOLD_C : natural := ite(DROP_ERR_PKT_G, 0, 1);

   type RegType is record
      rxFifoDrop      : sl;
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      rxFifoDrop      => '0',
      fifoPauseThresh => MAX_THRESH_SLV_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal primDrop  : sl                          := '0';
   signal bypDrop   : sl                          := '0';
   signal vlanDrops : slv(VLAN_SIZE_G-1 downto 0) := (others => '0');

--   attribute dont_touch      : string;
--   attribute dont_touch of r : signal is "TRUE";

begin

   U_Fifo : entity surf.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => VALID_THOLD_C,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => INT_EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PRIM_CONFIG_G)
      port map (
         sAxisClk        => sClk,
         sAxisRst        => sRst,
         sAxisMaster     => sPrimMaster,
         sAxisCtrl       => sPrimCtrl,
         sAxisDropFrame  => primDrop,
         fifoPauseThresh => r.fifoPauseThresh,
         mAxisClk        => mPrimClk,
         mAxisRst        => mPrimRst,
         mAxisMaster     => mPrimMaster,
         mAxisSlave      => mPrimSlave);

   BYP_DISABLED : if (BYP_EN_G = false) generate
      sBypCtrl   <= AXI_STREAM_CTRL_UNUSED_C;
      mBypMaster <= AXI_STREAM_MASTER_INIT_C;
   end generate;

   BYP_ENABLED : if (BYP_EN_G = true) generate
      U_Fifo : entity surf.SsiFifo
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => VALID_THOLD_C,
            -- FIFO configurations
            SYNTH_MODE_G        => SYNTH_MODE_G,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
            FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
            FIFO_FIXED_THRESH_G => false,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => INT_EMAC_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => BYP_CONFIG_G)
         port map (
            sAxisClk        => sClk,
            sAxisRst        => sRst,
            sAxisMaster     => sBypMaster,
            sAxisCtrl       => sBypCtrl,
            sAxisDropFrame  => bypDrop,
            fifoPauseThresh => r.fifoPauseThresh,
            mAxisClk        => mBypClk,
            mAxisRst        => mBypRst,
            mAxisMaster     => mBypMaster,
            mAxisSlave      => mBypSlave);
   end generate;

   VLAN_DISABLED : if (VLAN_EN_G = false) generate
      sVlanCtrl    <= (others => AXI_STREAM_CTRL_UNUSED_C);
      mVlanMasters <= (others => AXI_STREAM_MASTER_INIT_C);
   end generate;

   VLAN_ENABLED : if (VLAN_EN_G = true) generate
      GEN_VEC : for i in (VLAN_SIZE_G-1) downto 0 generate
         U_Fifo : entity surf.SsiFifo
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
               PIPE_STAGES_G       => PIPE_STAGES_G,
               SLAVE_READY_EN_G    => false,
               VALID_THOLD_G       => VALID_THOLD_C,
               -- FIFO configurations
               SYNTH_MODE_G        => SYNTH_MODE_G,
               MEMORY_TYPE_G       => MEMORY_TYPE_G,
               GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
               FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
               FIFO_FIXED_THRESH_G => false,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => INT_EMAC_AXIS_CONFIG_C,
               MASTER_AXI_CONFIG_G => VLAN_CONFIG_G)
            port map (
               sAxisClk        => sClk,
               sAxisRst        => sRst,
               sAxisMaster     => sVlanMasters(i),
               sAxisCtrl       => sVlanCtrl(i),
               sAxisDropFrame  => vlanDrops(i),
               fifoPauseThresh => r.fifoPauseThresh,
               mAxisClk        => mVlanClk,
               mAxisRst        => mVlanRst,
               mAxisMaster     => mVlanMasters(i),
               mAxisSlave      => mVlanSlaves(i));
      end generate GEN_VEC;
   end generate;

   comb : process (bypDrop, pauseThresh, phyReady, primDrop, r, sRst,
                   vlanDrops) is
      variable v    : RegType;
      variable drop : sl;
   begin
      -- Latch the current value
      v := r;

      -- OR-ing drop flags together
      v.rxFifoDrop := primDrop or bypDrop or uOr(vlanDrops);

      -- Check the programmable threshold
      if pauseThresh >= (2**FIFO_ADDR_WIDTH_G)-1 then
         v.fifoPauseThresh := MAX_THRESH_SLV_C;
      else
         v.fifoPauseThresh := pauseThresh(FIFO_ADDR_WIDTH_G-1 downto 0);
      end if;

      -- Outputs
      rxFifoDrop <= r.rxFifoDrop;

      -- Reset
      if (sRst = '1') or (phyReady = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sClk) is
   begin
      if rising_edge(sClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
