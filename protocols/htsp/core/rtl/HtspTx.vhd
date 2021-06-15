-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: HTSP Ethernet Transmitter
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
use surf.SsiPkg.all;
use surf.HtspPkg.all;

entity HtspTx is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_VC_G           : positive range 1 to 16 := 1;
      MAX_PAYLOAD_SIZE_G : positive               := 8192);  -- Must be a multiple of 64B (in units of bytes)
   port (
      -- Ethernet Configuration
      remoteMac      : in  slv(47 downto 0);
      localMac       : in  slv(47 downto 0);
      broadcastMac   : in  slv(47 downto 0);
      etherType      : in  slv(15 downto 0);
      -- User interface
      htspClk        : in  sl;
      htspRst        : in  sl;
      htspTxIn       : in  HtspTxInType;
      htspTxOut      : out HtspTxOutType;
      htspTxMasters  : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspTxSlaves   : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Status of receive and remote FIFOs
      locRxFifoCtrl  : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady : in  sl;
      remRxFifoCtrl  : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : in  sl;
      -- PHY interface
      phyTxRdy       : in  sl;
      phyTxMaster    : out AxiStreamMasterType;
      phyTxSlave     : in  AxiStreamSlaveType);
end entity HtspTx;

architecture rtl of HtspTx is

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
      htspTxOut    : HtspTxOutType;
      htspTxSlave  : AxiStreamSlaveType;
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
      htspTxOut    => HTSP_TX_OUT_INIT_C,
      htspTxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ibTxMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal ibTxSlaves  : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

   signal htspTxMaster : AxiStreamMasterType;
   signal htspTxSlave  : AxiStreamSlaveType;

   signal txSlave : AxiStreamSlaveType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   assert (isPowerOf2(MAX_PAYLOAD_SIZE_G) = true)
      report "MAX_PAYLOAD_SIZE_G must be power of 2" severity failure;

   GEN_VEC :
   for i in (NUM_VC_G-1) downto 0 generate

      U_Pipeline : entity surf.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => 1)
         port map (
            axisClk     => htspClk,
            axisRst     => htspRst,
            sAxisMaster => htspTxMasters(i),
            sAxisSlave  => htspTxSlaves(i),
            mAxisMaster => ibTxMasters(i),
            mAxisSlave  => ibTxSlaves(i));

   end generate GEN_VEC;

   ------------------------------------------------------
   -- Multiplex the incoming TX streams with interleaving
   ------------------------------------------------------
   U_Mux : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => NUM_VC_G,
         PIPE_STAGES_G        => 0,  -- 0 to keep the MUX and TX FSM in "lock step" to each other
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => true,
         ILEAVE_REARB_G       => MAX_SIZE_C)
      port map (
         axisClk      => htspClk,
         axisRst      => htspRst,
         disableSel   => r.disableSel,
         sAxisMasters => ibTxMasters,
         sAxisSlaves  => ibTxSlaves,
         mAxisMaster  => htspTxMaster,
         mAxisSlave   => htspTxSlave);

   comb : process (broadcastMac, etherType, htspRst, htspTxIn, htspTxMaster,
                   locRxFifoCtrl, locRxLinkReady, localMac, phyTxRdy, r,
                   remRxFifoCtrl, remRxLinkReady, remoteMac, txSlave) is
      variable v          : RegType;
      variable remoteRdy  : sl;
      variable pauseEvent : sl;
      variable hdrXsum    : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Update the variable
      pauseEvent := '0';
      remoteRdy  := htspTxIn.flowCntlDis or remRxLinkReady;
      hdrXsum    := (others => '0');

      -- Update/Reset the flags
      v.htspTxOut.opCodeReady := '0';
      v.htspTxOut.frameTx     := '0';
      v.htspTxOut.frameTxErr  := '0';
      v.htspTxOut.phyTxActive := phyTxRdy;
      v.htspTxOut.linkReady   := phyTxRdy;

      -- AXI Stream Flow Control
      v.htspTxSlave.tReady := '0';
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tKeep  := (others => '1');
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Loop through the bits
      for i in NUM_VC_G-1 downto 0 loop

         -- Map the FIFO control bits to HTSP non-VC bus
         v.htspTxOut.locOverflow(i) := locRxFifoCtrl(i).overflow;
         v.htspTxOut.locPause(i)    := locRxFifoCtrl(i).pause;

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
      v.nullInterval := htspTxIn.nullInterval;

      -- Check for change in configuration
      if (htspTxIn.nullInterval /= r.nullInterval) then
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
                  if (htspTxMaster.tValid = '1') or  -- payload data
                     (htspTxIn.opCodeEn = '1') or    -- OP-Code Event
                     (pauseEvent = '1') then         -- 0->1 pause event

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
               ssiSetUserSof(HTSP_AXIS_CONFIG_C, v.txMaster, '1');

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
               v.txMaster.tData(119 downto 112) := HTSP_VERSION_C;

               -- BYTE[15] = TID
               v.txMaster.tData(127 downto 120) := r.tid;

               -- BYTE[17:16] = Virtual Channel Pause
               v.txMaster.tData(143 downto 128) := v.pause;

               -- Check if there is payload
               if (htspTxMaster.tValid = '1') then

                  -- Match the PHY TDEST to HTSP tDEST (useful for debugging)
                  v.txMaster.tDest := htspTxMaster.tDest;

                  -- BYTE[18] = Virtual Channel Index
                  v.txMaster.tData(151 downto 144) := htspTxMaster.tDest;

                  -- BYTE[19] = SOF
                  v.txMaster.tData(152) := r.sof(conv_integer(htspTxMaster.tDest));

                  -- Reset the flag
                  v.sof(conv_integer(htspTxMaster.tDest)) := '0';

               else

                  -- Match the PHY TDEST to NULL tDEST (useful for debugging)
                  v.txMaster.tDest := x"FF";

                  -- BYTE[18] = NULL Marker
                  v.txMaster.tData(151 downto 144) := x"FF";

               end if;

               -- BYTE[20] = OP-Code Enable
               v.txMaster.tData(160) := htspTxIn.opCodeEn and remoteRdy;

               -- BYTE[21] = RxLinkReady
               v.txMaster.tData(168) := locRxLinkReady;

               -- BYTE[29:22] = Reserved

               -- BYTE[31:30] = Header Checksum
               --------------------------------
               -- // Processed at the end // --
               --------------------------------

               -- BYTE[47:32] = OpCodeData
               v.txMaster.tData(383 downto 256) := htspTxIn.opCode;

               -- BYTE[63:48] = LocalData
               v.txMaster.tData(511 downto 384) := htspTxIn.locData;

               -- Accept the OP-code
               v.htspTxOut.opCodeReady := htspTxIn.opCodeEn and remoteRdy;

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
               elsif (htspTxMaster.tValid = '1') then
                  -- Track the current tDest
                  v.tDest := htspTxMaster.tDest;

                  -- Reset the counters
                  v.htspTxOut.frameTxSize := (others => '0');

                  -- Next state
                  v.state := PAYLOAD_S;

               -- Check no payload
               else
                  -- Terminate the frame to make NULL frame
                  v.txMaster.tLast := '1';
                  -- Next state
                  v.state          := IDLE_S;
               end if;

               -- Calculate the checksum
               for i in 29 downto 0 loop
                  hdrXsum := hdrXsum + v.txMaster.tData(8*i+7 downto 8*i);
               end loop;
               for i in 63 downto 32 loop
                  hdrXsum := hdrXsum + v.txMaster.tData(8*i+7 downto 8*i);
               end loop;
               hdrXsum := not(hdrXsum);  -- one's complement

               -- BYTE[31:30] = Header Checksum
               v.txMaster.tData(255 downto 240) := hdrXsum;

            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (htspTxMaster.tValid = '1') then

               -- Check for change in tDEST
               if (htspTxMaster.tDest /= r.tDest) then

                  -- Next state
                  v.state := FOOTER_S;

               else

                  -- Accept the data
                  v.htspTxSlave.tReady := '1';

                  -- Move the data
                  v.txMaster := htspTxMaster;

                  -- Check the non-tKeep bytes to zero
                  for i in 63 downto 0 loop
                     if htspTxMaster.tKeep(i) = '0' then
                        v.txMaster.tData(8*i+7 downto 8*i) := x"00";
                     end if;
                  end loop;

                  -- Update the metadata
                  v.txMaster.tLast := '0';
                  v.txMaster.tKeep := (others => '1');
                  v.txMaster.tUser := (others => '0');

                  -- Increment the counters
                  v.wrdCnt                := r.wrdCnt + 1;
                  v.htspTxOut.frameTxSize := r.htspTxOut.frameTxSize + getTKeep(htspTxMaster.tKeep, HTSP_AXIS_CONFIG_C);

                  -- Sample the metadata
                  v.eof      := htspTxMaster.tLast;
                  v.eofe     := ssiGetUserEofe(HTSP_AXIS_CONFIG_C, htspTxMaster) and htspTxMaster.tLast;
                  v.lastKeep := htspTxMaster.tKeep(63 downto 0);

                  -- Check for EOF or max payload size
                  if (htspTxMaster.tLast = '1') or (r.wrdCnt = MAX_SIZE_C-1) then

                     -- Check if need to arm for SOF
                     if (htspTxMaster.tLast = '1') then
                        v.sof(conv_integer(htspTxMaster.tDest)) := '1';
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
               v.txMaster.tKeep              := resize(x"3F", AXI_STREAM_MAX_TKEEP_WIDTH_C);  -- 6 byte footer
               v.txMaster.tData(47 downto 0) := (others => '0');

               -- Forward the lastKeep/eof/eofe
               v.txMaster.tData(7 downto 0) := toSlv(getTKeep(r.lastKeep, HTSP_AXIS_CONFIG_C), 8);
               v.txMaster.tData(8)          := r.eof;
               v.txMaster.tData(9)          := r.eofe;

               -- Forward the updated pause
               v.txMaster.tData(31 downto 16) := v.pause;

               -- Forward the payload size
               v.txMaster.tData(47 downto 32) := r.htspTxOut.frameTxSize;

               -- Update flag
               v.htspTxOut.frameTx := '1';

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
         v.nullCnt := htspTxIn.nullInterval;
      end if;

      -- All flow control overridden by htspTxIn 'disable' and 'flowCntlDis'
      for i in NUM_VC_G-1 downto 0 loop

         -- Forced disable
         if (htspTxIn.disable = '1') then
            v.disableSel(i) := '1';

         -- No flow control
         elsif (htspTxIn.flowCntlDis = '1') then
            v.disableSel(i) := '0';

         -- Prevent disabling while in the middle of payload transport
         elsif (v.state = PAYLOAD_S) and (htspTxMaster.tDest = i)then
            v.disableSel(i) := '0';

         -- Else disable same as remote pause
         else
            v.disableSel(i) := remRxFifoCtrl(i).pause or not(remoteRdy);
         end if;

      end loop;

      -- Outputs
      htspTxSlave <= v.htspTxSlave;

      htspTxOut             <= r.htspTxOut;
      htspTxOut.opCodeReady <= v.htspTxOut.opCodeReady;

      -- Reset
      if (htspRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (htspClk) is
   begin
      if rising_edge(htspClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => htspClk,
         axisRst     => htspRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => phyTxMaster,
         mAxisSlave  => phyTxSlave);

end rtl;
