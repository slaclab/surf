-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on the Pgp4RxLite Low Speed Lane
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4RxLiteLowSpeedLane is
   generic (
      TPD_G              : time                    := 1 ns;
      SIMULATION_G       : boolean                 := false;
      DLY_STEP_SIZE_G    : positive range 1 to 255 := 1;
      STATUS_CNT_WIDTH_G : natural range 1 to 32   := 16;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32   := 8;
      AXIL_CLK_FREQ_G    : real                    := 125.0E+6);
   port (
      -- Deserialization Interface (deserClk domain)
      deserClk        : in  sl;
      deserRst        : in  sl;
      deserData       : in  slv(7 downto 0);
      dlyLoad         : out sl;
      dlyCfg          : out slv(8 downto 0);
      -- Config/Status Interface (deserClk domain)
      enUsrDlyCfg     : in  sl;
      usrDlyCfg       : in  slv(8 downto 0);
      minEyeWidth     : in  slv(7 downto 0);
      lockingCntCfg   : in  slv(23 downto 0);
      bypFirstBerDet  : in  sl;
      polarity        : in  sl;
      bitOrder        : in  slv(1 downto 0);
      errorDet        : out sl;
      bitSlip         : out sl;
      eyeWidth        : out slv(8 downto 0);
      locked          : out sl;
      -- PGP Streaming Outputs (deserClk domain)
      pgpRxMaster     : out AxiStreamMasterType;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end Pgp4RxLiteLowSpeedLane;

architecture mapping of Pgp4RxLiteLowSpeedLane is

   signal deserDataMask : slv(7 downto 0) := (others => '0');

   signal deserReset     : sl := '1';
   signal gearboxAligned : sl := '0';
   signal slip           : sl := '0';

   signal phyRxValid : sl := '0';
   signal phyRxData  : slv(65 downto 0);

begin

   process(deserClk)
   begin
      if rising_edge(deserClk) then
         bitSlip <= slip           after TPD_G;
         locked  <= gearboxAligned after TPD_G;
      end if;
   end process;

   U_reset : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => deserClk,
         rstIn  => deserRst,
         rstOut => deserReset);

   deserDataMask <= deserData when(polarity = '0') else not(deserData);

   ---------------
   -- 8:66 Gearbox
   ---------------
   U_Gearbox : entity surf.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => 8,
         MASTER_WIDTH_G => 66)
      port map (
         clk            => deserClk,
         rst            => deserReset,
         slip           => slip,
         -- Slave Interface
         slaveValid     => '1',
         slaveData      => deserDataMask,
         slaveBitOrder  => bitOrder(0),
         -- Master Interface
         masterValid    => phyRxValid,
         masterData     => phyRxData,
         masterReady    => '1',
         masterBitOrder => bitOrder(1));

   ------------------
   -- Gearbox Aligner
   ------------------
   U_GearboxAligner : entity surf.SelectIoRxGearboxAligner
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         DLY_STEP_SIZE_G => DLY_STEP_SIZE_G,
         CODE_TYPE_G     => "SCRAMBLER")
      port map (
         -- Clock and Reset
         clk             => deserClk,
         rst             => deserReset,
         -- Line-Code Interface (CODE_TYPE_G = "LINE_CODE")
         lineCodeValid   => '0',
         lineCodeErr     => '0',
         lineCodeDispErr => '0',
         linkOutOfSync   => '0',
         -- 64b/66b Interface (CODE_TYPE_G = "SCRAMBLER")
         rxHeaderValid   => phyRxValid,
         rxHeader        => phyRxData(65 downto 64),
         -- Link Status and Gearbox Slip
         bitSlip         => slip,
         -- IDELAY (DELAY_TYPE="VAR_LOAD") Interface
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- Configuration Interface
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         bypFirstBerDet  => bypFirstBerDet,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         -- Status Interface
         errorDet        => errorDet,
         eyeWidth        => eyeWidth,
         locked          => gearboxAligned);

   ------------------
   -- PGPv4 Core Lite
   ------------------
   U_Pgp4CoreLite : entity surf.Pgp4CoreLite
      generic map (
         TPD_G              => TPD_G,
         NUM_VC_G           => 1,       -- Only 1 VC per PGPv4 Lite link
         PGP_RX_ENABLE_G    => true,    -- Enable the RX path
         PGP_TX_ENABLE_G    => false,   -- Disable the unused TX path
         SKIP_EN_G          => false,  -- No skips (assumes clock source synchronous system)
         FLOW_CTRL_EN_G     => false,   -- No flow control
         EN_PGP_MON_G       => true,    -- Enable the AXI-Lite interface
         WRITE_EN_G         => true,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         ERROR_CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
         AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
      port map (
         -- Tx User interface
         pgpTxClk        => deserClk,
         pgpTxRst        => deserReset,
         pgpTxActive     => '0',
         pgpTxMasters    => (others => AXI_STREAM_MASTER_INIT_C),
         -- Tx PHY interface
         phyTxActive     => '0',
         phyTxReady      => '0',
         -- Rx User interface
         pgpRxClk        => deserClk,
         pgpRxRst        => deserReset,
         pgpRxMasters(0) => pgpRxMaster,
         pgpRxCtrl(0)    => AXI_STREAM_CTRL_UNUSED_C,
         -- Rx PHY interface
         phyRxClk        => deserClk,
         phyRxRst        => deserReset,
         phyRxActive     => gearboxAligned,
         phyRxStartSeq   => '0',
         phyRxValid      => phyRxValid,
         phyRxData       => phyRxData(63 downto 0),
         phyRxHeader     => phyRxData(65 downto 64),
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
