-------------------------------------------------------------------------------
-- File       : AxiStreamSimWrap.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-10
-- Last update: 2014-05-10
-------------------------------------------------------------------------------
-- Description: Wrapper for AXI Stream Simulation Module
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamSimWrap is 
   generic (
      -- General Configurations
      TPD_G               : time                   := 1 ns;
      SLAVE_CLK_PERIOD_G  : time := 10 ns;
      MASTER_CLK_PERIOD_G : time := 10 ns;
      RST_HOLD_TIME_G     : time := 500 ns;
      -- FIFO Configurations
      PIPE_STAGES_G       : natural range 0 to 16      := 0;
      VALID_THOLD_G       : integer range 1 to (2**24) := 1;
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
      -- AXIS Configurations
      AXIS_CONFIG_G       : AxiStreamConfigTYpe    := AXI_STREAM_CONFIG_INIT_C;
      EOFE_TUSER_EN_G     : boolean                := false;
      EOFE_TUSER_BIT_G    : integer range 0 to 127 := 0;
      SOF_TUSER_EN_G      : boolean                := false;
      SOF_TUSER_BIT_G     : integer range 0 to 127 := 0);
   port ( 
      -- Slave, non-interleaved, tkeep not supported
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master, non-interleaved, tkeep not supported
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamSimWrap;

architecture AxiStreamSimWrap of AxiStreamSimWrap is

   constant AXIS_CONFIG_C : AxiStreamConfigTYpe := (
      TSTRB_EN_C    => AXIS_CONFIG_G.TSTRB_EN_C,
      TDATA_BYTES_C => 4,-- 32 bit interface to software
      TDEST_BITS_C  => AXIS_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => AXIS_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => AXIS_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => AXIS_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => AXIS_CONFIG_G.TUSER_MODE_C);
      
   constant CLK_RATIO_C         : natural := (AXIS_CONFIG_G.TDATA_BYTES_C/AXIS_CONFIG_C.TDATA_BYTES_C);
   constant SLAVE_CLK_PERIOD_C  : time := ite((CLK_RATIO_C>1),(SLAVE_CLK_PERIOD_G/CLK_RATIO_C),SLAVE_CLK_PERIOD_G);
   constant MASTER_CLK_PERIOD_C : time := ite((CLK_RATIO_C>1),(MASTER_CLK_PERIOD_G/CLK_RATIO_C),MASTER_CLK_PERIOD_G);

   signal masterClk,
      masterRst,
      slaveClk,
      slaveRst : sl;
      
   signal masterAxisMaster,
      slaveAxisMaster : AxiStreamMasterType;
   
   signal masterAxisSlave,
      slaveAxisSlave : AxiStreamSlaveType;      

begin

   Slave_Fifo : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
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
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)      
      port map (
         -- Slave Port
         sAxisClk        => sAxisClk,
         sAxisRst        => sAxisRst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         -- Master Port
         mAxisClk        => masterClk,
         mAxisRst        => masterRst,
         mAxisMaster     => masterAxisMaster,
         mAxisSlave      => masterAxisSlave); 
         
   Master_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => MASTER_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => RST_HOLD_TIME_G)  -- Hold reset for this long)
      port map (
         clkP => masterClk,
         clkN => open,
         rst  => masterRst,
         rstL => open);          

   AxiStreamSim_Inst : entity work.AxiStreamSim
      generic map (
         TPD_G            => TPD_G,
         AXIS_CONFIG_G    => AXIS_CONFIG_C,
         EOFE_TUSER_EN_G  => EOFE_TUSER_EN_G,
         EOFE_TUSER_BIT_G => EOFE_TUSER_BIT_G,
         SOF_TUSER_EN_G   => SOF_TUSER_EN_G,
         SOF_TUSER_BIT_G  => SOF_TUSER_BIT_G) 
      port map (
         -- Slave, non-interleaved, 32-bit or 16-bit interface, tkeep not supported
         sAxisClk    => masterClk,
         sAxisRst    => masterRst,
         sAxisMaster => masterAxisMaster,
         sAxisSlave  => masterAxisSlave,
         -- Master, non-interleaved, 32-bit or 16-bit interface, tkeep not supported
         mAxisClk    => slaveClk,
         mAxisRst    => slaveRst,
         mAxisMaster => slaveAxisMaster,
         mAxisSlave  => slaveAxisSlave); 
         
   Slave_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => SLAVE_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => RST_HOLD_TIME_G)  -- Hold reset for this long)
      port map (
         clkP => slaveClk,
         clkN => open,
         rst  => slaveRst,
         rstL => open);         
         
   Master_Fifo : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
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
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)      
      port map (
         -- Slave Port
         sAxisClk        => slaveClk,
         sAxisRst        => slaveRst,
         sAxisMaster     => slaveAxisMaster,
         sAxisSlave      => slaveAxisSlave,
         -- Master Port
         mAxisClk        => mAxisClk,
         mAxisRst        => mAxisRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave);          

end AxiStreamSimWrap;
