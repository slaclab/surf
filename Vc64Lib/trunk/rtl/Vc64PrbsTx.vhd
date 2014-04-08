-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64PrbsTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-04-07
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
use work.Vc64Pkg.all;

entity Vc64PrbsTx is
   generic (
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      BRAM_EN_G          : boolean                    := true;
      USE_BUILT_IN_G     : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      GEN_SYNC_FIFO_G    : boolean                    := false;
      BYPASS_FIFO_G      : boolean                    := false;  -- If GEN_SYNC_FIFO_G = true, BYPASS_FIFO_G = true will reduce FPGA resources
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 256);
   port (
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl     : in  Vc64CtrlType;
      vcTxData     : out Vc64DataType;
      vcTxClk      : in  sl;
      vcTxRst      : in  sl := '0';
      -- Trigger Signal (locClk domain)
      trig         : in  sl;
      packetLength : in  slv(31 downto 0);
      busy         : out sl;
      locClk       : in  sl;
      locRst       : in  sl := '0');
end Vc64PrbsTx;

architecture rtl of Vc64PrbsTx is

   constant TAP_C : NaturalArray(0 to 0) := (others => 16);
   
   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      UPPER_S,
      LOWER_S,
      DATA_S);  

   type RegType is record
      busy         : sl;
      packetLength : slv(31 downto 0);
      eventCnt     : slv(15 downto 0);
      randomData   : slv(31 downto 0);
      dataCnt      : slv(31 downto 0);
      vcRxData     : Vc64DataType;
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      VC64_DATA_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal vcRxData : Vc64DataType := VC64_DATA_INIT_C;
   signal vcRxCtrl : Vc64CtrlType := VC64_CTRL_INIT_C;
   
begin

   comb : process (locRst, packetLength, r, trig, vcRxCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.vcRxData.valid := '0';
      v.vcRxData.sof   := '0';
      v.vcRxData.eof   := '0';
      v.vcRxData.eofe  := '0';

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if trig = '1' then
               -- Latch the generator seed
               v.randomData := x"0000" & r.eventCnt;
               -- Set the busy flag
               v.busy       := '1';
               -- Check the packet length request value
               if packetLength = 0 then
                  -- Force minimum packet length of 3 (+1)
                  v.packetLength := toSlv(3, 32);
               elsif packetLength = 1 then
                  -- Force minimum packet length of 3 (+1)
                  v.packetLength := toSlv(3, 32);
               elsif packetLength = 2 then
                  -- Force minimum packet length of 3 (+1)
                  v.packetLength := toSlv(3, 32);
               else
                  -- Latch the packet length
                  v.packetLength := packetLength;
               end if;
               -- Next State
               v.state := SEED_RAND_S;
            end if;
         ----------------------------------------------------------------------
         when SEED_RAND_S =>
            -- Check the FIFO status
            if vcRxCtrl.almostFull = '0' then
               -- Send the random seed word
               v.vcRxData.valid             := '1';
               v.vcRxData.sof               := '1';
               v.vcRxData.data(15 downto 0) := r.eventCnt;
               -- Generate the next random data word
               v.randomData                 := lfsrShift(r.randomData, TAP_C);
               -- Increment the counter
               v.eventCnt                   := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt                    := r.dataCnt + 1;
               -- Next State
               v.state                      := UPPER_S;
            end if;
         ----------------------------------------------------------------------
         when UPPER_S =>
            -- Check the FIFO status
            if vcRxCtrl.almostFull = '0' then
               -- Send the upper packetLength value
               v.vcRxData.valid             := '1';
               v.vcRxData.data(15 downto 0) := r.packetLength(31 downto 16);
               -- Increment the counter
               v.dataCnt                    := r.dataCnt + 1;
               -- Next State
               v.state                      := LOWER_S;
            end if;
         ----------------------------------------------------------------------
         when LOWER_S =>
            -- Check the FIFO status
            if vcRxCtrl.almostFull = '0' then
               -- Send the lower packetLength value
               v.vcRxData.valid             := '1';
               v.vcRxData.data(15 downto 0) := r.packetLength(15 downto 0);
               -- Increment the counter
               v.dataCnt                    := r.dataCnt + 1;
               -- Next State
               v.state                      := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check the FIFO status
            if vcRxCtrl.almostFull = '0' then
               -- Send the random data word
               v.vcRxData.valid             := '1';
               v.vcRxData.data(15 downto 0) := r.randomData(15 downto 0);
               -- Generate the next random data word
               v.randomData                 := lfsrShift(r.randomData, TAP_C);
               -- Increment the counter
               v.dataCnt                    := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.packetLength then
                  -- Reset the counter
                  v.dataCnt      := (others => '0');
                  -- Set the end of frame flag
                  v.vcRxData.eof := '1';
                  -- Reset the busy flag
                  v.busy         := '0';
                  -- Next State
                  v.state        := IDLE_S;
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
      vcRxData <= r.vcRxData;
      busy     <= r.busy;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   Vc64Fifo_Inst : entity work.Vc64Fifo
      generic map (
         TPD_G              => TPD_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         BRAM_EN_G          => BRAM_EN_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BYPASS_FIFO_G      => BYPASS_FIFO_G,
         PIPE_STAGES_G      => PIPE_STAGES_G,
         FIFO_SYNC_STAGES_G => FIFO_SYNC_STAGES_G,
         FIFO_ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G,
         FIFO_AFULL_THRES_G => FIFO_AFULL_THRES_G)      
      port map (
         -- Streaming RX Data Interface (vcRxClk domain) 
         vcRxData => vcRxData,
         vcRxCtrl => vcRxCtrl,
         vcRxClk  => locClk,
         vcRxRst  => locRst,
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxCtrl => vcTxCtrl,
         vcTxData => vcTxData,
         vcTxClk  => vcTxClk,
         vcTxRst  => vcTxRst);      
end rtl;
