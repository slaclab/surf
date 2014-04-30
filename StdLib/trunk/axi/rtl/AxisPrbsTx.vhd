-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxisPrbsTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-04-29
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module generates 
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxisPrbsTx is
   generic (
      -- General Configurations
      TPD_G               : time                       := 1 ns;
      -- FIFO configurations
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";
      USE_BUILT_IN_G      : boolean                    := false;
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : natural range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : natural range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G : natural range 1 to (2**24) := 2**8;
      -- AXI Stream IO Config
      AXI_STREAM_CONFIG_G : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C);      
   port (
      -- Master Port (mAxisClk)
      mAxisSlave   : in  AxiStreamSlaveType;
      mAxisMaster  : out AxiStreamMasterType;
      mAxisClk     : in  sl;
      mAxisRst     : in  sl;
      -- Trigger Signal (locClk domain)
      trig         : in  sl;
      packetLength : in  slv(31 downto 0);
      busy         : out sl;
      tDest        : in  slv(7 downto 0);
      tId          : in  slv(7 downto 0);
      sAxisCtrl    : out AxiStreamCtrlType;
      locClk       : in  sl;
      locRst       : in  sl := '0');
end AxisPrbsTx;

architecture rtl of AxisPrbsTx is

   constant TAP_C : NaturalArray(0 to 0) := (others => 16);
   
   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      LENGTH_S,
      DATA_S);  

   type RegType is record
      busy         : sl;
      packetLength : slv(31 downto 0);
      eventCnt     : slv(31 downto 0);
      randomData   : slv(31 downto 0);
      dataCnt      : slv(31 downto 0);
      txAxisMaster : AxiStreamMasterType;
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   
begin

   comb : process (locRst, packetLength, r, tDest, tId, trig, txAxisSlave) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Set the AXIS configurations
      v.txAxisMaster.tKeep := (others => '0');
      v.txAxisMaster.tStrb := (others => '0');
      for i in 0 to AXI_STREAM_CONFIG_G.TDATA_BYTES_C-1 loop
         v.txAxisMaster.tKeep(i) := '1';
         v.txAxisMaster.tStrb(i) := '1';
      end loop;

      -- Reset strobe signals
      v.txAxisMaster.tValid := '0';
      v.txAxisMaster.tLast  := '0';
      v.txAxisMaster.tUser  := (others => '0');

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if trig = '1' then
               -- Latch the generator seed
               v.randomData         := r.eventCnt;
               -- Set the busy flag
               v.busy               := '1';
               -- Latch the configuration
               v.txAxisMaster.tDest := tDest;
               v.txAxisMaster.tId   := tId;
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
            -- Check the status
            if txAxisSlave.tReady = '1' then
               -- Send the random seed word
               v.txAxisMaster.tvalid := '1';
               for i in 0 to 3 loop
                  v.txAxisMaster.tData(i*32+31 downto i*32) := r.eventCnt;
               end loop;
               -- Generate the next random data word
               v.randomData := lfsrShift(r.randomData, TAP_C);
               -- Increment the counter
               v.eventCnt   := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Next State
               v.state      := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check the status
            if txAxisSlave.tReady = '1' then
               -- Send the upper packetLength value
               v.txAxisMaster.tvalid := '1';
               for i in 0 to 3 loop
                  v.txAxisMaster.tData(i*32+31 downto i*32) := r.packetLength;
               end loop;
               -- Increment the counter
               v.dataCnt := r.dataCnt + 1;
               -- Next State
               v.state   := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check the status
            if txAxisSlave.tReady = '1' then
               -- Send the random data word
               v.txAxisMaster.tValid := '1';
               for i in 0 to 3 loop
                  v.txAxisMaster.tData(i*32+31 downto i*32) := r.randomData;
               end loop;
               -- Generate the next random data word
               v.randomData := lfsrShift(r.randomData, TAP_C);
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.packetLength then
                  -- Reset the counter
                  v.dataCnt            := (others => '0');
                  -- Set the end of frame flag                 
                  v.txAxisMaster.tLast := '1';
                  -- Reset the busy flag
                  v.busy               := '0';
                  -- Next State
                  v.state              := IDLE_S;
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
      txAxisMaster <= r.txAxisMaster;
      busy         <= r.busy;
      
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
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk      => locClk,
         sAxisRst      => locRst,
         sAxisMaster => txAxisMaster,
         sAxisSlave  => txAxisSlave,
         sAxisCtrl    => sAxisCtrl,
         -- Master Port
         mAxisClk      => mAxisClk,
         mAxisRst      => mAxisRst,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);  

end rtl;
