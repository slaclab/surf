-------------------------------------------------------------------------------
-- File       : EthMacRxFifo.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-21
-- Last update: 2016-10-21
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.EthMacPkg.all;

entity EthMacRxFifo is
   generic (
      TPD_G               : time                := 1 ns;
      DROP_ERR_PKT_G      : boolean             := true;
      INT_PIPE_STAGES_G   : natural             := 1;
      PIPE_STAGES_G       : natural             := 1;
      FIFO_ADDR_WIDTH_G   : positive            := 10;
      CASCADE_SIZE_G      : positive            := 2;
      FIFO_PAUSE_THRESH_G : positive            := 1000;
      CASCADE_PAUSE_SEL_G : natural             := 0;
      PRIM_COMMON_CLK_G   : boolean             := false;
      PRIM_CONFIG_G       : AxiStreamConfigType := EMAC_AXIS_CONFIG_C;
      BYP_EN_G            : boolean             := false;
      BYP_COMMON_CLK_G    : boolean             := false;
      BYP_CONFIG_G        : AxiStreamConfigType := EMAC_AXIS_CONFIG_C;
      VLAN_EN_G           : boolean             := false;
      VLAN_SIZE_G         : positive            := 1;
      VLAN_COMMON_CLK_G   : boolean             := false;
      VLAN_CONFIG_G       : AxiStreamConfigType := EMAC_AXIS_CONFIG_C);
   port (
      -- Clock and Reset
      sClk         : in  sl;
      sRst         : in  sl;
      -- Status (sClk domain)
      phyReady     : in  sl;
      rxFifoDrop   : out sl;
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

   constant VALID_THOLD_C : natural := ite(DROP_ERR_PKT_G, 0, 1);

   type RegType is record
      rxFifoDrop : sl;
   end record RegType;
   constant REG_INIT_C : RegType := (
      rxFifoDrop => '0');
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal primDrop  : sl                          := '0';
   signal bypDrop   : sl                          := '0';
   signal vlanDrops : slv(VLAN_SIZE_G-1 downto 0) := (others => '0');

--   attribute dont_touch      : string;
--   attribute dont_touch of r : signal is "TRUE";   
   
   
begin

   U_Fifo : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         EN_FRAME_FILTER_G   => true,
         OR_DROP_FLAGS_G     => true,
         VALID_THOLD_G       => VALID_THOLD_C,
         -- FIFO configurations
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PRIM_CONFIG_G)        
      port map (
         sAxisClk       => sClk,
         sAxisRst       => sRst,
         sAxisMaster    => sPrimMaster,
         sAxisCtrl      => sPrimCtrl,
         sAxisTermFrame => primDrop,
         mAxisClk       => mPrimClk,
         mAxisRst       => mPrimRst,
         mAxisMaster    => mPrimMaster,
         mAxisSlave     => mPrimSlave);    

   BYP_DISABLED : if (BYP_EN_G = false) generate
      sBypCtrl   <= AXI_STREAM_CTRL_UNUSED_C;
      mBypMaster <= AXI_STREAM_MASTER_INIT_C;
   end generate;

   BYP_ENABLED : if (BYP_EN_G = true) generate
      U_Fifo : entity work.SsiFifo
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_READY_EN_G    => false,
            EN_FRAME_FILTER_G   => true,
            OR_DROP_FLAGS_G     => true,
            VALID_THOLD_G       => VALID_THOLD_C,
            -- FIFO configurations
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
            CASCADE_SIZE_G      => CASCADE_SIZE_G,
            CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
            FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
            FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => BYP_CONFIG_G)        
         port map (
            sAxisClk       => sClk,
            sAxisRst       => sRst,
            sAxisMaster    => sBypMaster,
            sAxisCtrl      => sBypCtrl,
            sAxisTermFrame => bypDrop,
            mAxisClk       => mBypClk,
            mAxisRst       => mBypRst,
            mAxisMaster    => mBypMaster,
            mAxisSlave     => mBypSlave);    
   end generate;

   VLAN_DISABLED : if (VLAN_EN_G = false) generate
      sVlanCtrl    <= (others => AXI_STREAM_CTRL_UNUSED_C);
      mVlanMasters <= (others => AXI_STREAM_MASTER_INIT_C);
   end generate;

   VLAN_ENABLED : if (VLAN_EN_G = true) generate
      GEN_VEC : for i in (VLAN_SIZE_G-1) downto 0 generate
         U_Fifo : entity work.SsiFifo
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
               PIPE_STAGES_G       => PIPE_STAGES_G,
               SLAVE_READY_EN_G    => false,
               EN_FRAME_FILTER_G   => true,
               OR_DROP_FLAGS_G     => true,
               VALID_THOLD_G       => VALID_THOLD_C,
               -- FIFO configurations
               BRAM_EN_G           => true,
               GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
               CASCADE_SIZE_G      => CASCADE_SIZE_G,
               CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
               FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
               FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
               MASTER_AXI_CONFIG_G => VLAN_CONFIG_G)
            port map (
               sAxisClk       => sClk,
               sAxisRst       => sRst,
               sAxisMaster    => sVlanMasters(i),
               sAxisCtrl      => sVlanCtrl(i),
               sAxisTermFrame => vlanDrops(i),
               mAxisClk       => mVlanClk,
               mAxisRst       => mVlanRst,
               mAxisMaster    => mVlanMasters(i),
               mAxisSlave     => mVlanSlaves(i));    
      end generate GEN_VEC;
   end generate;

   comb : process (bypDrop, phyReady, primDrop, r, sRst, vlanDrops) is
      variable v    : RegType;
      variable drop : sl;
   begin
      -- Latch the current value
      v := r;

      -- OR-ing drop flags together
      v.rxFifoDrop := primDrop or bypDrop or uOr(vlanDrops);

      -- Reset
      if (sRst = '1') or (phyReady = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      rxFifoDrop <= r.rxFifoDrop;
      
   end process comb;

   seq : process (sClk) is
   begin
      if rising_edge(sClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
