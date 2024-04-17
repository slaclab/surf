-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Transmit Protocol
-- Takes pre-packetized AxiStream frames and creates a PGPv3 66/64 protocol
-- stream (pre-scrambler). Inserts IDLE and SKP codes as needed. Inserts
-- user K codes on request.
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
use surf.AxiStreamPacketizer2Pkg.all;
use surf.SsiPkg.all;
use surf.Pgp3Pkg.all;

entity Pgp3TxProtocol is

   generic (
      TPD_G            : time                  := 1 ns;
      NUM_VC_G         : integer range 1 to 16 := 4;
      STARTUP_HOLD_G   : integer               := 1000);
   port (
      -- User Transmit interface
      pgpTxClk    : in  sl;
      pgpTxRst    : in  sl;
      pgpTxIn     : in  Pgp3TxInType := PGP3_TX_IN_INIT_C;
      pgpTxOut    : out Pgp3TxOutType;
      pgpTxMaster : in  AxiStreamMasterType;
      pgpTxSlave  : out AxiStreamSlaveType;

      -- Status of local receive fifos
      -- These get synchronized by the Pgp3Tx parent
      locRxFifoCtrl  : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady : in sl;
      remRxLinkReady : in sl;

      -- Output Interface
      phyTxActive    : in  sl;
      protTxReady    : in  sl;
      protTxValid    : out sl;
      protTxStart    : out sl;
      protTxData     : out slv(63 downto 0);
      protTxHeader   : out slv(1 downto 0));

end entity Pgp3TxProtocol;

