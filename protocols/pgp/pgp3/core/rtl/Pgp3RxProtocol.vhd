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
      phyRxValid  : in sl;
      phyRxData   : in slv(63 downto 0);
      phyRxHeader : in slv(1 downto 0));

end entity Pgp3RxProtocol;

architecture rtl of Pgp3RxProtocol is

   type RegType is record
      pgpRxMaster    : AxiStreamMasterType;
      pgpRxOut : Pgp3RxOutType;
      remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : sl;
      locRxLinkReady : sl;              -- This might come from aligner instead?
   end record RegType;

   constant REG_INIT_C : RegType := (
      pgpRxMaster    => axiStreamMasterInit(PGP3_AXIS_CONFIG_C),
      remRxFifoCtrl  => AXI_STREAM_CTRL_INIT_C,  -- maybe init paused?
      remRxLinkReady => '0',
      locRxLinkReady => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (pgpRxRst, phyRxData, phyRxHeader, phyRxValid, r) is
      variable v        : RegType;
      variable linkInfo : slv(39 downto 0);
      variable btf      : slv(7 downto 0);
   begin
      v := r;

      btf := phyRxData(63 downto 56);

      v.pgpRxMaster.tValid := '0';
      v.pgpRxOut.opCodeEn  := '0';

      -- Just translate straight to AXI-Stream packetizer2 format
      -- and let the depacketizer handle any errors?
      if (phyRxValid = '1') then
         if (phyRxHeader = K_HEADER_C) then
            if (btf = IDLE_C) then
               extractLinkInfo(
                  phyRxData(39 downto 0),
                  v.remRxFifoCtrl,
                  v.remRxLinkReady,
                  v.version);
            elsif (btf = SOF_C or btf = SOC_C) then
               v.pgpRxMaster.tValid              := '1';
               v.pgpRxMaster.tData               := (others => '0');
               v.pgpRxMaster.tData(32)           := ite(btf = SOF_C, '0', '1');  -- packetizer SOC bit
               v.pgpRxMaster.tData(11 downto 8)  := phyRxData(43 downto 40);     -- VC
               v.pgpRxMaster.tData(43 downto 32) := phyRxData(55 downto 44);     -- packet number
               axiStreamSetUserBit(PGP3_AXIS_CONFIG_C, v.pgpRxMaster, SSI_SOF_C, '1', 0);  -- Set SOF
               extractLinkInfo(
                  phyRxData(39 downto 0),
                  v.remRxFifoCtrl,
                  v.remRxLinkReady,
                  v.version);
            elsif (btf = EOF_C or btf = EOC_C) then
               v.pgpRxMaster.tValid              := '1';
               v.pgpRxMaster.tData               := (others => '0');
               v.pgpRxMaster.tData(7 downto 0)   := phyRxData(7 downto 0);       -- TUSER LAST
               v.pgpRxMaster.tData(18 downto 16) := phyRxData(18 downto 16);     -- Last byte count
               v.pgpRxMaster.tData(63 downto 32) := phyRxData(56 downto 23);     -- CRC
            else
               for i in USER_C'range loop
                  if (btf = USER_C(i)) then
                     v.pgpRxOut.opCodeEn     := '1';
                     v.pgpRxOut.opCodeNumber := toSlv(i, 3);
                     v.pgpRxOut.opCodeData   := phyRxData(55 downto 0);
                  end if;
               end loop;
            end if;
         -- Unknown opcodes silently dropped
         elsif (phyRxHeader = D_HEADER_C) then
            -- Normal Data
            v.pgpRxMaster.tValid             := '1';
            v.pgpRxMaster.tData(63 downto 0) := phyRxData;
         end if;
      end if;

      if (pgpRxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      pgpRxMaster    <= r.pgpRxMaster;
      remRxFifoCtrl  <= r.remRxFifoCtrl;
      remRxLinkReady <= r.remRxLinkReady;
      locRxLinkReady <= r.locRxLinkReady;

   end process comb;

   seq : process (pgpRxClk) is
   begin
      if (rising_edge(pgpRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end architecture rtl;
