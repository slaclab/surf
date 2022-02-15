-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Subordinate Simulation Model
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

library ruckus;
use ruckus.BuildInfoPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity SugoiSubordinateSimModel is
   generic (
      TPD_G           : time     := 1 ns;
      NUM_ADDR_BITS_G : positive := 16);
   port (
      -- SUGOI Serial Ports
      clkInP  : in  sl;
      clkInN  : in  sl;
      rxP     : in  sl;
      rxN     : in  sl;
      txP     : out sl;
      txN     : out sl;
      clkOutP : out sl;
      clkOutN : out sl;
      -- Link Status
      linkup  : out sl;
      --Global Resets
      rst     : out sl;                 -- Active HIGH global reset
      rstL    : out sl;                 -- Active LOW global reset
      -- Trigger/Timing Command Bus
      opCode  : out slv(7 downto 0));   -- 1-bit per Control code
end entity SugoiSubordinateSimModel;

architecture mapping of SugoiSubordinateSimModel is

   constant GET_BUILD_INFO_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);
   constant MOD_BUILD_INFO_C : BuildInfoRetType := (
      buildString => GET_BUILD_INFO_C.buildString,
      fwVersion   => GET_BUILD_INFO_C.fwVersion,
      gitHash     => x"1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA");  -- Force githash
   constant SIM_BUILD_INFO_C : slv(2239 downto 0) := toSlv(MOD_BUILD_INFO_C);

   constant VERSION_INDEX_C    : natural := 0;
   constant BROKEN_INDEX_C     : natural := 1;
   constant NUM_AXIL_MASTERS_C : natural := 2;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", NUM_ADDR_BITS_G, NUM_ADDR_BITS_G-1);

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_INIT_C);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);

   signal clk   : sl;
   signal rx    : sl;
   signal tx    : sl;
   signal reset : sl;

begin

   -- Set the read data to be equal to the read address for swapping/verifying all address bytes
   axilReadSlaves(1).rdata   <= axilReadMasters(1).araddr;
   axilReadSlaves(1).arready <= axilReadMasters(1).arvalid;
   axilReadSlaves(1).rvalid  <= axilReadMasters(1).rready;


   rst <= reset;

   U_CLK_IN : IBUFDS
      port map (
         I  => clkInP,
         IB => clkInN,
         O  => clk);

   U_RX : IBUFDS
      port map (
         I  => rxP,
         IB => rxN,
         O  => rx);

   U_Core : entity surf.SugoiSubordinateCore
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk             => clk,
         rst             => reset,
         rstL            => rstL,
         -- SUGOI Serial Ports
         rx              => rx,
         tx              => tx,
         -- Link Status
         linkup          => linkup,
         -- Trigger/Timing Command Bus
         opCode          => opCode,
         -- AXI-Lite Master Interface
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => clk,
         axiClkRst           => reset,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_Version : entity surf.AxiVersion
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => SIM_BUILD_INFO_C)
      port map (
         -- AXI-Lite Interface
         axiClk         => clk,
         axiRst         => reset,
         axiReadMaster  => axilReadMasters(0),
         axiReadSlave   => axilReadSlaves(0),
         axiWriteMaster => axilWriteMasters(0),
         axiWriteSlave  => axilWriteSlaves(0));

   U_TX : entity surf.OutputBufferReg
      generic map (
         TPD_G       => TPD_G,
         DIFF_PAIR_G => true)
      port map (
         I   => tx,
         C   => clk,
         dly => '1',                    -- deskew the data by half clock cycle
         O   => txP,
         OB  => txN);

   U_CLK_OUT : entity surf.ClkOutBufDiff
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => "ULTRASCALE")
      port map (
         clkIn   => clk,
         clkOutP => clkOutP,
         clkOutN => clkOutN);

end mapping;
