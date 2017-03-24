-------------------------------------------------------------------------------
-- File       : AxiLiteAsyncTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-11
-- Last update: 2016-05-11
-------------------------------------------------------------------------------
-- Description: Testbench for design "AxiLiteAsync"
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
use work.TextUtilPkg.all;
use work.AxiLitePkg.all;

----------------------------------------------------------------------------------------------------

entity AxiLiteAsyncTb is

end entity AxiLiteAsyncTb;

----------------------------------------------------------------------------------------------------

architecture tb of AxiLiteAsyncTb is

   -- component generics
   constant TPD_G           : time                  := 1 ns;
   constant NUM_ADDR_BITS_G : natural               := 32;
   constant PIPE_STAGES_G   : integer range 0 to 16 := 0;

   -- component ports
   signal sAxiClk          : sl;        -- [in]
   signal sAxiClkRst       : sl;        -- [in]
   signal sAxiReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;  -- [in]
   signal sAxiReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;  -- [out]
   signal sAxiWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [in]
   signal sAxiWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;  -- [out]
   signal mAxiClk          : sl;        -- [in]
   signal mAxiClkRst       : sl;        -- [in]
   signal mAxiReadMaster   : AxiLiteReadMasterType               := AXI_LITE_READ_MASTER_INIT_C;  -- [out]
   signal mAxiReadSlave    : AxiLiteReadSlaveType                := AXI_LITE_READ_SLAVE_INIT_C;  -- [in]
   signal mAxiWriteMaster  : AxiLiteWriteMasterType              := AXI_LITE_WRITE_MASTER_INIT_C;  -- [out]
   signal mAxiWriteSlave   : AxiLiteWriteSlaveType               := AXI_LITE_WRITE_SLAVE_INIT_C;  -- [in]

   signal intAxiReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;  -- [out]
   signal intAxiReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;  -- [in]
   signal intAxiWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [out]
   signal intAxiWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;  -- [in]
begin

   U_AxiLiteCrossbar_1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 1,
         DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
         MASTERS_CONFIG_G   => (
            0               => (
               baseAddr     => X"00000000",
               addrBits     => 12,
               connectivity => (others => '1'))),
         DEBUG_G            => true)
      port map (
         axiClk           => sAxiClk,             -- [in]
         axiClkRst        => sAxiClkRst,          -- [in]
         sAxiWriteMasters(0) => sAxiWriteMaster,    -- [in]
         sAxiWriteSlaves(0)  => sAxiWriteSlave,     -- [out]
         sAxiReadMasters(0)  => sAxiReadMaster,     -- [in]
         sAxiReadSlaves(0)   => sAxiReadSlave,      -- [out]
         mAxiWriteMasters(0) => intAxiWriteMaster,  -- [out]
         mAxiWriteSlaves(0)  => intAxiWriteSlave,   -- [in]
         mAxiReadMasters(0)  => intAxiReadMaster,   -- [out]
         mAxiReadSlaves(0)   => intAxiReadSlave);   -- [in]

   -- component instantiation
   U_AxiLiteAsync : entity work.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         NUM_ADDR_BITS_G => NUM_ADDR_BITS_G,
         PIPE_STAGES_G   => PIPE_STAGES_G)
      port map (
         sAxiClk         => sAxiClk,                -- [in]
         sAxiClkRst      => sAxiClkRst,             -- [in]
         sAxiReadMaster  => intAxiReadMaster,   -- [in]
         sAxiReadSlave   => intAxiReadSlave,    -- [out]
         sAxiWriteMaster => intAxiWriteMaster,  -- [in]
         sAxiWriteSlave  => intAxiWriteSlave,   -- [out]
         mAxiClk         => mAxiClk,                -- [in]
         mAxiClkRst      => mAxiClkRst,             -- [in]
         mAxiReadMaster  => mAxiReadMaster,         -- [out]
         mAxiReadSlave   => mAxiReadSlave,          -- [in]
         mAxiWriteMaster => mAxiWriteMaster,        -- [out]
         mAxiWriteSlave  => mAxiWriteSlave);        -- [in]

   U_AxiDualPortRam_1 : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
--         MODE_G           => MODE_G,
         AXI_WR_EN_G      => true,
         SYS_WR_EN_G      => false,
         SYS_BYTE_WR_EN_G => false,
         COMMON_CLK_G     => true,
         ADDR_WIDTH_G     => 10,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => mAxiClk,          -- [in]
         axiRst         => mAxiClkRst,       -- [in]
         axiReadMaster  => mAxiReadMaster,   -- [in]
         axiReadSlave   => mAxiReadSlave,    -- [out]
         axiWriteMaster => mAxiWriteMaster,  -- [in]
         axiWriteSlave  => mAxiWriteSlave);  -- [out]


   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 8 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 1 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => sAxiClk,
         rst  => sAxiClkRst);

   U_ClkRst_2 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 5 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 20 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => mAxiClk,
         rst  => mAxiClkRst);

   test : process is
      variable addr : slv(31 downto 0) := (others => '0');
      variable data : slv(31 downto 0) := (others => '0');
   begin
      wait until sAxiClkRst = '1';
      wait until sAxiClkRst = '0';


      wait for 5 us;
      wait until sAxiClk = '1';

      data := X"11111111";
      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000000", X"11111111", true);
      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000004", X"22222222", true);
      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000008", X"33333333", true);

      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000000", data, true);
      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000004", data, true);
      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000008", data, true);

      wait until mAxiClkRst = '0';
      wait for 10 us;
      wait until sAxiClk = '1';

      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000000", X"11111111", true);
      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000004", X"22222222", true);
      axiLiteBusSimWrite(sAxiClk, sAxiWriteMaster, sAxiWriteSlave, X"00000008", X"33333333", true);

      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000000", data, true);
      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000004", data, true);
      axiLiteBusSimRead(sAxiClk, sAxiReadMaster, sAxiReadSlave, X"00000008", data, true);

   end process test;


end architecture tb;

----------------------------------------------------------------------------------------------------
