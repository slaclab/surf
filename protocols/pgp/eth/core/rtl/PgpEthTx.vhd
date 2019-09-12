-------------------------------------------------------------------------------
-- Title      : PgpEth Transmit
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use work.PgpEthPkg.all;

entity PgpEthTx is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_VC_G           : positive range 1 to 16 := 1;
      MAX_PAYLOAD_SIZE_G : positive               := 1024);  -- Must be a multiple of 64B (in units of bytes)
   port (
      -- Ethernet Configuration
      remoteMac      : in  slv(47 downto 0);
      localMac       : in  slv(47 downto 0);
      broadcastMac   : in  slv(47 downto 0);
      etherType      : in  slv(15 downto 0);
      -- User interface
      pgpClk         : in  sl;
      pgpRst         : in  sl;
      pgpTxIn        : in  PgpEthTxInType;
      pgpTxOut       : out PgpEthTxOutType;
      pgpTxMasters   : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves    : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Status of receive and remote FIFOs
      locRxFifoCtrl  : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady : in  sl;
      remRxFifoCtrl  : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : in  sl;
      -- PHY interface
      phyTxRdy       : in  sl;
      phyTxMaster    : out AxiStreamMasterType;
      phyTxSlave     : in  AxiStreamSlaveType);
end entity PgpEthTx;

