-------------------------------------------------------------------------------
-- File       : PgpParallelSimModel.vhd
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

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;

entity PgpParallelSimModel is
   generic (
      TPD_G                 : time                 := 1 ns;
      -- Delay Parameters
      CLK_FREQ_G            : real                 := 156.250E+6;  -- In units of HZ
      CABLE_LENGTH_G        : real                 := 1.0;  -- In units of meters
      INDEX_OF_REFRACTION_G : real                 := 1.5;  -- Default is 1.5 index of refraction for fiber optic cable
      TX_SER_DELAY_C        : natural              := 5;
      RX_SER_DELAY_C        : natural              := 5;
      -- PGP Parameters
      VC_INTERLEAVE_G       : integer              := 1;    -- Interleave Frames
      PAYLOAD_CNT_TOP_G     : integer              := 7;    -- Top bit for payload counter
      NUM_VC_EN_G           : integer range 1 to 4 := 4;
      TX_ENABLE_G           : boolean              := true;        -- Enable TX direction
      RX_ENABLE_G           : boolean              := true);       -- Enable RX direction      
   port (
      -- System Signals
      clk          : in  sl;
      rst          : in  sl;
      -- Frame Transmit Interface
      pgpTxMasters : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface
      pgpRxMasters : out AxiStreamMasterArray(3 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(3 downto 0);
      -- Non VC Rx Signals
      pgpRxIn      : in  Pgp2bRxInType := PGP2B_RX_IN_INIT_C;
      pgpRxOut     : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn      : in  Pgp2bTxInType := PGP2B_TX_IN_INIT_C;
      pgpTxOut     : out Pgp2bTxOutType;
      -- PGP 8B/10B Encoded
      pgpIn        : in  slv(19 downto 0);
      pgpOut       : out slv(19 downto 0));       
end PgpParallelSimModel;

architecture mapping of PgpParallelSimModel is

   constant SPEED_OF_LIGHT_C    : real    := 299792458.0;  -- speed of light in a vacuum (m/s)
   constant SPEED_OF_FIBER_C    : real    := SPEED_OF_LIGHT_C / INDEX_OF_REFRACTION_G;  -- speed of light in a fiber (m/s)
   constant CLK_PER_METER_C     : real    := CLK_FREQ_G / SPEED_OF_FIBER_C;  -- # of clock cycles per meter
   constant CABLE_DELAY_FLOAT_C : real    := CABLE_LENGTH_G * CLK_PER_METER_C;
   constant CABLE_DELAY_C       : natural := getTimeRatio(CABLE_DELAY_FLOAT_C, 1.0);

   -- 2 bytes of 8B10B is 20 bits
   constant WIDTH_C : natural := 20;

   signal phyTxReady : sl;
   signal phyRxReady : sl;
   signal pgpInDly   : slv(19 downto 0);
   signal dataIn     : slv(19 downto 0);
   signal dataOut    : slv(19 downto 0);

   signal phyTxLanesOut : Pgp2bTxPhyLaneOutArray(0 to 0);
   signal phyRxLanesIn  : Pgp2bRxPhyLaneInArray(0 to 0);
   
begin

   U_CableDelay : entity work.SlvDelay
      generic map (
         TPD_G   => TPD_G,
         DELAY_G => CABLE_DELAY_C,
         WIDTH_G => WIDTH_C)
      port map (
         clk  => clk,
         din  => pgpIn,
         dout => pgpInDly); 

   U_RxSerDelay : entity work.SlvDelay
      generic map (
         TPD_G   => TPD_G,
         DELAY_G => RX_SER_DELAY_C,
         WIDTH_G => WIDTH_C)
      port map (
         clk  => clk,
         din  => pgpInDly,
         dout => dataIn);                 

   U_Decoder8b10b : entity work.Decoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 2)
      port map (
         clk      => clk,
         rst      => rst,
         dataIn   => dataIn,
         dataOut  => phyRxLanesIn(0).data,
         dataKOut => phyRxLanesIn(0).dataK,
         codeErr  => phyRxLanesIn(0).decErr,
         dispErr  => phyRxLanesIn(0).dispErr);      

   phyTxReady <= not(rst);
   phyRxReady <= not(rst);

   U_Pgp2bLane : entity work.Pgp2bLane
      generic map (
         TPD_G             => TPD_G,
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         TX_ENABLE_G       => TX_ENABLE_G,
         RX_ENABLE_G       => RX_ENABLE_G)         
      port map (
         pgpTxClk         => clk,
         pgpTxClkRst      => rst,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         phyTxLanesOut    => phyTxLanesOut,
         phyTxReady       => phyTxReady,
         pgpRxClk         => clk,
         pgpRxClkRst      => rst,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => open,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLanesOut    => open,
         phyRxLanesIn     => phyRxLanesIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => open);

   U_Encoder8b10b : entity work.Encoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => 2)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => phyTxLanesOut(0).data,
         dataKIn => phyTxLanesOut(0).dataK,
         dataOut => dataOut);

   U_TxSerDelay : entity work.SlvDelay
      generic map (
         TPD_G   => TPD_G,
         DELAY_G => TX_SER_DELAY_C,
         WIDTH_G => WIDTH_C)
      port map (
         clk  => clk,
         din  => dataOut,
         dout => pgpOut);        

end mapping;
