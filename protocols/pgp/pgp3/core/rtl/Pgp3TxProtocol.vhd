-------------------------------------------------------------------------------
-- Title      : PGP3 Transmit Protocol
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

entity Pgp3TxProtocol is

   generic (
      TPD_G            : time                  := 1 ns;
      NUM_VC_G         : integer range 1 to 16 := 4;
      SKP_INTERVAL_G   : integer               := 5000;
      SKP_BURST_SIZE_G : integer               := 8);

   port (
      -- User Transmit interface
      pgpTxClk    : in  sl;
      pgpTxRst    : in  sl;
      pgpTxIn     : in  Pgp3TxInType;
      pgpTxOut    : out Pgp3TxOutType;
      pgpTxMaster : in  AxiStreamMasterType;
      pgpTxSlave  : out AxiStreamSlaveType;

      -- Status of local receive fifos
      locRxFifoCtrl : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      locRxLinkReady  : in sl;

      -- Output data (to scrambler)
      phyTxData   : out slv(63 downto 0);
      phyTxHeader : out slv(1 downto 0));

end entity Pgp3TxProtocol;

architecture rtl of Pgp3TxProtocol is

   type RegType is record
      skpCount    : slv(15 downto 0);
      pgpTxSlave  : AxiStreamSlaveType;
      phyTxData   : slv(63 downto 0);
      phyTxHeader : slv(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      skpCount    => (others => '0'),
      pgpTxSlave  => AXI_STREAM_SLAVE_INIT_C,
      phyTxData   => (others => '0'),
      phyTxHeader => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (locRxFifoCtrl, locRxLinkReady, pgpTxIn, pgpTxMaster, pgpTxRst, r) is
      variable v        : RegType;
      variable linkInfo : slv(39 downto 0);
   begin
      v := r;

      linkInfo := makeLinkInfo(locRxFifoCtrl, locRxLinkReady);

      -- Always increment skpCount
      v.skpCount := r.skpCount + 1;

      -- Don't accept new frame data by default
      v.pgpTxSlave.tReady := '0';

      -- Decide whether to send IDLE, SKP, USER or data frames.
      -- Coded in reverse order of priority

      -- Send idle chars by default
      -- Need to be able to only send this for some generic number of cycles after reset
      v.phyTxData(39 downto 0)  := linkInfo;
      v.phyTxData(55 downto 40) := (others => '0');
      v.phyTxData(63 downto 56) := IDLE_C;
      v.phyTxHeader             := K_HEADER_C;

      -- Send data if there is data to send
      if (pgpTxMaster.tValid = '1') then
         v.pgpTxSlave.tReady := '1';    -- Accept the data

         if (ssiGetUserSof(PGP3_AXIS_CONFIG_C, pgpTxMaster) = '1') then
            -- SOF/SOC, format SOF/SOC char from data
            v.phyTxData               := (others => '0');
            v.phyTxData(63 downto 56) := ite(pgpTxMaster.tData(32) = '1', SOC_C, SOF_C);
            v.phyTxData(39 downto 0)  := linkInfo;
            v.phyTxData(43 downto 40) := pgpTxMaster.tData(11 downto 8);  -- Virtual Channel
            v.phyTxData(55 downto 44) := pgpTxMaster.tData(43 downto 32);   -- Packet number
            v.phyTxHeader             := K_HEADER_C;

         elsif (pgpTxMaster.tLast = '1') then
            -- EOF/EOC
            v.phyTxData               := (others => '0');
            v.phyTxData(63 downto 56) := ite(pgpTxMaster.tData(8) = '1', EOF_C, EOC_C);
            v.phyTxData(7 downto 0)   := pgpTxMaster.tData(7 downto 0);    -- TUSER LAST
            v.phyTxData(18 downto 16) := pgpTxMaster.tData(18 downto 16);  -- Last byte count
            v.phyTxData(56 downto 24) := pgpTxMaster.tData(63 downto 32);  -- CRC
            v.phyTxHeader             := K_HEADER_C;

         else
            -- Normal data
            v.phyTxData(63 downto 0) := pgpTxMaster.tData(63 downto 0);
            v.phyTxHeader            := D_HEADER_C;
         end if;
      end if;

      -- 
      if (r.skpCount = SKP_INTERVAL_G-1) then
         v.skpCount               := (others => '0');
         v.pgpTxSlave.tReady      := '0';  -- Override any data acceptance.
         v.phyTxData              := (others => '0');
         v.phyTxData(63 downto 56) := SKP_C;
         v.phyTxHeader            := K_HEADER_C;
      end if;


      -- USER codes override data
      if (pgpTxIn.opCodeEn = '1') then
         v.pgpTxSlave.tReady       := '0';  -- Override any data acceptance.
         v.phyTxData(63 downto 56) := USER_C(conv_integer(pgpTxIn.opCodeNumber));
         v.phyTxData(55 downto 0)  := pgpTxIn.opCodeData;
         -- If skip was interrupted, hold it for next cycle
         if (r.skpCount = SKP_INTERVAL_G-1) then
            v.skpCount := r.skpCount;
         end if;
      end if;

      if (pgpTxRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      pgpTxSlave  <= v.pgpTxSlave;
      phyTxData   <= r.phyTxData;
      phyTxHeader <= r.phyTxHeader;

   end process comb;

   seq : process (pgpTxClk) is
   begin
      if (rising_edge(pgpTxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end architecture rtl;
