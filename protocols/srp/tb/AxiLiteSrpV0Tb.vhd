-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation testbed for AxiLiteSrpV0
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
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

----------------------------------------------------------------------------------------------------

entity AxiLiteSrpV0Tb is

end entity AxiLiteSrpV0Tb;

----------------------------------------------------------------------------------------------------

architecture tb of AxiLiteSrpV0Tb is

   -- component generics
   constant TPD_G               : time                       := 1 ns;
   constant RESP_THOLD_G        : integer range 0 to (2**24) := 1;
   constant SLAVE_READY_EN_G    : boolean                    := true;
   constant MEMORY_TYPE_G       : string                     := "block";
   constant GEN_SYNC_FIFO_G     : boolean                    := false;
   constant FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
   constant FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 2**8;
   constant AXI_STREAM_CONFIG_G : AxiStreamConfigType        := EMAC_AXIS_CONFIG_C;

   -- component ports
   signal axisClk            : sl;      -- [in]
   signal axisRst            : sl                     := '0';  -- [in]
   signal txAxisMaster       : AxiStreamMasterType;            -- [out]
   signal txAxisSlave        : AxiStreamSlaveType;             -- [in]
   signal rxAxisMaster       : AxiStreamMasterType;            -- [in]
   signal rxAxisSlave        : AxiStreamSlaveType;             -- [out]
   signal rxAxisCtrl         : AxiStreamCtrlType;              -- [out]
   signal axilClk            : sl;      -- [in]
   signal axilRst            : sl;      -- [in]
   signal uutAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [in]
   signal uutAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;  -- [out]
   signal uutAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;  -- [in]
   signal uutAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;  -- [out]
   signal srpAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [in]
   signal srpAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;  -- [out]
   signal srpAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;  -- [in]
   signal srpAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;  -- [out]

begin

   -------------------------------------------------------------------------------------------------
   -- Create clocks
   -------------------------------------------------------------------------------------------------
   U_ClkRst_AXIS : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axisClk,
         rst  => axisRst);

   U_ClkRst_AXIL : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 8.0 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axilClk,
         rst  => axilRst);

   ----------------------------------------------------------------------------------------------
   -- Instantiate UUT
   ----------------------------------------------------------------------------------------------
   U_AxiLiteSrpV0 : entity surf.AxiLiteSrpV0
      generic map (
         TPD_G               => TPD_G,
         RESP_THOLD_G        => RESP_THOLD_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         mAxisClk         => axisClk,             -- [in]
         mAxisRst         => axisRst,             -- [in]
         mAxisMaster      => txAxisMaster,        -- [out]
         mAxisSlave       => txAxisSlave,         -- [in]
         sAxisClk         => axisClk,             -- [in]
         sAxisRst         => axisRst,             -- [in]
         sAxisMaster      => rxAxisMaster,        -- [in]
         sAxisSlave       => rxAxisSlave,         -- [out]
         sAxisCtrl        => rxAxisCtrl,          -- [out]
         axilClk          => axilClk,             -- [in]
         axilRst          => axilRst,             -- [in]
         sAxilWriteMaster => uutAxilWriteMaster,  -- [in]
         sAxilWriteSlave  => uutAxilWriteSlave,   -- [out]
         sAxilReadMaster  => uutAxilReadMaster,   -- [in]
         sAxilReadSlave   => uutAxilReadSlave);   -- [out]


   -------------------------------------------------------------------------------------------------
   -- Connect to SrpV0AxiLite
   -------------------------------------------------------------------------------------------------
   U_SrpV0AxiLite_1 : entity surf.SrpV0AxiLite
      generic map (
         TPD_G               => TPD_G,
         RESP_THOLD_G        => RESP_THOLD_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         EN_32BIT_ADDR_G     => true,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         sAxisClk            => axisClk,             -- [in]
         sAxisRst            => axisRst,             -- [in]
         sAxisMaster         => txAxisMaster,        -- [in]
         sAxisSlave          => txAxisSlave,         -- [out]
         sAxisCtrl           => open,                -- [out]
         mAxisClk            => axisClk,             -- [in]
         mAxisRst            => axisRst,             -- [in]
         mAxisMaster         => rxAxisMaster,        -- [out]
         mAxisSlave          => rxAxisSlave,         -- [in]
         axiLiteClk          => axilClk,             -- [in]
         axiLiteRst          => axilRst,             -- [in]
         mAxiLiteWriteMaster => srpAxilWriteMaster,  -- [out]
         mAxiLiteWriteSlave  => srpAxilWriteSlave,   -- [in]
         mAxiLiteReadMaster  => srpAxilReadMaster,   -- [out]
         mAxiLiteReadSlave   => srpAxilReadSlave);   -- [in]

   -------------------------------------------------------------------------------------------------
   -- Connect SrpV0AxiLite to a RAM
   -------------------------------------------------------------------------------------------------
   U_AxiDualPortRam_1 : entity surf.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_WR_EN_G      => true,
         SYS_WR_EN_G      => false,
         SYS_BYTE_WR_EN_G => false,
         COMMON_CLK_G     => true,
         ADDR_WIDTH_G     => 12,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => axilClk,             -- [in]
         axiRst         => axilRst,             -- [in]
         axiReadMaster  => srpAxilReadMaster,   -- [in]
         axiReadSlave   => srpAxilReadSlave,    -- [out]
         axiWriteMaster => srpAxilWriteMaster,  -- [in]
         axiWriteSlave  => srpAxilWriteSlave);  -- [out]

   -------------------------------------------------------------------------------------------------
   -- Test process
   -------------------------------------------------------------------------------------------------
   test : process is
      variable data : slv(31 downto 0);
   begin
      wait until axilRst = '1';
      wait until axilRst = '0';
      wait for 1 us;

      for i in 0 to 256 loop

         -- Write AXI-Lite Transaction
         axiLiteBusSimWrite (axilClk, uutAxilWriteMaster, uutAxilWriteSlave, toSlv(4*i, 32), toSlv(i, 32), true);

         -- Read AXI-Lite Transaction
         axiLiteBusSimRead (axilClk, uutAxilReadMaster, uutAxilReadSlave, toSlv(4*i, 32), data, true);

         -- Check for failure
         if (data /= i) then
            -- Simulation failed
            assert false report "Simulation Failed!" severity failure;
         end if;

      end loop;

      -- Simulation Passed
      assert false report "Simulation Passed!" severity failure;

   end process test;

end architecture tb;

----------------------------------------------------------------------------------------------------
