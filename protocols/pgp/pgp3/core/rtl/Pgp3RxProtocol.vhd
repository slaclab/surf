-------------------------------------------------------------------------------
-- Title      : PGP3 Receive Protocol
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Takes pre-packetized AxiStream frames and creates a PGP3 66/64 protocol
-- stream (pre-scrambler). Inserts IDLE and SKP codes as needed. Inserts
-- user K codes on request.
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp3Pkg.all;

entity Pgp3RxProtocol is

   generic (
      TPD_G    : time                  := 1 ns;
      NUM_VC_G : integer range 1 to 16 := 4);
   port (
      -- User Transmit interface
      pgpRxClk    : in  sl;
      pgpRxRst    : in  sl;
      pgpRxIn     : in  Pgp3RxInType;
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

   U_SynchronizerEdge_1 : entity work.SynchronizerEdge
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

      btf := protRxData(63 downto 56);

      v.pgpRxMaster        := REG_INIT_C.pgpRxMaster;
      v.pgpRxOut.opCodeEn  := '0';
      v.pgpRxOut.linkDown  := '0';
      v.pgpRxOut.linkError := '0';
      v.protRxPhyInit      := '0';

      opCodeChecksum := not (protRxData(7 downto 0) +
                             protRxData(15 downto 8) +
                             protRxData(23 downto 16) +
                             protRxData(31 downto 24) +
                             protRxData(39 downto 32) +                             
                             protRxData(47 downto 40));


      -- Just translate straight to AXI-Stream packetizer2 format
      -- and let the depacketizer handle any errors?
      if (protRxValid = '1') then
         if (r.pgpRxOut.linkReady = '0') then
            -- Unlinked
            -- Need N valid headers in a row. Data is ignored.
            v.count := (others => '0');
            if (protRxHeader = K_HEADER_C) then
               for i in VALID_BTF_ARRAY_C'range loop
                  if (btf = VALID_BTF_ARRAY_C(i)) then
                     -- Valid header, increment count
                     v.count := r.count + 1;
                  end if;
               end loop;
            elsif (protRxHeader = D_HEADER_C) then
               -- Ignore data
               v.count := r.count;
            end if;

         else
            -- Linked

            -- Increment count on every incomming word
            -- reset when IDLE or SOF or SOC seen
            v.count := r.count + 1;

            if (protRxHeader = K_HEADER_C) then
               if (btf = IDLE_C) then
                  extractLinkInfo(
                     protRxData(39 downto 0),
                     v.remRxFifoCtrl,
                     v.remRxLinkReady,
                     v.version);
                  if (v.version = PGP3_VERSION_C) then
                     v.count := (others => '0');
                  end if;
               elsif (btf = SOF_C or btf = SOC_C) then
                  v.pgpRxMaster.tValid              := r.pgpRxOut.linkReady;  -- Hold Everything until
                  v.pgpRxMaster.tData               := (others => '0');
                  v.pgpRxMaster.tData(24)           := ite(btf = SOF_C, '1', '0');  -- packetizer SOC bit
                  v.pgpRxMaster.tData(11 downto 8)  := protRxData(43 downto 40);  -- VC
                  v.pgpRxMaster.tData(43 downto 32) := protRxData(55 downto 44);  -- packet number
                  axiStreamSetUserBit(PGP3_AXIS_CONFIG_C, v.pgpRxMaster, SSI_SOF_C, '1', 0);  -- Set SOF
                  extractLinkInfo(
                     protRxData(39 downto 0),
                     v.remRxFifoCtrl,
                     v.pgpRxOut.remRxLinkReady,
                     v.version);
                  if (v.version = PGP3_VERSION_C) then
                     v.count := (others => '0');
                  end if;
               elsif (btf = EOF_C or btf = EOC_C) then
                  v.pgpRxMaster.tValid              := r.pgpRxOut.linkReady;
                  v.pgpRxMaster.tLast               := '1';
                  v.pgpRxMaster.tData               := (others => '0');
                  v.pgpRxMaster.tData(8)            := toSl(btf = EOF_C);     -- EOF bit
                  v.pgpRxMaster.tData(7 downto 0)   := protRxData(7 downto 0);    -- TUSER LAST
                  v.pgpRxMaster.tData(19 downto 16) := protRxData(19 downto 16);  -- Last byte count
                  v.pgpRxMaster.tData(63 downto 32) := protRxData(55 downto 24);  -- CRC
               else
                  for i in USER_C'range loop
                     if (btf = USER_C(i)) then
                        v.pgpRxOut.opCodeNumber := toSlv(i, 3);
                        v.pgpRxOut.opCodeData   := protRxData(47 downto 0);
                        -- Verify checksun
                        if (protRxData(55 downto 48) = opCodeChecksum) then
                           v.pgpRxOut.opCodeEn := '1';                           
                        end if;
                     end if;
                  end loop;
               end if;
            -- Unknown opcodes silently dropped
            elsif (protRxHeader = D_HEADER_C) then
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
