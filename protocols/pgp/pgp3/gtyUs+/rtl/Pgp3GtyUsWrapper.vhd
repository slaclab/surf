-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTY Ultrascale+ Wrapper
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
use surf.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp3GtyUsWrapper is
   generic (
      TPD_G                       : time                        := 1 ns;
      ROGUE_SIM_EN_G              : boolean                     := false;
      ROGUE_SIM_SIDEBAND_G        : boolean                     := true;
      ROGUE_SIM_PORT_NUM_G        : natural range 1024 to 49151 := 9000;
      SYNTH_MODE_G                : string                      := "inferred";
      MEMORY_TYPE_G               : string                      := "block";
      NUM_LANES_G                 : positive range 1 to 4       := 1;
      NUM_VC_G                    : positive range 1 to 16      := 4;
      REFCLK_G                    : boolean                     := false;  --  FALSE: pgpRefClkP/N,  TRUE: pgpRefClkIn
      RATE_G                      : string                      := "10.3125Gbps";  -- or "6.25Gbps" or "3.125Gbps"
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G             : boolean                     := true;
      RX_ALIGN_SLIP_WAIT_G        : integer                     := 32;
      PGP_TX_ENABLE_G             : boolean                     := true;
      TX_CELL_WORDS_MAX_G         : integer                     := PGP3_DEFAULT_TX_CELL_WORDS_MAX_C;  -- Number of 64-bit words per cell
      TX_MUX_MODE_G               : string                      := "INDEXED";      -- Or "ROUTED"
      TX_MUX_TDEST_ROUTES_G       : Slv8Array                   := (0      => "--------");  -- Only used in ROUTED mode
      TX_MUX_TDEST_LOW_G          : integer range 0 to 7        := 0;
      TX_MUX_ILEAVE_EN_G          : boolean                     := true;
      TX_MUX_ILEAVE_ON_NOTVALID_G : boolean                     := true;
      EN_PGP_MON_G                : boolean                     := false;
      EN_GTH_DRP_G                : boolean                     := false;
      EN_QPLL_DRP_G               : boolean                     := false;
      TX_POLARITY_G               : slv(3 downto 0)             := x"0";
      RX_POLARITY_G               : slv(3 downto 0)             := x"0";
      AXIL_BASE_ADDR_G            : slv(31 downto 0)            := (others => '0');
      AXIL_CLK_FREQ_G             : real                        := 125.0E+6);
   port (
      -- Stable Clock and Reset
      stableClk         : in  sl;       -- GT needs a stable clock to "boot up"
      stableRst         : in  sl;
      -- Gt Serial IO
      pgpGtTxP          : out slv(NUM_LANES_G-1 downto 0);
      pgpGtTxN          : out slv(NUM_LANES_G-1 downto 0);
      pgpGtRxP          : in  slv(NUM_LANES_G-1 downto 0);
      pgpGtRxN          : in  slv(NUM_LANES_G-1 downto 0);
      -- GT Clocking
      pgpRefClkP        : in  sl                                                     := '0';  -- 156.25 MHz
      pgpRefClkN        : in  sl                                                     := '1';  -- 156.25 MHz
      pgpRefClkIn       : in  sl                                                     := '0';  -- 156.25 MHz
      pgpRefClkOut      : out sl;
      pgpRefClkDiv2Bufg : out sl;
      -- Clocking
      pgpClk            : out slv(NUM_LANES_G-1 downto 0);
      pgpClkRst         : out slv(NUM_LANES_G-1 downto 0);
      -- Non VC Rx Signals
      pgpRxIn           : in  Pgp3RxInArray(NUM_LANES_G-1 downto 0);
      pgpRxOut          : out Pgp3RxOutArray(NUM_LANES_G-1 downto 0);
      -- Non VC Tx Signals
      pgpTxIn           : in  Pgp3TxInArray(NUM_LANES_G-1 downto 0);
      pgpTxOut          : out Pgp3TxOutArray(NUM_LANES_G-1 downto 0);
      -- Frame Transmit Interface
      pgpTxMasters      : in  AxiStreamMasterArray((NUM_LANES_G*NUM_VC_G)-1 downto 0);
      pgpTxSlaves       : out AxiStreamSlaveArray((NUM_LANES_G*NUM_VC_G)-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters      : out AxiStreamMasterArray((NUM_LANES_G*NUM_VC_G)-1 downto 0);
      pgpRxCtrl         : in  AxiStreamCtrlArray((NUM_LANES_G*NUM_VC_G)-1 downto 0);  -- Used in implementation only
      pgpRxSlaves       : in  AxiStreamSlaveArray((NUM_LANES_G*NUM_VC_G)-1 downto 0) := (others => AXI_STREAM_SLAVE_FORCE_C);  -- Used in simulation only
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk           : in  sl                                                     := '0';  -- Stable Clock
      axilRst           : in  sl                                                     := '0';
      axilReadMaster    : in  AxiLiteReadMasterType                                  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave     : out AxiLiteReadSlaveType                                   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster   : in  AxiLiteWriteMasterType                                 := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave    : out AxiLiteWriteSlaveType                                  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp3GtyUsWrapper;

architecture rtl of Pgp3GtyUsWrapper is

   signal qpllLock   : Slv2Array(3 downto 0) := (others => "00");
   signal qpllClk    : Slv2Array(3 downto 0) := (others => "00");
   signal qpllRefclk : Slv2Array(3 downto 0) := (others => "00");
   signal qpllRst    : Slv2Array(3 downto 0) := (others => "00");

   signal pgpRefClkDiv2 : sl;
   signal pgpRefClk     : sl;

   constant NUM_AXIL_MASTERS_C : integer := NUM_LANES_G+1;
   constant QPLL_AXIL_INDEX_C  : integer := NUM_AXIL_MASTERS_C-1;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 16, 13);

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)   := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);

