-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SsiFifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2015-09-15
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
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
      TPD_G               : time                       := 1 ns;
      PIPE_STAGES_G       : natural range 0 to 16      := 0;
      EN_FRAME_FILTER_G   : boolean                    := true;
      VALID_THOLD_G       : integer range 0 to (2**24) := 1;
      -- FIFO configurations
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";
      USE_BUILT_IN_G      : boolean                    := false;
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      FIFO_FIXED_THRESH_G : boolean                    := true;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 500;
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);  
   port (
      -- Slave Port
      sAxisClk        : in  sl;
      sAxisRst        : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      sAxisDropWrite  : out sl;
      sAxisTermFrame  : out sl;
      -- FIFO status & config , synchronous to sAxisClk
      fifoPauseThresh : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');
      -- Master Port
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      mTLastTUser     : out slv(127 downto 0));  -- when VALID_THOLD_G /= 1, used to look ahead at tLast's tUser
end SsiFifo;

architecture mapping of SsiFifo is
   
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;
   
begin

   U_Filter : entity work.SsiFrameFilter
      generic map (
         -- General Configurations
         TPD_G             => TPD_G,
         EN_FRAME_FILTER_G => EN_FRAME_FILTER_G,
         -- AXI Stream Port Configurations
         AXIS_CONFIG_G     => SLAVE_AXI_CONFIG_G)          
      port map (
         -- Slave Port
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         sAxisDropWrite => sAxisDropWrite,
         sAxisTermFrame => sAxisTermFrame,
         -- Master Port
         mAxisMaster    => axisMaster,
         mAxisSlave     => axisSlave,
         -- Clock and Reset
         axisClk        => sAxisClk,
         axisRst        => sAxisRst);   

   U_Fifo : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
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
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)      
      port map (
         -- Slave Port
         sAxisClk        => sAxisClk,
         sAxisRst        => sAxisRst,
         sAxisMaster     => axisMaster,
         sAxisSlave      => axisSlave,
         sAxisCtrl       => sAxisCtrl,
         -- FIFO status & config , synchronous to sAxisClk
         fifoPauseThresh => fifoPauseThresh,
         -- Master Port
         mAxisClk        => mAxisClk,
         mAxisRst        => mAxisRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave,
         mTLastTUser     => mTLastTUser);      

end mapping;
