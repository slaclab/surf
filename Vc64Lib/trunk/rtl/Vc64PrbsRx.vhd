-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64PrbsRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-04-09
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

entity Vc64PrbsRx is
   generic (
      TPD_G              : time                       := 1 ns;
      SiZE_16BITS_G      : integer range 0 to 3       := 3;
      LANE_NUMBER_G      : integer range 0 to 255     := 0;
      VC_NUMBER_G        : integer range 0 to 3       := 0;
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
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData        : in  Vc64DataType;
      vcRxCtrl        : out Vc64CtrlType;
      vcRxClk         : in  sl;
      vcRxRst         : in  sl           := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl        : in  Vc64CtrlType := VC64_CTRL_FORCE_C;
      vcTxData        : out Vc64DataType;
      vcTxClk         : in  sl;
      vcTxRst         : in  sl;
      -- Error Detection Signals (vcRxClk domain)
      updatedResults  : out sl;
      busy            : out sl;
      errMissedPacket : out sl;
      errLength       : out sl;
      errDataBus      : out sl;
      errEofe         : out sl;
      errWordCnt      : out slv(31 downto 0);
      errbitCnt       : out slv(31 downto 0);
      packetRate      : out slv(31 downto 0);
      packetLength    : out slv(31 downto 0));
end Vc64PrbsRx;

architecture rtl of Vc64PrbsRx is

   constant TAP_C         : NaturalArray(0 to 0) := (others => 16);
   constant MAX_ERR_CNT_C : slv(31 downto 0)     := (others => '1');

   type StateType is (
      IDLE_S,
      UPPER_S,
      LOWER_S,
      DATA_S,
      BIT_ERR_S,
      SEND_RESULT_S);   
   type RegType is record
      busy            : sl;
      packetLength    : slv(31 downto 0);
      eof             : sl;
      eofe            : sl;
      errLength       : sl;
      updatedResults  : sl;
      errMissedPacket : sl;
      errDataBus      : sl;
      errorBits       : slv(15 downto 0);
      bitPntr         : slv(3 downto 0);
      errWordCnt      : slv(31 downto 0);
      errbitCnt       : slv(31 downto 0);
      eventCnt        : slv(15 downto 0);
      randomData      : slv(31 downto 0);
      dataCnt         : slv(31 downto 0);
      stopTime        : slv(31 downto 0);
      startTime       : slv(31 downto 0);
      packetRate      : slv(31 downto 0);
      txCtrl          : Vc64CtrlType;
      rxData          : Vc64DataType;
      state           : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      '1',
      toSlv(3, 32),
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '1'),
      (others => '1'),
      VC64_CTRL_INIT_C,
      VC64_DATA_INIT_C,
      IDLE_S);
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxData : Vc64DataType := VC64_DATA_INIT_C;
   signal rxCtrl : Vc64CtrlType := VC64_CTRL_INIT_C;

   signal txData : Vc64DataType := VC64_DATA_INIT_C;
   signal txCtrl : Vc64CtrlType := VC64_CTRL_INIT_C;
   
