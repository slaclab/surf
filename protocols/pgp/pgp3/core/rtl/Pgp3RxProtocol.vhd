-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Receive Protocol
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

entity Pgp3RxProtocol is

   generic (
      TPD_G    : time                  := 1 ns;
      NUM_VC_G : integer range 1 to 16 := 4);
   port (
      -- User Transmit interface
      pgpRxClk    : in  sl;
      pgpRxRst    : in  sl;
      pgpRxIn     : in  Pgp3RxInType := PGP3_RX_IN_INIT_C;
      pgpRxOut    : out Pgp3RxOutType;
      pgpRxMaster : out AxiStreamMasterType;
      pgpRxSlave  : in  AxiStreamSlaveType;

      -- Status of local receive fifos
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;

      -- Received data from descramber/CC FIFO
      phyRxActive   : in  sl;
      protRxValid   : in  sl;
      protRxPhyInit : out sl;
      protRxData    : in  slv(63 downto 0);
      protRxHeader  : in  slv(1 downto 0));

end entity Pgp3RxProtocol;

architecture rtl of Pgp3RxProtocol is

   type RegType is record
      notValidCnt    : slv(31 downto 0);
      count          : slv(15 downto 0);
      pgpRxMaster    : AxiStreamMasterType;
      pgpRxOut       : Pgp3RxOutType;
      protRxPhyInit  : sl;
      remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : sl;
      locRxLinkReady : sl;              -- This might come from aligner instead?
      version        : slv(2 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      notValidCnt    => (others => '0'),
      count          => (others => '0'),
      pgpRxMaster    => axiStreamMasterInit(PGP3_AXIS_CONFIG_C),
      pgpRxOut       => PGP3_RX_OUT_INIT_C,
      protRxPhyInit  => '1',
      remRxFifoCtrl  => (others => AXI_STREAM_CTRL_INIT_C),  -- init paused
      remRxLinkReady => '0',
      locRxLinkReady => '0',
      version        => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal phyRxActiveSyncFall : sl;
   signal phyRxActiveSync     : sl;

begin

   U_SynchronizerEdge_1 : entity surf.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => pgpRxClk,              -- [in]
         rst         => pgpRxRst,              -- [in]
         dataIn      => phyRxActive,           -- [in]
         dataOut     => phyRxActiveSync,       -- [out]
         fallingEdge => phyRxActiveSyncFall);  -- [out]

   comb : process (pgpRxIn, pgpRxRst, phyRxActiveSync, phyRxActiveSyncFall, protRxData,
                   protRxHeader, protRxValid, r) is
      variable v              : RegType;
      variable linkInfo       : slv(39 downto 0);
      variable btf            : slv(7 downto 0);
      variable opCodeChecksum : slv(7 downto 0);
   begin
      v := r;

      btf := protRxData(PGP3_BTF_FIELD_C);

      v.pgpRxMaster        := REG_INIT_C.pgpRxMaster;
      v.pgpRxOut.opCodeEn  := '0';
      v.pgpRxOut.linkDown  := '0';
      v.pgpRxOut.linkError := '0';
      v.protRxPhyInit      := '0';

      opCodeChecksum := pgp3OpCodeChecksum(protRxData(47 downto 0));

      -- Just translate straight to AXI-Stream packetizer2 format
      -- and let the depacketizer handle any errors?
      if (protRxValid = '1') then
         if (r.pgpRxOut.linkReady = '0') then
            -- Unlinked
            -- Need N valid headers in a row. Data is ignored.
            v.count := (others => '0');
            if (protRxHeader = PGP3_K_HEADER_C) then
               for i in PGP3_VALID_BTF_ARRAY_C'range loop
                  if (btf = PGP3_VALID_BTF_ARRAY_C(i)) then
                     -- Valid header, increment count
                     v.count := r.count + 1;
                  end if;
               end loop;
            elsif (protRxHeader = PGP3_D_HEADER_C) then
               -- Ignore data
               v.count := r.count;
            end if;

         else
            -- Linked
            -- Increment count on every incomming word
            -- reset when IDLE or SOF or SOC seen
            v.count := r.count + 1;

            if (protRxHeader = PGP3_K_HEADER_C) then
               if (btf = PGP3_IDLE_C) then
                  pgp3ExtractLinkInfo(
                     protRxData(PGP3_LINKINFO_FIELD_C),
                     v.remRxFifoCtrl,
                     v.remRxLinkReady,
                     v.version);
                  if (v.version = PGP3_VERSION_C) then
                     v.count := (others => '0');
                  end if;
               elsif (btf = PGP3_SOF_C or btf = PGP3_SOC_C) then
                  v.pgpRxMaster :=
                     makePacketizer2Header(
                        CRC_MODE_C => "DATA",
                        valid      => r.pgpRxOut.linkReady,  -- Hold Everything until linkready
                        sof        => ite(btf = PGP3_SOF_C, '1', '0'),
                        tdest      => resize(protRxData(PGP3_SOFC_VC_FIELD_C), 8),
                        seq        => resize(protRxData(PGP3_SOFC_SEQ_FIELD_C), 16));
                  pgp3ExtractLinkInfo(
                     protRxData(PGP3_LINKINFO_FIELD_C),
                     v.remRxFifoCtrl,
                     v.pgpRxOut.remRxLinkReady,
                     v.version);
                  if (v.version = PGP3_VERSION_C) then
                     v.count := (others => '0');
                  end if;
               elsif (btf = PGP3_EOF_C or btf = PGP3_EOC_C) then
                  v.pgpRxMaster :=
                     makePacketizer2Tail(
                        CRC_MODE_C => "DATA",
                        valid      => r.pgpRxOut.linkReady,
                        eof        => toSl(btf = PGP3_EOF_C),
                        tuser      => protRxData(PGP3_EOFC_TUSER_FIELD_C),
                        bytes      => protRxData(PGP3_EOFC_BYTES_LAST_FIELD_C),
                        crc        => protRxData(PGP3_EOFC_CRC_FIELD_C));
               else
                  for i in PGP3_USER_C'range loop
                     if (btf = PGP3_USER_C(i)) then
                        v.pgpRxOut.opCodeNumber := toSlv(i, 3);
                        v.pgpRxOut.opCodeData   := protRxData(PGP3_USER_OPCODE_FIELD_C);
                        -- Verify checksun
                        if (protRxData(PGP3_USER_CHECKSUM_FIELD_C) = opCodeChecksum) then
                           v.pgpRxOut.opCodeEn := '1';
                        else
                           v.pgpRxOut.linkError := '1';
                        end if;
                     end if;
                  end loop;
               end if;
            -- Unknown opcodes silently dropped
            elsif (protRxHeader = PGP3_D_HEADER_C) then
               -- Normal Data
               v.pgpRxMaster.tValid             := r.pgpRxOut.linkReady;
               v.pgpRxMaster.tData(63 downto 0) := protRxData;
            else
               v.pgpRxOut.linkError := '1';
            end if;
         end if;
      end if;

      v.notValidCnt := (others => '0');
      if (protRxValid = '0' and phyRxActiveSync = '1') then
         v.notValidCnt := r.notValidCnt + 1;
      end if;

      -- Count reaching max indicates that link state needs to toggle
      -- When not linked, r.count counts consecutive valid k-chars
      -- When linked, r.count counts consecutive chars without a valid k-char
      if (r.count = 1000) then
         v.pgpRxOut.linkReady := not r.pgpRxOut.linkReady;
         v.count              := (others => '0');
      end if;

      if (phyRxActiveSyncFall = '1') then
         v.pgpRxOut.linkReady := '0';
      end if;

      -- Reset phy if active but no valid data for 100 cycles
      -- Indicates aligner unable to get lock
      if (r.notValidCnt = 10000) then
         v.pgpRxOut.linkReady := '0';
         v.protRxPhyInit      := '1';
      end if;

      if (pgpRxIn.resetRx = '1') then
         v.pgpRxOut.linkReady := '0';
         v.protRxPhyInit      := '1';   -- Always init the phy on resetRx
      end if;

      if (r.pgpRxOut.linkReady = '1' and v.pgpRxOut.linkReady = '0') then
         v.pgpRxOut.linkDown := '1';
         v.protRxPhyInit     := '1';
         v.count             := (others => '0');
      end if;

      if (v.pgpRxOut.linkReady = '0') then
         v.remRxLinkReady := '0';
      end if;


      if (pgpRxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      pgpRxOut       <= r.pgpRxOut;
      protRxPhyInit  <= r.protRxPhyInit;
      pgpRxMaster    <= r.pgpRxMaster;
      remRxFifoCtrl  <= r.remRxFifoCtrl;
      remRxLinkReady <= r.remRxLinkReady;
      locRxLinkReady <= r.pgpRxOut.linkReady;

   end process comb;

   seq : process (pgpRxClk) is
   begin
      if (rising_edge(pgpRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end architecture rtl;