begin

   pgpRefClkOut <= pgpRefClk;

   INT_REFCLK : if (REFCLK_G = false) generate

      U_BUFG_GT : BUFG_GT
         port map (
            I       => pgpRefClkDiv2,
            CE      => '1',
            CLR     => '0',
            CEMASK  => '1',
            CLRMASK => '1',
            DIV     => "000",           -- Divide by 1
            O       => pgpRefClkDiv2Bufg);

      U_pgpRefClk : IBUFDS_GTE4
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => pgpRefClkP,
            IB    => pgpRefClkN,
            CEB   => '0',
            ODIV2 => pgpRefClkDiv2,
            O     => pgpRefClk);

   end generate;

   EXT_REFCLK : if (REFCLK_G = true) generate

      pgpRefClkDiv2Bufg <= '0';
      pgpRefClk         <= pgpRefClkIn;

   end generate;

   REAL_PGP : if (not ROGUE_SIM_EN_G) generate

      U_XBAR : entity surf.AxiLiteCrossbar
         generic map (
            TPD_G              => TPD_G,
            NUM_SLAVE_SLOTS_G  => 1,
            NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
            MASTERS_CONFIG_G   => XBAR_CONFIG_C)
         port map (
            axiClk              => axilClk,
            axiClkRst           => axilRst,
            sAxiWriteMasters(0) => axilWriteMaster,
            sAxiWriteSlaves(0)  => axilWriteSlave,
            sAxiReadMasters(0)  => axilReadMaster,
            sAxiReadSlaves(0)   => axilReadSlave,
            mAxiWriteMasters    => axilWriteMasters,
            mAxiWriteSlaves     => axilWriteSlaves,
            mAxiReadMasters     => axilReadMasters,
            mAxiReadSlaves      => axilReadSlaves);

      U_QPLL : entity surf.Pgp3GtyUsQpll
         generic map (
            TPD_G    => TPD_G,
            RATE_G   => RATE_G,
            EN_DRP_G => EN_QPLL_DRP_G)
         port map (
            -- Stable Clock and Reset
            stableClk       => stableClk,                            -- [in]
            stableRst       => stableRst,                            -- [in]
            -- QPLL Clocking
            pgpRefClk       => pgpRefClk,                            -- [in]
            qpllLock        => qpllLock,                             -- [out]
            qpllClk         => qpllClk,                              -- [out]
            qpllRefclk      => qpllRefclk,                           -- [out]
            qpllRst         => qpllRst,                              -- [in]
            axilClk         => axilClk,                              -- [in]
            axilRst         => axilRst,                              -- [in]
            axilReadMaster  => axilReadMasters(QPLL_AXIL_INDEX_C),   -- [in]
            axilReadSlave   => axilReadSlaves(QPLL_AXIL_INDEX_C),    -- [out]
            axilWriteMaster => axilWriteMasters(QPLL_AXIL_INDEX_C),  -- [in]
            axilWriteSlave  => axilWriteSlaves(QPLL_AXIL_INDEX_C));  -- [out]

      -----------
      -- PGP Core
      -----------
      GEN_LANE : for i in NUM_LANES_G-1 downto 0 generate
         U_Pgp : entity surf.Pgp3GtyUs
            generic map (
               TPD_G                       => TPD_G,
               RATE_G                      => RATE_G,
               SYNTH_MODE_G                => SYNTH_MODE_G,
               ----------------------------------------------------------------------------------------------
               -- PGP Settings
               ----------------------------------------------------------------------------------------------
               PGP_RX_ENABLE_G             => PGP_RX_ENABLE_G,
               RX_ALIGN_SLIP_WAIT_G        => RX_ALIGN_SLIP_WAIT_G,
               PGP_TX_ENABLE_G             => PGP_TX_ENABLE_G,
               NUM_VC_G                    => NUM_VC_G,
               TX_CELL_WORDS_MAX_G         => TX_CELL_WORDS_MAX_G,
               TX_MUX_MODE_G               => TX_MUX_MODE_G,
               TX_MUX_TDEST_ROUTES_G       => TX_MUX_TDEST_ROUTES_G,
               TX_MUX_TDEST_LOW_G          => TX_MUX_TDEST_LOW_G,
               TX_MUX_ILEAVE_EN_G          => TX_MUX_ILEAVE_EN_G,
               TX_MUX_ILEAVE_ON_NOTVALID_G => TX_MUX_ILEAVE_ON_NOTVALID_G,
               EN_PGP_MON_G                => EN_PGP_MON_G,
               EN_DRP_G                    => EN_GTH_DRP_G,
               TX_POLARITY_G               => TX_POLARITY_G(i),
               RX_POLARITY_G               => RX_POLARITY_G(i),
               AXIL_BASE_ADDR_G            => XBAR_CONFIG_C(i).baseAddr,
               AXIL_CLK_FREQ_G             => AXIL_CLK_FREQ_G)
            port map (
               -- Stable Clock and Reset
               stableClk       => stableClk,
               stableRst       => stableRst,
               -- QPLL Interface
               qpllLock        => qpllLock(i),
               qpllClk         => qpllClk(i),
               qpllRefclk      => qpllRefclk(i),
               qpllRst         => qpllRst(i),
               -- Gt Serial IO
               pgpGtTxP        => pgpGtTxP(i),
               pgpGtTxN        => pgpGtTxN(i),
               pgpGtRxP        => pgpGtRxP(i),
               pgpGtRxN        => pgpGtRxN(i),
               -- Clocking
               pgpClk          => pgpClk(i),
               pgpClkRst       => pgpClkRst(i),
               -- Non VC Rx Signals
               pgpRxIn         => pgpRxIn(i),
               pgpRxOut        => pgpRxOut(i),
               -- Non VC Tx Signals
               pgpTxIn         => pgpTxIn(i),
               pgpTxOut        => pgpTxOut(i),
               -- Frame Transmit Interface
               pgpTxMasters    => pgpTxMasters(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               pgpTxSlaves     => pgpTxSlaves(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               -- Frame Receive Interface
               pgpRxMasters    => pgpRxMasters(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               pgpRxCtrl       => pgpRxCtrl(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               -- AXI-Lite Register Interface (axilClk domain)
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMasters(i),
               axilReadSlave   => axilReadSlaves(i),
               axilWriteMaster => axilWriteMasters(i),
               axilWriteSlave  => axilWriteSlaves(i));

      end generate GEN_LANE;

   end generate REAL_PGP;

   SIM_PGP : if (ROGUE_SIM_EN_G) generate
      GEN_LANE : for i in NUM_LANES_G-1 downto 0 generate
         U_Rogue : entity surf.RoguePgp3Sim
            generic map(
               TPD_G         => TPD_G,
               SYNTH_MODE_G  => SYNTH_MODE_G,
               MEMORY_TYPE_G => MEMORY_TYPE_G,
               PORT_NUM_G    => (ROGUE_SIM_PORT_NUM_G+(i*34)),
               EN_SIDEBAND_G => ROGUE_SIM_SIDEBAND_G,
               NUM_VC_G      => NUM_VC_G)
            port map(
               -- GT Ports
               pgpRefClk       => pgpRefClk,
               pgpGtTxP        => pgpGtTxP(i),
               pgpGtTxN        => pgpGtTxN(i),
               pgpGtRxP        => pgpGtRxP(i),
               pgpGtRxN        => pgpGtRxN(i),
               -- PGP Clock and Reset
               pgpClk          => pgpClk(i),
               pgpClkRst       => pgpClkRst(i),
               -- Non VC Rx Signals
               pgpRxIn         => pgpRxIn(i),
               pgpRxOut        => pgpRxOut(i),
               -- Non VC Tx Signals
               pgpTxIn         => pgpTxIn(i),
               pgpTxOut        => pgpTxOut(i),
               -- Frame Transmit Interface
               pgpTxMasters    => pgpTxMasters(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               pgpTxSlaves     => pgpTxSlaves(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               -- Frame Receive Interface
               pgpRxMasters    => pgpRxMasters(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               pgpRxSlaves     => pgpRxSlaves(((i+1)*NUM_VC_G)-1 downto (i*NUM_VC_G)),
               -- AXI-Lite Register Interface (axilClk domain)
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMasters(i),
               axilReadSlave   => axilReadSlaves(i),
               axilWriteMaster => axilWriteMasters(i),
               axilWriteSlave  => axilWriteSlaves(i));
      end generate GEN_LANE;
   end generate SIM_PGP;

end rtl;
