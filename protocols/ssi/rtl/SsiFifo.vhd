-------------------------------------------------------------------------------
-- File       : SsiFifo.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-10-17
-------------------------------------------------------------------------------
-- Description:   This module is the AXIS FIFO with a frame filter
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of channels during the middle of a frame transfer.
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
use work.SsiPkg.all;

entity SsiFifo is
   generic (
      -- General Configurations
      TPD_G               : time                  := 1 ns;
      INT_PIPE_STAGES_G   : natural               := 0;
      PIPE_STAGES_G       : natural               := 1;
      SLAVE_READY_EN_G    : boolean               := true;
      EN_FRAME_FILTER_G   : boolean               := true;
      OR_DROP_FLAGS_G     : boolean               := false;
      VALID_THOLD_G       : natural               := 1;
      -- FIFO configurations
      BRAM_EN_G           : boolean               := true;
      XIL_DEVICE_G        : string                := "7SERIES";
      USE_BUILT_IN_G      : boolean               := false;
      GEN_SYNC_FIFO_G     : boolean               := false;
      ALTERA_SYN_G        : boolean               := false;
      ALTERA_RAM_G        : string                := "M9K";
      CASCADE_SIZE_G      : positive              := 1;
      CASCADE_PAUSE_SEL_G : natural               := 0;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48 := 9;
      FIFO_FIXED_THRESH_G : boolean               := true;
      FIFO_PAUSE_THRESH_G : positive              := 1;
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType   := SSI_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType   := SSI_CONFIG_INIT_C);  
   port (
      -- Slave Port
      sAxisClk        : in  sl;
      sAxisRst        : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      sAxisDropWrite  : out sl;
      sAxisTermFrame  : out sl;
      fifoPauseThresh : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');
      -- Master Port
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      mAxisDropWrite  : out sl;
      mAxisTermFrame  : out sl);
end SsiFifo;

architecture mapping of SsiFifo is
   
   signal rxMaster   : AxiStreamMasterType;
   signal rxSlave    : AxiStreamSlaveType;
   signal rxCtrl     : AxiStreamCtrlType;
   signal sAxisReset : sl;

   signal txMaster     : AxiStreamMasterType;
   signal txSlave      : AxiStreamSlaveType;
   signal txTLastTUser : slv(7 downto 0);
   signal overflow     : sl;

   signal sDropWrite     : sl;
   signal sDropWriteSync : sl;
   signal sTermFrame     : sl;
   signal sTermFrameSync : sl;

   signal mDropWrite     : sl;
   signal mDropWriteSync : sl;
   signal mTermFrame     : sl;
   signal mTermFrameSync : sl;
   
