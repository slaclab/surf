-------------------------------------------------------------------------------
-- Title         : SSI Lib, Simulation Link, PGP Like Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : PgpSim.vhd
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity PgpSim is 
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

      -- Tx Interface, 16-bits
      pgpTxMasters      : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves       : out AxiStreamSlaveArray(3 downto 0);

      -- System clock, reset & control
      pgpRxClk          : in  sl;
      pgpRxClkRst       : in  sl;

      -- Non-VC related IO
      pgpRxIn           : in  PgpRxInType;
      pgpRxOut          : out PgpRxOutType;

      -- Rx Interface, 16-bits, muxed and de-muxed copies
      pgpRxMasters      : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed  : out AxiStreamMasterType;

      -- AXI buffer status
      axiFifoStatus     : in  AxiStreamCtrlArray(3 downto 0)
   );

end PgpSim;


-- Define architecture
architecture PgpSim of PgpSim is

   signal intTxMaster : AxiStreamMasterType;
   signal intTxSlave  : AxiStreamSlaveType;
   signal intRxMaster : AxiStreamMasterType;
   signal tmpRxMaster : AxiStreamMasterType;
   signal intRxSlave  : AxiStreamSlaveType;

begin

   -- Fake transmit control signals
   pgpTxOut.linkReady <= '1';

   -- Transmit MUX
   U_TxMux : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 4
      ) port map (
         axiClk            => pgpTxClk,
         axiRst            => pgpTxClkRst,
         sAxiStreamMasters => pgpTxMasters,
         sAxiStreamSlaves  => pgpTxSlaves,
         mAxiStreamMaster  => intTxMaster,
         mAxiStreamSlave   => intTxSlave
      );

   -- Simulation link
   U_Sim : entity work.AxiStreamSim
      generic map (
         TPD_G            => TPD_G,
         TDATA_BYTES_G    => 2,
         EOFE_TUSER_BIT_G => SSI_EOFE_C
      ) port map ( 
         sAxiClk           => pgpTxClk,
         sAxiRst           => pgpTxClkRst,
         sAxiStreamMaster  => intTxMaster,
         sAxiStreamSlave   => intTxSlave,
         mAxiClk           => pgpRxClk,
         mAxiRst           => pgpRxClkRst,
         mAxiStreamMaster  => tmpRxMaster,
         mAxiStreamSlave   => intRxSlave
      );

   -- override valid and ready when paused
   process ( axiFifoStatus, intRxMaster ) is
      variable ready : sl;
   begin

      ready := '1';

      for i in 0 to 3 loop
         if axiFifoStatus(i).pause = '1' then
            ready := '0';
         end if;
      end loop;

      intRxSlave.tReady  <= ready;
      intRxMaster        <= tmpRxMaster;
      intRxMaster.tValid <= tmpRxMaster.tValid and ready;

   end process;

   -- Muxed output
   pgpRxMasterMuxed  <= intRxMaster;

   -- Receive De-MUX
   U_RxDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4
      ) port map (
         axiClk            => pgpRxClk,
         axiRst            => pgpRxClkRst,
         sAxiStreamMaster  => intRxMaster,
         sAxiStreamSlave   => intRxSlave,
         mAxiStreamMasters => pgpRxMasters,
         mAxiStreamSlaves  => (others=>AXI_STREAM_SLAVE_FORCE_C)
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
   pgpRxOut.remOverFlow  <= (others=>'0');

end PgpSim;

