-------------------------------------------------------------------------------
-- Title      : PGP3 Support Package
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package Pgp3Pkg is

   constant PGP3_AXIS_CONFIG_C : AxiStreamConfigType := ();

   -- Define K code BTFs
   constant IDLE_C : slv(7 downto 0)   := X"99";
   constant SOF_C  : slv(7 downto 0)   := X"AA";
   constant EOF_C  : slv(7 downto 0)   := X"55";
   constant SOC_C  : slv(7 downto 0)   := X"CC";
   constant EOC_C  : slv(7 downto 0)   := X"33";
   constant SKP_C  : slv(7 downto 0)   := X"66";
   constant USER_C : Slv8Array(0 to 7) := (X"78", X"87", X"2D", X"D2", X"1E", X"E1", X"B4", X"4B");

   constant D_HEADER_C : slv(1 downto 0) := "01";
   constant K_HEADER_C : slv(1 downto 0) := "10";

   type Pgp3TxInType is record
      opCodeEn     : sl;
      opCodeNumber : slv(2 downto 0);
      opCodeData   : slv(55 downto 0);
   end record Pgp3TxInType;

   type Pgp3TxOutType is record
      locOverflow : slv(15 downto 0);   -
      locPause : slv(15 downto 0);
      phyTxReady : sl;
      linkReady : sl;
      frameTx : sl;                     -- A good frame was transmitted
      frameTxErr : sl;                  -- An errored frame was transmitted
   end record Pgp3TxOutType;


end package Pgp3Pkg;
