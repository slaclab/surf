-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on RogueStreamSim to simulate a PGPv3
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp2fcPkg.all;
use surf.SsiPkg.all;

entity RoguePgp2fcSim is
   generic (
      TPD_G      : time                        := 1 ns;
      FC_WORDS_G : integer range 1 to 8        := 1;
      PORT_NUM_G : natural range 1024 to 49151 := 9000;
      NUM_VC_G   : integer range 1 to 16       := 4);
   port (
      -- PGP Clock and Reset
      pgpClk       : in  sl;
      pgpClkRst    : in  sl;
      -- Non VC Rx Signals
      pgpRxIn      : in  Pgp2fcRxInType;
      pgpRxOut     : out Pgp2fcRxOutType;
      -- Non VC Tx Signals
      pgpTxIn      : in  Pgp2fcTxInType;
      pgpTxOut     : out Pgp2fcTxOutType;
      -- Frame Transmit Interface
      pgpTxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxSlaves  : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0));
end entity RoguePgp2fcSim;

architecture sim of RoguePgp2fcSim is

   constant FC_AXIS_CFG_C   : AxiStreamConfigType := ssiAxiStreamConfig(2*FC_WORDS_G, TKEEP_COMP_C);
   constant BYTE_AXIS_CFG_C : AxiStreamConfigType := ssiAxiStreamConfig(2, TKEEP_COMP_C);


   signal txOut : Pgp2fcTxOutType := PGP2FC_TX_OUT_INIT_C;
   signal rxOut : Pgp2fcRxOutType := PGP2FC_RX_OUT_INIT_C;

   signal pgpTxMastersLoc : AxiStreamMasterArray(NUM_VC_G-1 downto 0);

   signal txFcAxisMaster : AxiStreamMasterType := axiStreamMasterInit(FC_AXIS_CFG_C);
   signal txFcAxisSlave  : AxiStreamSlaveType;
   signal rxFcAxisMaster : AxiStreamMasterType := axiStreamMasterInit(FC_AXIS_CFG_C);
   signal rxFcAxisSlave  : AxiStreamSlaveType;

   signal txByteAxisMaster : AxiStreamMasterType := axiStreamMasterInit(BYTE_AXIS_CFG_C);
   signal txByteAxisSlave  : AxiStreamSlaveType;
   signal rxByteAxisMaster : AxiStreamMasterType := axiStreamMasterInit(BYTE_AXIS_CFG_C);
   signal rxByteAxisSlave  : AxiStreamSlaveType;



begin

   pgpTxOut <= txOut;
   pgpRxOut <= rxOut;

   TDEST_ZERO : process (pgpTxMasters) is
      variable tmp : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   begin
      tmp := pgpTxMasters;
      for i in NUM_VC_G-1 downto 0 loop
         tmp(i).tDest := (others => '0');
      end loop;
      pgpTxMastersLoc <= tmp;

   end process TDEST_ZERO;

   GEN_VEC : for i in NUM_VC_G-1 downto 0 generate
      U_PGP_VC : entity surf.RogueTcpStreamWrap
         generic map (
            TPD_G         => TPD_G,
            PORT_NUM_G    => (PORT_NUM_G + i*2),
            SSI_EN_G      => true,
            CHAN_MASK_G   => "00000000",
            TDEST_MASK_G  => toSlv(i, 8),
            AXIS_CONFIG_G => PGP2FC_AXIS_CONFIG_C)
         port map (
            axisClk     => pgpClk,              -- [in]
            axisRst     => pgpClkRst,           -- [in]
            sAxisMaster => pgpTxMastersLoc(i),  -- [in]
            sAxisSlave  => pgpTxSlaves(i),      -- [out]
            mAxisMaster => pgpRxMasters(i),     -- [out]
            mAxisSlave  => pgpRxSlaves(i));     -- [in]
   end generate GEN_VEC;

   U_RogueSideBandWrap_1 : entity surf.RogueSideBandWrap
      generic map (
         TPD_G      => TPD_G,
         PORT_NUM_G => PORT_NUM_G + 8)
      port map (
         sysClk     => pgpClk,              -- [in]
         sysRst     => pgpClkRst,           -- [in]
         txOpCode   => X"00",               -- [in]
         txOpCodeEn => '0',                 -- [in]
         txRemData  => pgpTxIn.locData,     -- [in]
         rxOpCode   => open,                -- [out]
         rxOpCodeEn => open,                -- [out]
         rxRemData  => rxOut.remLinkData);  -- [out]


   -- Send a single txn frame for FC word
   txFcAxisMaster.tValid                          <= pgpTxIn.fcValid;
   txFcAxisMaster.tData(FC_WORDS_G*16-1 downto 0) <= pgpTxIn.fcWord(FC_WORDS_G*16-1 downto 0);
   txFcAxisMaster.tLast                           <= pgpTxIn.fcValid;
   txFcAxisMaster.tUser(1)                        <= pgpTxIn.fcValid;

   U_TX_Resize : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => FC_AXIS_CFG_C,
         MASTER_AXI_CONFIG_G => BYTE_AXIS_CFG_C)
      port map (
         -- Clock and Reset
         axisClk     => pgpClk,
         axisRst     => pgpClkRst,
         -- Slave Port
         sAxisMaster => txFcAxisMaster,
         sAxisSlave  => txFcAxisSlave,
         -- Master Port
         mAxisMaster => txByteAxisMaster,
         mAxisSlave  => txByteAxisSlave);


   U_PGP_FC : entity surf.RogueTcpStreamWrap
      generic map (
         TPD_G         => TPD_G,
         PORT_NUM_G    => (PORT_NUM_G + 10),
         SSI_EN_G      => true,
         CHAN_MASK_G   => "00000000",
         TDEST_MASK_G  => "00000000",
         AXIS_CONFIG_G => BYTE_AXIS_CFG_C)
      port map (
         axisClk     => pgpClk,          -- [in]
         axisRst     => pgpClkRst,       -- [in]
         sAxisMaster => txByteAxisMaster,  -- [in]
         sAxisSlave  => txByteAxisSlave,   -- [out]
         mAxisMaster => rxByteAxisMaster,  -- [out]
         mAxisSlave  => rxByteAxisSlave);  -- [in]

   U_RX_Resize : entity surf.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => BYTE_AXIS_CFG_C,
         MASTER_AXI_CONFIG_G => FC_AXIS_CFG_C)
      port map (
         -- Clock and Reset
         axisClk     => pgpClk,
         axisRst     => pgpClkRst,
         -- Slave Port
         sAxisMaster => rxByteAxisMaster,
         sAxisSlave  => rxByteAxisSlave,
         -- Master Port
         mAxisMaster => rxFcAxisMaster,
         mAxisSlave  => rxFcAxisSlave);


   -- Receive single txn frame for FC word
   rxOut.fcValid                          <= rxFcAxisMaster.tValid;
   rxOut.fcWord(FC_WORDS_G*16-1 downto 0) <= rxFcAxisMaster.tData(FC_WORDS_G*16-1 downto 0);

   txOut.phyTxReady <= '1';
   txOut.linkReady  <= '1';

   rxOut.phyRxReady   <= '1';
   rxOut.linkReady    <= '1';
   rxOut.remLinkReady <= '1';

end sim;
