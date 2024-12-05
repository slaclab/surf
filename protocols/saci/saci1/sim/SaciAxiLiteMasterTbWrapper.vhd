-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: surf.AxiLiteCrossbar cocoTB testbed
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

entity SaciAxiLiteMasterTbWrapper is
end SaciAxiLiteMasterTbWrapper;

architecture mapping of SaciAxiLiteMasterTbWrapper is

   signal axilClk  : sl;
   signal axilRstL : sl;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;


begin

   U_SaciAxiLiteMasterTb_1 : entity surf.SaciAxiLiteMasterTb
      port map (
         S_AXI_ACLK    => axilClk,                  -- [in]
         S_AXI_ARESETN => axilRstL,                 -- [in]
         S_AXI_AWADDR  => axilWriteMaster.awaddr,   -- [in]
         S_AXI_AWPROT  => axilWriteMaster.awprot,   -- [in]
         S_AXI_AWVALID => axilWriteMaster.awvalid,  -- [in]
         S_AXI_AWREADY => axilWriteSlave.awready,   -- [out]
         S_AXI_WDATA   => axilWriteMaster.wdata,    -- [in]
         S_AXI_WSTRB   => axilWriteMaster.wstrb,    -- [in]
         S_AXI_WVALID  => axilWriteMaster.wvalid,   -- [in]
         S_AXI_WREADY  => axilWriteSlave.WREADY,    -- [out]
         S_AXI_BRESP   => axilWriteSlave.BRESP,     -- [out]
         S_AXI_BVALID  => axilWriteSlave.BVALID,    -- [out]
         S_AXI_BREADY  => axilWriteMaster.BREADY,   -- [in]
         S_AXI_ARADDR  => axilReadMaster.ARADDR,    -- [in]
         S_AXI_ARPROT  => axilReadMaster.ARPROT,    -- [in]
         S_AXI_ARVALID => axilReadMaster.ARVALID,   -- [in]
         S_AXI_ARREADY => axilReadSlave.ARREADY,    -- [out]
         S_AXI_RDATA   => axilReadSlave.RDATA,      -- [out]
         S_AXI_RRESP   => axilReadSlave.RRESP,      -- [out]
         S_AXI_RVALID  => axilReadSlave.RVALID,     -- [out]
         S_AXI_RREADY  => axilReadMaster.RREADY);   -- [in]

   U_ClkRst_2 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G => 8.0 ns,
         CLK_DELAY_G  => 3.2 ns)
      port map (
         clkP => axilClk,               -- [out]
         rstL => axilRstL);             -- [out]

   process is
      variable wrData : slv(31 downto 0);
      variable rdData : slv(31 downto 0);
   begin
      wait for 10 us;
      wait until axilClk = '1';
      wait until axilClk = '1';
      wait until axilClk = '1';

      wrData := X"12345678";
      axiLiteBusSimWrite(
         axilClk,
         axilWriteMaster,
         axilWriteSlave,
         X"00000000",
         wrData);

      axiLiteBusSimRead(
         axilClk,
         axilReadMaster,
         axilReadSlave,
         X"00000000",
         rdData);

      assert (wrData = rdData) report "Data Mismatch" severity error;

      wrData := X"9abcdef0";
      axiLiteBusSimWrite(
         axilClk,
         axilWriteMaster,
         axilWriteSlave,
         X"00000004",
         wrData);

      axiLiteBusSimRead(
         axilClk,
         axilReadMaster,
         axilReadSlave,
         X"00000004",
         rdData);

      assert (wrData = rdData) report "Data Mismatch" severity error;


      wrData := X"deadbeef";
      axiLiteBusSimWrite(
         axilClk,
         axilWriteMaster,
         axilWriteSlave,
         X"00100008",
         wrData);

      axiLiteBusSimRead(
         axilClk,
         axilReadMaster,
         axilReadSlave,
         X"00100008",
         rdData);

      assert (wrData = rdData) report "Data Mismatch" severity error;



      wait until axilClk = '1';
      wait;

   end process;



end mapping;