begin

   Vc64Fifo_Rx : entity work.Vc64Fifo
      generic map (
         TPD_G              => TPD_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         BRAM_EN_G          => BRAM_EN_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G    => true,
         PIPE_STAGES_G      => PIPE_STAGES_G,
         FIFO_SYNC_STAGES_G => FIFO_SYNC_STAGES_G,
         FIFO_ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G,
         FIFO_AFULL_THRES_G => FIFO_AFULL_THRES_G)      
      port map (
         -- Streaming RX Data Interface (vcRxClk domain) 
         vcRxData => vcRxData,
         vcRxCtrl => vcRxCtrl,
         vcRxClk  => vcRxClk,
         vcRxRst  => vcRxRst,
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxCtrl => txCtrl,
         vcTxData => txData,
         vcTxClk  => vcRxClk,
         vcTxRst  => vcRxRst);    

   comb : process (r, rxCtrl, txData, vcRxRst) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.rxData.valid   := '0';
      v.rxData.sof     := '0';
      v.rxData.eof     := '0';
      v.rxData.eofe    := '0';
      v.updatedResults := '0';

      -- Check for roll over
      if r.stopTime /= r.startTime then
         -- Increment the rate counter
         v.stopTime := r.stopTime + 1;
      end if;

      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy              := '0';
            -- Ready to receive data
            v.txCtrl.ready      := '1';
            v.txCtrl.almostFull := '0';
            -- Check for a FIFO read
            if (txData.valid = '1') and (r.txCtrl.ready = '1') then
               -- Check for a start of frame
               if txData.sof = '1' then
                  -- Calculate the time between this packet and the previous one
                  v.packetRate      := r.stopTime - r.startTime;
                  v.startTime       := r.stopTime;
                  -- Reset the error counters
                  v.errWordCnt      := (others => '0');
                  v.errbitCnt       := (others => '0');
                  v.errMissedPacket := '0';
                  v.errLength       := '0';
                  v.errDataBus      := '0';
                  v.eof             := '0';
                  v.eofe            := '0';
                  -- Check if we have missed a packet 
                  if txData.data(15 downto 0) /= r.eventCnt then
                     -- Set the error flag
                     v.errMissedPacket := '1';
                  end if;
                  -- Align the event counter to the next packet
                  v.eventCnt   := txData.data(15 downto 0) + 1;
                  -- Latch the SEED for the randomization
                  v.randomData := (x"0000" & txData.data(15 downto 0));
                  -- Check for a data bus error
                  for i in 0 to SiZE_16BITS_G loop
                     if txData.data(15 downto 0) /= txData.data(i*16+15 downto i*16) then
                        v.errDataBus := '1';
                     end if;
                  end loop;
                  -- Set the busy flag
                  v.busy    := '1';
                  -- Increment the counter
                  v.dataCnt := r.dataCnt + 1;
                  -- Next State
                  v.state   := UPPER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when UPPER_S =>
            -- Check for a FIFO read
            if (txData.valid = '1') and (r.txCtrl.ready = '1') then
               -- Latch the upper packetLength value
               v.packetLength(31 downto 16) := txData.data(15 downto 0);
               -- Check for a data bus error
               for i in 0 to SiZE_16BITS_G loop
                  if txData.data(15 downto 0) /= txData.data(i*16+15 downto i*16) then
                     v.errDataBus := '1';
                  end if;
               end loop;
               -- Increment the counter
               v.dataCnt := r.dataCnt + 1;
               -- Next State
               v.state   := LOWER_S;
            end if;
         ----------------------------------------------------------------------
         when LOWER_S =>
            -- Check for a FIFO read
            if (txData.valid = '1') and (r.txCtrl.ready = '1') then
               -- Calculate the next data word
               v.randomData                := lfsrShift(r.randomData, TAP_C);
               -- Latch the lower packetLength value
               v.packetLength(15 downto 0) := txData.data(15 downto 0);
               -- Check for a data bus error
               for i in 0 to SiZE_16BITS_G loop
                  if txData.data(15 downto 0) /= txData.data(i*16+15 downto i*16) then
                     v.errDataBus := '1';
                  end if;
               end loop;
               -- Increment the counter
               v.dataCnt := r.dataCnt + 1;
               -- Next State
               v.state   := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check for a FIFO read
            if (txData.valid = '1') and (r.txCtrl.ready = '1') then
               -- Check for a data bus error
               for i in 0 to SiZE_16BITS_G loop
                  if txData.data(15 downto 0) /= txData.data(i*16+15 downto i*16) then
                     v.errDataBus := '1';
                  end if;
               end loop;
               -- Calculate the next data word
               v.randomData := lfsrShift(r.randomData, TAP_C);
               -- Increment the data counter
               v.dataCnt    := r.dataCnt + 1;
               -- Compare the data word to calculated data word
               if r.randomData(15 downto 0) /= txData.data(15 downto 0) then
                  -- Check for roll over
                  if r.errWordCnt /= MAX_ERR_CNT_C then
                     -- Increment the word error counter
                     v.errWordCnt := r.errWordCnt + 1;
                  end if;
                  -- Latch the bits with error
                  v.errorBits         := (r.randomData(15 downto 0) xor txData.data(15 downto 0));
                  -- Stop reading the FIFO
                  v.txCtrl.ready      := '0';
                  v.txCtrl.almostFull := '1';
                  -- Check the eof flag
                  if (r.dataCnt = r.packetLength) or (txData.eof = '1') then
                     -- Reset the counter
                     v.dataCnt := (others => '0');
                     -- Set the local eof flag
                     v.eof     := '1';
                     -- Latch the packets eofe flag
                     v.eofe    := txData.eofe;
                     -- Check the data packet length
                     if (r.dataCnt /= r.packetLength) or (txData.eof = '0') then
                        -- wrong length detected
                        v.errLength := '1';
                     end if;
                  end if;
                  -- Next State
                  v.state := BIT_ERR_S;
               -- Valid Data has been detected
               -- Now going to check the eof flag and packet length
               elsif (r.dataCnt = r.packetLength) or (txData.eof = '1') then
                  -- Reset the counter
                  v.dataCnt := (others => '0');
                  -- Set the local eof flag
                  v.eof     := '1';
                  -- Latch the packets eofe flag
                  v.eofe    := txData.eofe;
                  -- Check the data packet length
                  if (r.dataCnt /= r.packetLength) or (txData.eof = '0') then
                     -- wrong length detected
                     v.errLength := '1';
                  end if;
                  -- Stop reading the FIFO
                  v.txCtrl.ready      := '0';
                  v.txCtrl.almostFull := '1';
                  -- Next State
                  v.state             := SEND_RESULT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BIT_ERR_S =>
            -- Increment the counter
            v.bitPntr := r.bitPntr + 1;
            -- Check for an error bit
            if r.errorBits(conv_integer(r.bitPntr)) = '1' then
               -- Check for roll over
               if r.errbitCnt /= MAX_ERR_CNT_C then
                  -- Increment the bit error counter
                  v.errbitCnt := r.errbitCnt + 1;
               end if;
            end if;
            -- Check the bit pointer
            if r.bitPntr = 15 then
               -- Reset the counter
               v.bitPntr := (others => '0');
               -- Check if there was an eof flag
               if r.eof = '1' then
                  -- Next State
                  v.state := SEND_RESULT_S;
               else
                  -- Ready for more data
                  v.txCtrl.ready      := '1';
                  v.txCtrl.almostFull := '0';
                  -- Next State
                  v.state             := DATA_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEND_RESULT_S =>
            -- Check the upstream buffer status
            if rxCtrl.almostFull = '0' then
               -- Sending Data 
               v.rxData.valid := '1';
               -- Increment the data counter
               v.dataCnt      := r.dataCnt + 1;
               -- Send data w.r.t. the counter
               case (r.dataCnt) is
                  when toSlv(0, 32) =>
                     -- Update strobe for the results
                     v.updatedResults            := '1';
                     -- Write the data to the TX virtual channel
                     v.rxData.sof                := '1';
                     v.rxData.data(31 downto 16) := x"FFFF";  -- static pattern for software alignment
                     v.rxData.data(15 downto 8)  := toSlv(LANE_NUMBER_G, 8);  -- pointer to the Virtual Channel
                     v.rxData.data(7 downto 0)   := toSlv(VC_NUMBER_G, 8);  -- pointer to the Virtual Channel
                  when toSlv(1, 32) =>
                     v.rxData.data(31 downto 0) := r.packetLength;
                  when toSlv(2, 32) =>
                     v.rxData.data(31 downto 0) := r.packetRate;
                  when toSlv(3, 32) =>
                     v.rxData.data(31 downto 0) := r.errWordCnt;
                  when toSlv(4, 32) =>
                     v.rxData.data(31 downto 0) := r.errbitCnt;
                  when others =>
                     -- Reset the counter
                     v.dataCnt                  := (others => '0');
                     -- Send the last word
                     v.rxData.eof               := '1';
                     v.rxData.data(31 downto 4) := (others => '0');
                     v.rxData.data(3)           := r.errDataBus;
                     v.rxData.data(2)           := r.eofe;
                     v.rxData.data(1)           := r.errLength;
                     v.rxData.data(0)           := r.errMissedPacket;
                     -- Ready to receive data
                     v.txCtrl.ready             := '1';
                     v.txCtrl.almostFull        := '0';
                     -- Reset the busy flag
                     v.busy                     := '0';
                     -- Next State
                     v.state                    := IDLE_S;
               end case;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (vcRxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      txCtrl          <= r.txCtrl;
      rxData          <= r.rxData;
      updatedResults  <= r.updatedResults;
      errMissedPacket <= r.errMissedPacket;
      errLength       <= r.errLength;
      errDataBus      <= r.errDataBus;
      errEofe         <= r.eofe;
      errWordCnt      <= r.errWordCnt;
      errbitCnt       <= r.errbitCnt;
      packetRate      <= r.packetRate;
      busy            <= r.busy;
      packetLength    <= r.packetLength;
      
   end process comb;

   seq : process (vcRxClk) is
   begin
      if rising_edge(vcRxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   Vc64Fifo_TX : entity work.Vc64FifoMux
      generic map (
         TPD_G              => TPD_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         RX_LANES_G         => 2,
         TX_LANES_G         => 1,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         BRAM_EN_G          => BRAM_EN_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         PIPE_STAGES_G      => PIPE_STAGES_G,
         FIFO_SYNC_STAGES_G => FIFO_SYNC_STAGES_G,
         FIFO_ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G,
         FIFO_AFULL_THRES_G => FIFO_AFULL_THRES_G)      
      port map (
         -- Streaming RX Data Interface (vcRxClk domain) 
         vcRxData => rxData,
         vcRxCtrl => rxCtrl,
         vcRxClk  => vcRxClk,
         vcRxRst  => vcRxRst,
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxCtrl => vcTxCtrl,
         vcTxData => vcTxData,
         vcTxClk  => vcTxClk,
         vcTxRst  => vcTxRst);         

end rtl;
