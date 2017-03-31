-------------------------------------------------------------------------------
-- Title      : Pgp3 Transmit
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

entity Pgp3Tx is

   generic (
      TPD_G : time := 1 ns);

   port (
      -- Transmit interface
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpTxIn      : in  Pgp3TxInType;
      pgpTxOut     : out Pgp3TxOutType;
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      pgpTxCtrl    : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      -- Status of receive and remote FIFOs (Asynchronous)
      locRxFifoStatus : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxFifoStatus : in AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

      phyTxClk : in sl;
      phyTxReady : in sl;
      phyTxData : out slv(63 downto 0);
      phyTxHeader : out sl(1 downto 0);


      );




end entity Pgp3Tx;
