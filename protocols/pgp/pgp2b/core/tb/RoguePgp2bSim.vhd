-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
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
use surf.Pgp2bPkg.all;

entity RoguePgp2bSim is
   generic (
      TPD_G         : time                        := 1 ns;
      PORT_NUM_G    : natural range 1024 to 49151 := 9000;
      NUM_VC_G      : integer range 1 to 16       := 4;
      EN_SIDEBAND_G : boolean                     := true);
   port (
      -- PGP Clock and Reset
      pgpClk          : in  sl;
      pgpClkRst       : in  sl;
      -- Non VC Rx Signals
      pgpRxIn         : in  Pgp2bRxInType;
      pgpRxOut        : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn         : in  Pgp2bTxInType;
      pgpTxOut        : out Pgp2bTxOutType;
      -- Frame Transmit Interface
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxSlaves     : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';  -- Stable Clock
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);
end entity RoguePgp2bSim;

architecture sim of RoguePgp2bSim is

   signal txOut : Pgp2bTxOutType := PGP2B_TX_OUT_INIT_C;
   signal rxOut : Pgp2bRxOutType := PGP2B_RX_OUT_INIT_C;

   signal pgpTxMastersLoc : AxiStreamMasterArray(NUM_VC_G-1 downto 0);

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
            AXIS_CONFIG_G => SSI_PGP2B_CONFIG_C)
         port map (
            axisClk     => pgpClk,              -- [in]
            axisRst     => pgpClkRst,           -- [in]
            sAxisMaster => pgpTxMastersLoc(i),  -- [in]
            sAxisSlave  => pgpTxSlaves(i),      -- [out]
            mAxisMaster => pgpRxMasters(i),     -- [out]
            mAxisSlave  => pgpRxSlaves(i));     -- [in]
   end generate GEN_VEC;

   GEN_SIDEBAND : if (EN_SIDEBAND_G) generate
      U_RogueSideBandWrap_1 : entity surf.RogueSideBandWrap
         generic map (
            TPD_G      => TPD_G,
            PORT_NUM_G => PORT_NUM_G + 8)
         port map (
            sysClk     => pgpClk,              -- [in]
            sysRst     => pgpClkRst,           -- [in]
            txOpCode   => pgpTxIn.opCode,      -- [in]
            txOpCodeEn => pgpTxIn.opCodeEn,    -- [in]
            txRemData  => pgpTxIn.locData,     -- [in]
            rxOpCode   => rxOut.opCode,        -- [out]
            rxOpCodeEn => rxOut.opCodeEn,      -- [out]
            rxRemData  => rxOut.remLinkData);  -- [out]
   end generate GEN_SIDEBAND;

   txOut.phyTxReady <= '1';
   txOut.linkReady  <= '1';

   rxOut.phyRxReady   <= '1';
   rxOut.linkReady    <= '1';
   rxOut.remLinkReady <= '1';

end sim;