architecture rtl of PgpEthTx is

   constant MAX_SIZE_C : positive := (MAX_PAYLOAD_SIZE_G/64);  -- units of 512-bit words

   type StateType is (
      IDLE_S,
      HDR_S,
      PAYLOAD_S,
      FOOTER_S);

   type RegType is record
      disableSel   : slv(NUM_VC_G-1 downto 0);
      sof          : slv(15 downto 0);
      eof          : sl;
      eofe         : sl;
      lastKeep     : slv(63 downto 0);
      wrdCnt       : natural range 0 to MAX_SIZE_C;
      tid          : slv(7 downto 0);
      nullCnt      : slv(31 downto 0);
      nullInterval : slv(31 downto 0);
      pause        : slv(15 downto 0);
      lastPausSent : slv(15 downto 0);
      tDest        : slv(7 downto 0);
      pgpTxOut     : PgpEthTxOutType;
      pgpTxSlave   : AxiStreamSlaveType;
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      disableSel   => (others => '0'),
      sof          => (others => '1'),
      eof          => '0',
      eofe         => '0',
      lastKeep     => (others => '1'),
      wrdCnt       => 0,
      tid          => (others => '0'),
      nullCnt      => (others => '0'),
      nullInterval => (others => '0'),
      pause        => (others => '0'),
      lastPausSent => (others => '0'),
      tDest        => (others => '0'),
      pgpTxOut     => PGP_ETH_TX_OUT_INIT_C,
      pgpTxSlave   => AXI_STREAM_SLAVE_INIT_C,
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ibTxMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal ibTxSlaves  : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

   signal pgpTxMaster : AxiStreamMasterType;
   signal pgpTxSlave  : AxiStreamSlaveType;

   signal txSlave : AxiStreamSlaveType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   GEN_VEC :
   for i in (NUM_VC_G-1) downto 0 generate

      U_Pipeline : entity work.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => 1)
         port map (
            axisClk     => pgpClk,
            axisRst     => pgpRst,
            sAxisMaster => pgpTxMasters(i),
            sAxisSlave  => pgpTxSlaves(i),
            mAxisMaster => ibTxMasters(i),
            mAxisSlave  => ibTxSlaves(i));

   end generate GEN_VEC;

   ------------------------------------------------------
   -- Multiplex the incoming TX streams with interleaving
   ------------------------------------------------------
   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => NUM_VC_G,
         PIPE_STAGES_G        => 0,  -- 0 to keep the MUX and TX FSM in "lock step" to each other
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => true,
         ILEAVE_REARB_G       => MAX_SIZE_C)
      port map (
         axisClk      => pgpClk,
         axisRst      => pgpRst,
         disableSel   => r.disableSel,
         sAxisMasters => ibTxMasters,
         sAxisSlaves  => ibTxSlaves,
         mAxisMaster  => pgpTxMaster,
         mAxisSlave   => pgpTxSlave);

   comb : process (broadcastMac, etherType, locRxFifoCtrl, locRxLinkReady,
                   localMac, pgpRst, pgpTxIn, pgpTxMaster, phyTxRdy, r,
                   remRxFifoCtrl, remRxLinkReady, remoteMac, txSlave) is
      variable v          : RegType;
      variable remoteRdy  : sl;
      variable pauseEvent : sl;
   begin
      -- Latch the current value
      v := r;

      -- Update the variable
      pauseEvent := '0';
      remoteRdy  := pgpTxIn.flowCntlDis or remRxLinkReady;

      -- Update/Reset the flags
      v.pgpTxOut.opCodeReady := '0';
      v.pgpTxOut.frameTx     := '0';
      v.pgpTxOut.frameTxErr  := '0';
      v.pgpTxOut.phyTxActive := phyTxRdy;
      v.pgpTxOut.linkReady   := phyTxRdy;

      -- AXI Stream Flow Control
      v.pgpTxSlave.tReady := '0';
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tKeep  := (others => '1');
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Loop through the bits
      for i in NUM_VC_G-1 downto 0 loop

         -- Map the FIFO control bits to PGP non-VC bus
         v.pgpTxOut.locOverflow(i) := locRxFifoCtrl(i).overflow;
         v.pgpTxOut.locPause(i)    := locRxFifoCtrl(i).pause;

         -- Latch the pause bits with the payload transport
         if (locRxFifoCtrl(i).pause = '1') then
            v.pause(i) := '1';
         end if;

         -- Check for 0->1 pause event during the IDLE_S state
         if (locRxFifoCtrl(i).pause = '1') and (r.lastPausSent(i) = '0') then
            pauseEvent := '1';
         end if;

      end loop;

      -- Keep delayed copy
      v.nullInterval := pgpTxIn.nullInterval;

      -- Check for change in configuration
      if (pgpTxIn.nullInterval /= r.nullInterval) then
         -- Force a NULL message
         v.nullCnt := (others => '0');
      -- Check if need to decrement the counter
      elsif (r.nullCnt /= 0) then
         -- Increment the counter
         v.nullCnt := r.nullCnt - 1;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if PHY is up
            if (phyTxRdy = '1') then

               -- Check for NULL timeout event
               if (r.nullCnt = 0) then
                  -- Next state
                  v.state := HDR_S;

               -- Check if remote is ready
               elsif (remoteRdy = '1') then

                  -- Check for send event
                  if (pgpTxMaster.tValid = '1') or  -- payload data
                     (pgpTxIn.opCodeEn = '1') or    -- OP-Code Event
                     (pauseEvent = '1') then        -- 0->1 pause event

                     -- Next state
                     v.state := HDR_S;

                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when HDR_S =>
            -- Reset the counter
            v.wrdCnt := 0;

            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Move the data
               v.txMaster.tValid := '1';

               -- Reset the data bus
               v.txMaster.tData := (others => '0');

               -- Insert the SOF bit
               ssiSetUserSof(PGP_ETH_AXIS_CONFIG_C, v.txMaster, '1');

               -- Check if remote link up
               if (remoteRdy = '1') then
                  -- BYTE[5:0] = Destination MAC
                  v.txMaster.tData(47 downto 0) := remoteMac;
               else
                  -- BYTE[5:0] = Destination MAC = Broadcast
                  v.txMaster.tData(47 downto 0) := broadcastMac;
               end if;

               -- BYTE[11:6] = Source MAC
               v.txMaster.tData(95 downto 48) := localMac;

               -- BYTE[13:12] = EtherType
               v.txMaster.tData(111 downto 96) := etherType;

               -- BYTE[14] = Version
               v.txMaster.tData(119 downto 112) := PGP_ETH_VERSION_C;

               -- BYTE[15] = TID
               v.txMaster.tData(127 downto 120) := r.tid;

               -- BYTE[17:16] = Virtual Channel Pause
               v.txMaster.tData(143 downto 128) := v.pause;

               -- Check if there is payload
               if (pgpTxMaster.tValid = '1') then

                  -- Match the PHY TDEST to PGP tDEST (useful for debugging)
                  v.txMaster.tDest := pgpTxMaster.tDest;

                  -- BYTE[18] = Virtual Channel Index
                  v.txMaster.tData(151 downto 144) := pgpTxMaster.tDest;

                  -- BYTE[19] = SOF 
                  v.txMaster.tData(152) := r.sof(conv_integer(pgpTxMaster.tDest));

                  -- Reset the flag
                  v.sof(conv_integer(pgpTxMaster.tDest)) := '0';

               else

                  -- Match the PHY TDEST to NULL tDEST (useful for debugging)
                  v.txMaster.tDest := x"FF";

                  -- BYTE[18] = NULL Marker
                  v.txMaster.tData(151 downto 144) := x"FF";

               end if;

               -- BYTE[20] = OP-Code Enable
               v.txMaster.tData(160) := pgpTxIn.opCodeEn and remoteRdy;

               -- BYTE[21] = RxLinkReady
               v.txMaster.tData(168) := locRxLinkReady;

               -- BYTE[31:22] = Reserved

               -- BYTE[47:32] = OpCodeData
               v.txMaster.tData(383 downto 256) := pgpTxIn.opCode;

               -- BYTE[63:48] = LocalData
               v.txMaster.tData(511 downto 384) := pgpTxIn.locData;

               -- Accept the OP-code
               v.pgpTxOut.opCodeReady := pgpTxIn.opCodeEn and remoteRdy;

               -- Increment the counter
               v.tid := r.tid + 1;

               -- Sample the last pause sent
               v.lastPausSent := v.pause;

               -- Check if link remote RX link not up
               if (remoteRdy = '0') then
                  -- Terminate the frame to make NULL frame
                  v.txMaster.tLast := '1';
                  -- Next state
                  v.state          := IDLE_S;

               -- Check if there is payload
               elsif (pgpTxMaster.tValid = '1') then
                  -- Track the current tDest
                  v.tDest := pgpTxMaster.tDest;

                  -- Reset the counter
                  v.pgpTxOut.frameTxSize := (others => '0');

                  -- Next state
                  v.state := PAYLOAD_S;

               -- Check no payload
               else
                  -- Terminate the frame to make NULL frame
                  v.txMaster.tLast := '1';
                  -- Next state
                  v.state          := IDLE_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (pgpTxMaster.tValid = '1') then

               -- Check for change in tDEST
               if (pgpTxMaster.tDest /= r.tDest) then
                  -------------------------------------------------------------
                  --                Execute the footer here
                  -------------------------------------------------------------

                  -- Move the data
                  v.txMaster.tValid             := '1';
                  v.txMaster.tLast              := '1';
                  v.txMaster.tKeep              := resize(x"F", AXI_STREAM_MAX_TKEEP_WIDTH_C);  -- 4 byte footer
                  v.txMaster.tData(31 downto 0) := (others => '0');

                  -- Send the metadata
                  v.txMaster.tData(7 downto 0) := x"40";  -- tKeep(63:0) = all ones
                  v.txMaster.tData(8)          := '0';    -- EOF = 0x0
                  v.txMaster.tData(9)          := '0';    -- EOFE = 0x0

                  -- Forward the updated pause
                  v.txMaster.tData(31 downto 16) := v.pause;

                  -- Update flag
                  v.pgpTxOut.frameTx := '1';

                  -- Sample the last pause sent
                  v.lastPausSent := v.pause;

                  -- Next state
                  v.state := IDLE_S;

               else

                  -- Accept the data
                  v.pgpTxSlave.tReady := '1';

                  -- Move the data
                  v.txMaster := pgpTxMaster;

                  -- Update the metadata
                  v.txMaster.tLast := '0';
                  v.txMaster.tKeep := (others => '1');
                  v.txMaster.tUser := (others => '0');

                  -- Increment the counters
                  v.wrdCnt               := r.wrdCnt + 1;
                  v.pgpTxOut.frameTxSize := r.pgpTxOut.frameTxSize + getTKeep(pgpTxMaster.tKeep, PGP_ETH_AXIS_CONFIG_C);

                  -- Check for EOF or max payload size
                  if (pgpTxMaster.tLast = '1') or (r.wrdCnt = MAX_SIZE_C-1) then

                     -- Sample the metadata
                     v.eof      := pgpTxMaster.tLast;
                     v.eofe     := ssiGetUserEofe(PGP_ETH_AXIS_CONFIG_C, pgpTxMaster);
                     v.lastKeep := pgpTxMaster.tKeep(63 downto 0);

                     -- Check if need to arm for SOF
                     if (pgpTxMaster.tLast = '1') then
                        v.sof(conv_integer(pgpTxMaster.tDest)) := '1';
                     end if;

                     -- Next state
                     v.state := FOOTER_S;

                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when FOOTER_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then

               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tLast              := '1';
               v.txMaster.tKeep              := resize(x"F", AXI_STREAM_MAX_TKEEP_WIDTH_C);  -- 4 byte footer
               v.txMaster.tData(31 downto 0) := (others => '0');

               -- Check for tLast
               if (r.eof = '1') then
                  v.txMaster.tData(7 downto 0) := toSlv(getTKeep(r.lastKeep, PGP_ETH_AXIS_CONFIG_C), 8);
                  v.txMaster.tData(8)          := r.eof;
                  v.txMaster.tData(9)          := r.eofe;
               end if;

               -- Forward the updated pause
               v.txMaster.tData(31 downto 16) := v.pause;

               -- Update flag
               v.pgpTxOut.frameTx := '1';

               -- Sample the last pause sent
               v.lastPausSent := v.pause;

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check if next state is HDR_S
      if (v.state = HDR_S) then
         -- Reset the pause bits
         v.pause := (others => '0');
      end if;

      -- Check if next state is IDLE_S and currently not in IDLE_S
      if (v.state = IDLE_S) and (r.state /= IDLE_S) then
         -- Pre-set the counter
         v.nullCnt := pgpTxIn.nullInterval;
      end if;

      -- All flow control overridden by pgpTxIn 'disable' and 'flowCntlDis'
      for i in NUM_VC_G-1 downto 0 loop

         -- Forced disable
         if (pgpTxIn.disable = '1') then
            v.disableSel(i) := '1';

         -- No flow control
         elsif (pgpTxIn.flowCntlDis = '1') then
            v.disableSel(i) := '0';

         -- Prevent disabling while in the middle of payload transport
         elsif (v.state = PAYLOAD_S) and (pgpTxMaster.tDest = i)then
            v.disableSel(i) := '0';

         -- Else disable same as remote pause
         else
            v.disableSel(i) := remRxFifoCtrl(i).pause or not(remoteRdy);
         end if;

      end loop;

      -- Outputs        
      pgpTxSlave <= v.pgpTxSlave;

      pgpTxOut             <= r.pgpTxOut;
      pgpTxOut.opCodeReady <= v.pgpTxOut.opCodeReady;

      -- Reset
      if (pgpRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (pgpClk) is
   begin
      if rising_edge(pgpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => pgpClk,
         axisRst     => pgpRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => phyTxMaster,
         mAxisSlave  => phyTxSlave);

end rtl;
