-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Pgp4TxLite (targeted/optimized for ASIC integration)
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4TxLiteWrapper is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      -- Clock and Reset
      clk        : in  sl;
      rst        : in  sl;                 -- Active HIGH reset
      -- 64-bit Input Framing Interface
      txValid    : in  sl;                 -- tValid
      txReady    : out sl;                 -- tReady
      txData     : in  slv(63 downto 0);   -- tData
      txSof      : in  sl;                 -- tUser.FirstByte.BIT1
      txEof      : in  sl;                 -- tLast
      txEofe     : in  sl;                 -- tUser.LastByte.BIT0
      -- 66-bit Output Interface
      phyTxValid : out sl;                 -- tValid
      phyTxReady : in  sl;                 -- tReady
      phyTxData  : out slv(65 downto 0));  -- 2-bit header packed on MSB
end entity Pgp4TxLiteWrapper;

architecture mapping of Pgp4TxLiteWrapper is

   signal pgpTxIn : Pgp4TxInType := (
      disable     => '0',               -- TX is enabled
      flowCntlDis => '1',  -- Disable PGPv4 pause flow control from RX side
      resetTx     => '0',               -- Not resetting TX
      skpInterval => (others => '0'),  -- No skips (assumes clock source synchronous system)
      opCodeEn    => '0',               -- OP-code mode not being implemented
      opCodeData  => (others => '0'),
      locData     => (others => '0'));  -- sideband locData not being implemented

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType;
   signal rstL        : sl;

begin

   txReady                        <= pgpTxSlave.tReady;
   pgpTxMaster.tValid             <= txValid;
   pgpTxMaster.tData(63 downto 0) <= txData;
   pgpTxMaster.tKeep(7 downto 0)  <= X"FF";  -- Assumes always 64-bit tData per clock cycle
   pgpTxMaster.tUser(1)           <= txSof;
   pgpTxMaster.tUser(14)          <= txEofe;
   pgpTxMaster.tLast              <= txEof;

   U_Pgp4TxLite : entity surf.Pgp4TxLite
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         NUM_VC_G       => 1,           -- Only 1 VC per PGPv4 link
         SKIP_EN_G      => false,  -- No skips (assumes clock source synchronous system)
         FLOW_CTRL_EN_G => false)  -- no pause flow control from PGPv4.RX side
      port map (
         -- Transmit interface
         pgpTxClk        => clk,
         pgpTxRst        => rst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => open,
         pgpTxActive     => '1',
         pgpTxMasters(0) => pgpTxMaster,
         pgpTxSlaves(0)  => pgpTxSlave,
         -- Status of receive and remote FIFOs (Asynchronous)
         locRxFifoCtrl(0)=> AXI_STREAM_CTRL_UNUSED_C,
         locRxLinkReady  => '1',
         remRxFifoCtrl(0)=> AXI_STREAM_CTRL_UNUSED_C,
         remRxLinkReady  => '1',
         -- PHY interface
         phyTxActive     => rstL,
         phyTxReady      => phyTxReady,
         phyTxValid      => phyTxValid,
         phyTxStart      => open,
         phyTxData       => phyTxData(63 downto 0),
         phyTxHeader     => phyTxData(65 downto 64));

   rstL <= not(rst);

end architecture mapping;
