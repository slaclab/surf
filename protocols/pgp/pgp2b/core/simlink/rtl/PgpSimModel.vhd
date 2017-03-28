-------------------------------------------------------------------------------
-- File       : Pgp2bLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for PGP
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity PgpSimModel is 
   generic (
      TPD_G       : time := 1 ns;
      LANE_CNT_G  : integer range 1 to 2 := 1   -- Number of lanes, 1-2
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  sl;
      pgpTxClkRst       : in  sl;

      -- Non-VC related IO
      pgpTxIn           : in  Pgp2bTxInType;
      pgpTxOut          : out Pgp2bTxOutType;

      -- Tx Interface, 16-bits
      pgpTxMasters      : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves       : out AxiStreamSlaveArray(3 downto 0);

      -- System clock, reset & control
      pgpRxClk          : in  sl;
      pgpRxClkRst       : in  sl;

      -- Non-VC related IO
      pgpRxIn           : in  Pgp2bRxInType;
      pgpRxOut          : out Pgp2bRxOutType;

      -- Rx Interface, 16-bits, muxed and de-muxed copies
      pgpRxMasters      : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed  : out AxiStreamMasterType;

      -- AXI buffer status
      pgpRxCtrl         : in  AxiStreamCtrlArray(3 downto 0)
   );

end PgpSimModel;


-- Define architecture
architecture PgpSimModel of PgpSimModel is

   signal muxedTxMaster      : AxiStreamMasterType;
   signal muxedTxSlave       : AxiStreamSlaveType;
   signal muxedRxMaster      : AxiStreamMasterType;
   signal muxedRxSlave       : AxiStreamSlaveType;
   signal deMuxedRxMasters   : AxiStreamMasterArray(3 downto 0);
   signal deMuxedRxSlaves    : AxiStreamSlaveArray(3 downto 0);

begin

   -- Fake transmit control signals
   pgpTxOut.linkReady <= '1';

   -- Transmit MUX
   U_TxMux : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 4
      ) port map (
         axisClk      => pgpTxClk,
         axisRst      => pgpTxClkRst,
         sAxisMasters => pgpTxMasters,
         sAxisSlaves  => pgpTxSlaves,
         mAxisMaster  => muxedTxMaster,
         mAxisSlave   => muxedTxSlave
      );

   -- Simulation link
   U_Sim : entity work.AxiStreamSim
      generic map (
         TPD_G            => TPD_G,
         AXIS_CONFIG_G    => SSI_PGP2B_CONFIG_C,
         EOFE_TUSER_EN_G  => true,
         EOFE_TUSER_BIT_G => SSI_EOFE_C,
         SOF_TUSER_EN_G   => true,
         SOF_TUSER_BIT_G  => SSI_SOF_C
      ) port map (                          
         sAxisClk     => pgpTxClk,
         sAxisRst     => pgpTxClkRst,
         sAxisMaster  => muxedTxMaster,
         sAxisSlave   => muxedTxSlave,
         mAxisClk     => pgpRxClk,
         mAxisRst     => pgpRxClkRst,
         mAxisMaster  => muxedRxMaster,
         mAxisSlave   => muxedRxSlave
      );

   process ( pgpRxCtrl, muxedRxMaster, muxedRxSlave, deMuxedRxSlaves, deMuxedRxMasters ) is
   begin

      pgpRxMasterMuxed        <= muxedRxMaster;
      pgpRxMasterMuxed.tValid <= muxedRxMaster.tValid and muxedRxSlave.tReady;

      pgpRxMasters <= deMuxedRxMasters;

      for i in 0 to 3 loop
         deMuxedRxSlaves(i).tReady <= not pgpRxCtrl(i).pause;
         pgpRxMasters(i).tValid    <= deMuxedRxMasters(i).tValid and deMuxedRxSlaves(i).tReady;
      end loop;

   end process;

   -- Receive De-MUX
   U_RxDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4
      ) port map (
         axisClk      => pgpRxClk,
         axisRst      => pgpRxClkRst,
         sAxisMaster  => muxedRxMaster,
         sAxisSlave   => muxedRxSlave,
         mAxisMasters => deMuxedRxMasters,
         mAxisSlaves  => deMuxedRxSlaves
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

end PgpSimModel;