architecture rtl of Pgp3TxProtocol is

   type RegType is record
      pauseDly          : slv(NUM_VC_G-1 downto 0);
      pauseEvent        : slv(NUM_VC_G-1 downto 0);
      pauseEventSent    : slv(NUM_VC_G-1 downto 0);
      overflowDly       : slv(NUM_VC_G-1 downto 0);
      overflowEvent     : slv(NUM_VC_G-1 downto 0);
      overflowEventSent : slv(NUM_VC_G-1 downto 0);
      skpInterval       : slv(31 downto 0);
      skpCount          : slv(31 downto 0);
      startupCount      : integer;
      pgpTxSlave        : AxiStreamSlaveType;
      opCodeReady       : sl;
      linkReady         : sl;
      frameTx           : sl;
      frameTxErr        : sl;
      protTxValid       : sl;
      protTxStart       : sl;
      protTxData        : slv(63 downto 0);
      protTxHeader      : slv(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      pauseDly          => (others => '0'),
      pauseEvent        => (others => '0'),
      pauseEventSent    => (others => '0'),
      overflowDly       => (others => '0'),
      overflowEvent     => (others => '0'),
      overflowEventSent => (others => '0'),
      skpInterval       => PGP3_TX_IN_INIT_C.skpInterval,
      skpCount          => (others => '0'),
      startupCount      => 0,
      pgpTxSlave        => AXI_STREAM_SLAVE_INIT_C,
      opCodeReady       => '0',
      linkReady         => '0',
      frameTx           => '0',
      frameTxErr        => '0',
      protTxValid       => '0',
      protTxStart       => '0',
      protTxData        => (others => '0'),
      protTxHeader      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (locRxFifoCtrl, locRxLinkReady, pgpTxIn, pgpTxMaster, pgpTxRst, phyTxActive,
                   protTxReady, r, remRxLinkReady) is
      variable v                  : RegType;
      variable linkInfo           : slv(39 downto 0);
      variable dataEn             : sl;
      variable rxFifoCtrl         : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      variable resetEventMetaData : boolean;
   begin
      -- Latch the current value
      v := r;

      -- Update the variables default values
      resetEventMetaData := false;
      rxFifoCtrl         := locRxFifoCtrl;

      -- Detect 0->1 edges on locRxFifoCtrl(i).pause and locRxFifoCtrl(i).overflow
      for i in NUM_VC_G-1 downto 0 loop
         -- Save last value for edge detection
         v.pauseDly(i)    := locRxFifoCtrl(i).pause;
         v.overflowDly(i) := locRxFifoCtrl(i).overflow;

         -- Check for rising edge on pause
         if (locRxFifoCtrl(i).pause = '1') and (r.pauseDly(i) = '0') then
            v.pauseEvent(i) := '1';
         end if;

         -- Check for rising edge on overflow
         if (locRxFifoCtrl(i).overflow = '1') and (r.overflowDly(i) = '0') then
            v.overflowEvent(i) := '1';
         end if;

         -- Include the pauseEvent or overflowEvent in the linkInfo message
         rxFifoCtrl(i).pause    := r.pauseEvent(i) or locRxFifoCtrl(i).pause;
         rxFifoCtrl(i).overflow := r.overflowEvent(i) or locRxFifoCtrl(i).overflow;
      end loop;

      -- Generate the link information message
      linkInfo := pgp3MakeLinkInfo(rxFifoCtrl, locRxLinkReady);

      -- Keep delay copy of skip interval configuration
      v.skpInterval := pgpTxIn.skpInterval;

      -- Check for change in configuration
      if (r.skpInterval /= v.skpInterval) then
         -- Force a skip
         v.skpCount := v.skpInterval;
      -- Check for counter roll over
      elsif (r.skpCount /= r.skpInterval) then
         -- Increment the counter
         v.skpCount := r.skpCount + 1;
      end if;

      -- Don't accept new frame data by default
      v.pgpTxSlave.tReady := '0';
      v.opCodeReady       := '0';

      v.frameTx    := '0';
      v.frameTxErr := '0';

      -- Check the handshaking
      if (protTxReady = '1') then
         v.protTxValid := '0';
      end if;

      dataEn := ite(pgpTxIn.flowCntlDis = '1', r.linkReady, remRxLinkReady);

      if (v.protTxValid = '0' and phyTxActive = '1') then

         -- Send only IDLE and SKP for STARTUP_HOLD_G cycles after reset
         if (r.startupCount = STARTUP_HOLD_G) then
            -- Set the flags
            v.linkReady   := '1';
            v.protTxStart := '1';
            v.protTxValid := '1';
         else
            -- Increment the counter
            v.startupCount := r.startupCount + 1;
         end if;

         -- Decide whether to send IDLE, SKP, USER or data frames.
         -- Coded in reverse order of priority

         -- Send idle chars by default
         v.protTxData                        := (others => '0');
         resetEventMetaData                  := true;
         v.protTxData(PGP3_LINKINFO_FIELD_C) := linkInfo;
         v.protTxData(PGP3_BTF_FIELD_C)      := PGP3_IDLE_C;
         v.protTxHeader                      := PGP3_K_HEADER_C;

         --------------------------------------------------------------------
         --                   Header and Data and Footer                   --
         --------------------------------------------------------------------

         -- Send data if there is data to send
         if (pgpTxMaster.tValid = '1' and dataEn = '1') then
            -- Accept the data
            v.pgpTxSlave.tReady := '1';
            -- Update the flag
            resetEventMetaData  := false;

            if (ssiGetUserSof(PGP3_AXIS_CONFIG_C, pgpTxMaster) = '1') then
               -- SOF/SOC, format SOF/SOC char from data
               v.protTxData                        := (others => '0');
               v.protTxData(PGP3_BTF_FIELD_C)      := ite(pgpTxMaster.tData(PACKETIZER2_HDR_SOF_BIT_C) = '1', PGP3_SOF_C, PGP3_SOC_C);
               v.protTxData(PGP3_LINKINFO_FIELD_C) := linkInfo;
               v.protTxData(PGP3_SOFC_VC_FIELD_C)  := resize(pgpTxMaster.tData(PACKETIZER2_HDR_TDEST_FIELD_C), 4);  -- Virtual Channel
               v.protTxData(PGP3_SOFC_SEQ_FIELD_C) := resize(pgpTxMaster.tData(PACKETIZER2_HDR_SEQ_FIELD_C), 12);  -- Packet number
               v.protTxHeader                      := PGP3_K_HEADER_C;

            elsif (pgpTxMaster.tLast = '1') then
               -- EOF/EOC
               v.protTxData                               := (others => '0');
               v.protTxData(PGP3_BTF_FIELD_C)             := ite(pgpTxMaster.tData(PACKETIZER2_TAIL_EOF_BIT_C) = '1', PGP3_EOF_C, PGP3_EOC_C);
               v.protTxData(PGP3_EOFC_TUSER_FIELD_C)      := pgpTxMaster.tData(PACKETIZER2_TAIL_TUSER_FIELD_C);  -- TUSER LAST
               v.protTxData(PGP3_EOFC_BYTES_LAST_FIELD_C) := pgpTxMaster.tData(PACKETIZER2_TAIL_BYTES_FIELD_C);  -- Last byte count
               v.protTxData(PGP3_EOFC_CRC_FIELD_C)        := pgpTxMaster.tData(PACKETIZER2_TAIL_CRC_FIELD_C);  -- CRC
               v.protTxHeader                             := PGP3_K_HEADER_C;
               -- Debug output
               v.frameTx                                  := pgpTxMaster.tData(PACKETIZER2_TAIL_EOF_BIT_C);
               v.frameTxErr                               := v.frameTx and ssiGetUserEofe(PGP3_AXIS_CONFIG_C, pgpTxMaster);
               -- Reset the metadata
               resetEventMetaData                         := true;
            else
               -- Normal data
               v.protTxData(63 downto 0) := pgpTxMaster.tData(63 downto 0);
               v.protTxHeader            := PGP3_D_HEADER_C;
            end if;
         end if;

         --------------------------------------------------------------------
         --                   Commands and Metadata                        --
         --------------------------------------------------------------------

         -- USER codes override data and delay SKP if they happen to coincide
         if (pgpTxIn.opCodeEn = '1' and dataEn = '1') then
            -- Override any data acceptance.
            v.pgpTxSlave.tReady := '0';
            -- Accept the op-code
            v.opCodeReady       := '1';

            -- Update the TX data bus
            v.protTxData(PGP3_BTF_FIELD_C)           := PGP3_USER_C(conv_integer(pgpTxIn.opCodeNumber));
            v.protTxData(PGP3_USER_CHECKSUM_FIELD_C) := pgp3OpCodeChecksum(pgpTxIn.opCodeData);
            v.protTxData(PGP3_USER_OPCODE_FIELD_C)   := pgpTxIn.opCodeData;
            v.protTxHeader                           := PGP3_K_HEADER_C;

            resetEventMetaData := false;
         -- SKIP codes override data
         elsif (r.skpCount = r.skpInterval) then
            v.skpCount                           := (others => '0');
            v.pgpTxSlave.tReady                  := '0';            -- Override any data acceptance.
            v.protTxData(PGP3_SKIP_DATA_FIELD_C) := pgpTxIn.locData;
            v.protTxData(PGP3_BTF_FIELD_C)       := PGP3_SKP_C;
            v.protTxHeader                       := PGP3_K_HEADER_C;
            resetEventMetaData                   := false;
         else
            -- A local rx pause going high causes an IDLE char to be sent mid frame
            -- So that the sending end is notified with minimum latency
            for i in NUM_VC_G-1 downto 0 loop
               if (r.pauseEvent(i) = '1') and (r.pauseEventSent(i) = '0') then
                  v.pauseEventSent(i)                 := '1';
                  v.pgpTxSlave.tReady                 := '0';
                  v.protTxData(PGP3_BTF_FIELD_C)      := PGP3_IDLE_C;
                  v.protTxData(PGP3_LINKINFO_FIELD_C) := linkInfo;
                  v.protTxHeader                      := PGP3_K_HEADER_C;
               end if;
               if (r.overflowEvent(i) = '1') and (r.overflowEventSent(i) = '0') then
                  v.overflowEventSent(i)              := '1';
                  v.pgpTxSlave.tReady                 := '0';
                  v.protTxData(PGP3_BTF_FIELD_C)      := PGP3_IDLE_C;
                  v.protTxData(PGP3_LINKINFO_FIELD_C) := linkInfo;
                  v.protTxHeader                      := PGP3_K_HEADER_C;
               end if;
            end loop;
         end if;

         -- Check if TX is disabled
         if (pgpTxIn.disable = '1') then
            v.linkReady      := '0';
            v.protTxStart    := '0';
            v.startupCount   := 0;
            v.protTxData     := (others => '0');
            v.protTxHeader   := (others => '0');
         end if;

      end if;

      -- Check if link down
      if (phyTxActive = '0') then
         v.linkReady      := '0';
         v.protTxStart    := '0';
         v.startupCount   := 0;
      end if;

      -- Check if need to reset event meta data
      if (resetEventMetaData) then
         v.pauseEvent        := (others => '0');
         v.pauseEventSent    := (others => '0');
         v.overflowEvent     := (others => '0');
         v.overflowEventSent := (others => '0');
      end if;

      -- Outputs
      pgpTxSlave <= v.pgpTxSlave;

      protTxData     <= r.protTxData;
      protTxHeader   <= r.protTxHeader;
      protTxValid    <= r.protTxValid;
      protTxStart    <= r.protTxStart;

      pgpTxOut.phyTxActive <= phyTxActive;
      pgpTxOut.linkReady   <= r.linkReady;
      pgpTxOut.frameTx     <= r.frameTx;
      pgpTxOut.frameTxErr  <= r.frameTxErr;
      pgpTxOut.opCodeReady <= v.opCodeReady;

      for i in 15 downto 0 loop
         if (i < NUM_VC_G) then
            pgpTxOut.locOverflow(i) <= locRxFifoCtrl(i).overflow;
            pgpTxOut.locPause(i)    <= locRxFifoCtrl(i).pause;
         else
            pgpTxOut.locOverflow(i) <= '0';
            pgpTxOut.locPause(i)    <= '0';
         end if;
      end loop;

      -- Reset
      if (pgpTxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (pgpTxClk) is
   begin
      if (rising_edge(pgpTxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