begin

   assert (SLAVE_AXI_CONFIG_G.TUSER_BITS_C >= 2) report "SsiFifo:  SLAVE_AXI_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;
   assert (MASTER_AXI_CONFIG_G.TUSER_BITS_C >= 2) report "SsiFifo:  MASTER_AXI_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   U_IbFilter : entity work.SsiIbFrameFilter
      generic map (
         TPD_G             => TPD_G,
         SLAVE_READY_EN_G  => SLAVE_READY_EN_G,
         EN_FRAME_FILTER_G => EN_FRAME_FILTER_G,
         AXIS_CONFIG_G     => SLAVE_AXI_CONFIG_G)          
      port map (
         -- Slave Port
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         sAxisCtrl      => sAxisCtrl,
         sAxisDropWrite => sDropWrite,
         sAxisTermFrame => sTermFrame,
         -- Master Port
         mAxisMaster    => rxMaster,
         mAxisSlave     => rxSlave,
         mAxisCtrl      => rxCtrl,
         -- Clock and Reset
         axisClk        => sAxisClk,
         axisRst        => sAxisReset);  

   U_Fifo : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => VALID_THOLD_G,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => FIFO_FIXED_THRESH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => CASCADE_PAUSE_SEL_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)      
      port map (
         -- Slave Port
         sAxisClk        => sAxisClk,
         sAxisRst        => sAxisReset,
         sAxisMaster     => rxMaster,
         sAxisSlave      => rxSlave,
         sAxisCtrl       => rxCtrl,
         -- FIFO status & config , synchronous to sAxisClk
         fifoPauseThresh => fifoPauseThresh,
         -- Master Port
         mAxisClk        => mAxisClk,
         mAxisRst        => mAxisRst,
         mAxisMaster     => txMaster,
         mAxisSlave      => txSlave,
         mTLastTUser     => txTLastTUser);      

   sAxisReset <= (sAxisRst or (rxCtrl.overflow and not(rxCtrl.idle))) when(EN_FRAME_FILTER_G) else sAxisRst;

   GEN_SYNC_SLAVE : if (GEN_SYNC_FIFO_G = true) generate
      overflow <= rxCtrl.overflow;
   end generate;

   GEN_ASYNC_SLAVE : if (GEN_SYNC_FIFO_G = false) generate
      Sync_Overflow : entity work.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => mAxisClk,
            rst     => mAxisRst,
            dataIn  => rxCtrl.overflow,
            dataOut => overflow);             
   end generate;

   U_ObFilter : entity work.SsiObFrameFilter
      generic map (
         TPD_G             => TPD_G,
         VALID_THOLD_G     => VALID_THOLD_G,
         EN_FRAME_FILTER_G => EN_FRAME_FILTER_G,
         AXIS_CONFIG_G     => MASTER_AXI_CONFIG_G)          
      port map (
         -- Slave Port
         sAxisMaster    => txMaster,
         sAxisSlave     => txSlave,
         sTLastTUser    => txTLastTUser,
         overflow       => overflow,
         -- Master Port
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => mAxisSlave,
         mAxisDropWrite => mDropWrite,
         mAxisTermFrame => mTermFrame,
         -- Clock and Reset
         axisClk        => mAxisClk,
         axisRst        => mAxisRst);          

   
   ORING_DROP : if (OR_DROP_FLAGS_G = true) generate
      
      GEN_SYNC : if (GEN_SYNC_FIFO_G = true) generate
         sAxisDropWrite <= sDropWrite or mDropWrite;
         sAxisTermFrame <= sTermFrame or mTermFrame;
         mAxisDropWrite <= sDropWrite or mDropWrite;
         mAxisTermFrame <= sTermFrame or mTermFrame;
      end generate;

      GEN_ASYNC : if (GEN_SYNC_FIFO_G = false) generate
         
         sAxisDropWrite <= sDropWrite or mDropWriteSync;
         sAxisTermFrame <= sTermFrame or mTermFrameSync;
         mAxisDropWrite <= sDropWriteSync or mDropWrite;
         mAxisTermFrame <= sTermFrameSync or mTermFrame;

         Sync_0 : entity work.SynchronizerOneShot
            generic map (
               TPD_G => TPD_G)
            port map (
               clk     => sAxisClk,
               dataIn  => mDropWrite,
               dataOut => mDropWriteSync);  

         Sync_1 : entity work.SynchronizerOneShot
            generic map (
               TPD_G => TPD_G)
            port map (
               clk     => sAxisClk,
               dataIn  => mTermFrame,
               dataOut => mTermFrameSync);   

         Sync_2 : entity work.SynchronizerOneShot
            generic map (
               TPD_G => TPD_G)
            port map (
               clk     => mAxisClk,
               dataIn  => sDropWrite,
               dataOut => sDropWriteSync);  

         Sync_3 : entity work.SynchronizerOneShot
            generic map (
               TPD_G => TPD_G)
            port map (
               clk     => mAxisClk,
               dataIn  => sTermFrame,
               dataOut => sTermFrameSync);                  

      end generate;
   end generate;

   NO_ORING_DROP : if (OR_DROP_FLAGS_G = false) generate
      sAxisDropWrite <= sDropWrite;
      sAxisTermFrame <= sTermFrame;
      mAxisDropWrite <= mDropWrite;
      mAxisTermFrame <= mTermFrame;
   end generate;

end mapping;
