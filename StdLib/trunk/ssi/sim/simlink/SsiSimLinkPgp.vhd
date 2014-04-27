-------------------------------------------------------------------------------
-- Title         : SSI Lib, Simulation Link, PGP Like Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : SsiSimLinkPgp.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/18/2014
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/18/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.SsiPkg.all;

entity SsiSimLinkPgp is 
   generic (
      TPD_G  : time := 1 ns
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  sl;
      pgpTxClkRst       : in  sl;

      -- Non-VC related IO
      pgpTxIn           : in  PgpTxInType;
      pgpTxOut          : out PgpTxOutType;

      -- Tx Interface
      pgpTxMasters      : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves       : out AxiStreamSlaveArray(3 downto 0);

      -- System clock, reset & control
      pgpRxClk          : in  sl;
      pgpRxClkRst       : in  sl;

      -- Non-VC related IO
      pgpRxIn           : in  PgpRxInType;
      pgpRxOut          : out PgpRxOutType;

      -- Rx Interface
      pgpRxMasters      : out AxiStreamSlaveArray(3 downto 0);
      pgpRxSlaves       : in  AxiStreamMasterArray(3 downto 0)
   );

end SsiSimLinkPgp;


-- Define architecture
architecture SsiSimLinkPgp of SsiSimLinkPgp is

   signal intTxMaster : AxiStreamMasterType;
   signal intTxSlave  : AxiStreamSlaveType;
   signal intRxMaster : AxiStreamMasterType;
   signal intRxSlave  : AxiStreamSlaveType;

begin

   -- Fake transmit control signals
   pgpTxOut.linkReady <= '1';

   -- Transmit MUX
   U_TxMux : entity work.SsiFrameMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 4
      ) port map (
         axiClk              => pgpTxClk,
         axiRst              => pgpTxClkRst,
         slvAxiStreamMasters => pgpTxMasters,
         slvAxiStreamSlaves  => pgpTxSlaves,
         mstAxiStreamMaster  => intTxMaster,
         mstAxiStreamSlave   => intTxSlave
      );

   -- Simulation link
   U_SsiSimLink : entity work.SsiSimLink
      generic map (
         TPD_G => TPD_G
      ) port map ( 
         ibAxiClk           => pgpTxClk,
         ibAxiRst           => pgpTxClkRst,
         ibAxiStreamMaster  => intTxMaster,
         ibAxiStreamSlave   => intTxSlave,
         obAxiClk           => pgpRxClk,
         obAxiRst           => pgpRxClkRst,
         obAxiStreamMaster  => intRxMaster,
         obAxiStreamSlave   => intRxSlave
      );

   -- Receive De-MUX
   U_RxDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4
      ) port map (
         axiClk              => pgpRxClk,
         axiRst              => pgpRxClkRst,
         slvAxiStreamMaster  => intRxMaster,
         slvAxiStreamSlave   => intRxSlave,
         mstAxiStreamMasters => pgpRxMasters,
         mstAxiStreamSlaves  => pgpRxSlaves
      );

   -- Fake receive control signals
   pgpRxOut.linkReady    <= '1';
   pgpRxOut.cellError    <= '0';
   pgpRxOut.linkDown     <= '0';
   pgpRxOut.linkError    <= '0';
   pgpRxOut.opCodeEn     <= '0';
   pgpRxOut.opCode       <= (others=>'0');
   pgpRxOut.remLinkReady <= '1';
   pgpRxOut.remLinkData  <= (others=>'0');

end SsiSimLinkPgp;

