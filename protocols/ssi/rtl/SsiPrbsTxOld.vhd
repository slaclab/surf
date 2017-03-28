-------------------------------------------------------------------------------
-- File       : SsiPrbsTxOld.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-11-07
-------------------------------------------------------------------------------
-- Description:   This module generates 
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
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
use work.SsiPkg.all;

entity SsiPrbsTxOld is
   generic (
      -- General Configurations
      TPD_G                      : time                       := 1 ns;
      -- FIFO Configurations
      BRAM_EN_G                  : boolean                    := true;
      XIL_DEVICE_G               : string                     := "7SERIES";
      USE_BUILT_IN_G             : boolean                    := false;
      GEN_SYNC_FIFO_G            : boolean                    := false;
      ALTERA_SYN_G               : boolean                    := false;
      ALTERA_RAM_G               : string                     := "M9K";
      CASCADE_SIZE_G             : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G          : natural range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G        : natural range 1 to (2**24) := 2**8;
      -- PRBS Configurations
      PRBS_SEED_SIZE_G           : natural range 32 to 128    := 32;
      PRBS_TAPS_G                : NaturalArray               := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      -- AXI Stream Configurations
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType        := ssiAxiStreamConfig(16, TKEEP_COMP_C);
      MASTER_AXI_PIPE_STAGES_G   : natural range 0 to 16      := 0);      
   port (
      -- Master Port (mAxisClk)
      mAxisClk     : in  sl;
      mAxisRst     : in  sl;
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- Trigger Signal (locClk domain)
      locClk       : in  sl;
      locRst       : in  sl               := '0';
      trig         : in  sl               := '1';
      packetLength : in  slv(31 downto 0) := X"FFFFFFFF";
      forceEofe    : in  sl               := '0';
      busy         : out sl;
      tDest        : in  slv(7 downto 0)  := X"00";
      tId          : in  slv(7 downto 0)  := X"00");
end SsiPrbsTxOld;

architecture rtl of SsiPrbsTxOld is

   constant PRBS_BYTES_C      : natural             := (PRBS_SEED_SIZE_G/8);
   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(PRBS_BYTES_C, TKEEP_COMP_C);
   
   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      LENGTH_S,
      DATA_S);  

   type RegType is record
      busy         : sl;
      overflow     : sl;
      packetLength : slv(31 downto 0);
      dataCnt      : slv(31 downto 0);
      eventCnt     : slv(PRBS_SEED_SIZE_G-1 downto 0);
      randomData   : slv(PRBS_SEED_SIZE_G-1 downto 0);
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txCtrl : AxiStreamCtrlType;
   
begin

   assert (PRBS_SEED_SIZE_G mod 8 = 0) report "PRBS_SEED_SIZE_G must be a multiple of 8" severity failure;

   comb : process (forceEofe, locRst, packetLength, r, tDest, tId, trig, txCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txMaster);
      v.txMaster.tData := (others => '0');

      -- Check for overflow condition or forced EOFE
      if (txCtrl.overflow = '1') or (forceEofe = '1') then
         -- Latch the overflow error bit for the data packet
         v.overflow := '1';
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if trig = '1' then
               -- Latch the generator seed
               v.randomData     := r.eventCnt;
               -- Set the busy flag
               v.busy           := '1';
               -- Reset the overflow flag
               v.overflow       := '0';
               -- Latch the configuration
               v.txMaster.tDest := tDest;
               v.txMaster.tId   := tId;
               -- Check the packet length request value
               if packetLength = 0 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               elsif packetLength = 1 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               else
                  -- Latch the packet length
                  v.packetLength := packetLength;
               end if;
               -- Next State
               v.state := SEED_RAND_S;
            end if;
         ----------------------------------------------------------------------
         when SEED_RAND_S =>
            -- Check if the FIFO is ready
            if txCtrl.pause = '0' then
               -- Send the random seed word
               v.txMaster.tvalid                             := '1';
               v.txMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.eventCnt;
               -- Generate the next random data word
               v.randomData                                  := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Increment the counter
               v.eventCnt                                    := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt                                     := r.dataCnt + 1;
               -- Set the SOF bit
               ssiSetUserSof(PRBS_SSI_CONFIG_C, v.txMaster, '1');
               -- Next State
               v.state                                       := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check if the FIFO is ready
            if txCtrl.pause = '0' then
               -- Send the upper packetLength value
               v.txMaster.tvalid             := '1';
               v.txMaster.tData(31 downto 0) := r.packetLength;
               -- Increment the counter
               v.dataCnt                     := r.dataCnt + 1;
               -- Next State
               v.state                       := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if the FIFO is ready
            if txCtrl.pause = '0' then
               -- Send the random data word
               v.txMaster.tValid                             := '1';
               v.txMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.randomData;
               -- Generate the next random data word
               v.randomData                                  := lfsrShift(r.randomData, PRBS_TAPS_G);
               -- Increment the counter
               v.dataCnt                                     := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.packetLength then
                  -- Reset the counter
                  v.dataCnt        := (others => '0');
                  -- Set the EOF bit                
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txMaster, r.overflow);
                  -- Reset the busy flag
                  v.busy           := '0';
                  -- Next State
                  v.state          := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (locRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      busy <= r.busy;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_Inst : entity work.AxiStreamFifo
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => MASTER_AXI_PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => open,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);  

end rtl;
