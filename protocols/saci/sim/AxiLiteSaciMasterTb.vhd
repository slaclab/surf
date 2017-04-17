-------------------------------------------------------------------------------
-- File       : AxiLiteSaciMasterTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-17
-- Last update: 2016-06-17
-------------------------------------------------------------------------------
-- Description: Simulation testbed for AxiLiteSaciMaster2
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
use work.AxiLitePkg.all;

----------------------------------------------------------------------------------------------------

entity AxiLiteSaciMasterTb is

end entity AxiLiteSaciMasterTb;

----------------------------------------------------------------------------------------------------

architecture sim of AxiLiteSaciMasterTb is

   -- component generics
   constant TPD_G              : time                  := 1 ns;
   constant AXIL_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_DECERR_C;
   constant AXIL_CLK_PERIOD_G  : real                  := 8.0e-9;
   constant AXIL_TIMEOUT_G     : real                  := 1.0E-3;
   constant SACI_CLK_PERIOD_G  : real                  := 1.0e-6;
   constant SACI_CLK_FREERUN_G : boolean               := false;
   constant SACI_NUM_CHIPS_G   : positive range 1 to 4 := 4;
   constant SACI_RSP_BUSSED_G  : boolean               := false;

   -- component ports
   signal saciClk         : sl;        
   signal saciCmd         : sl;        
   signal saciSelL        : slv(SACI_NUM_CHIPS_G-1 downto 0);  
   signal saciRsp         : slv(ite(SACI_RSP_BUSSED_G, 0, SACI_NUM_CHIPS_G-1) downto 0) := (others => '0');  
   signal axilClk         : sl;         
   signal axilRst         : sl;         
   signal axilRstL        : sl;
   signal axilReadMaster  : AxiLiteReadMasterType;             
   signal axilReadSlave   : AxiLiteReadSlaveType;              
   signal axilWriteMaster : AxiLiteWriteMasterType;            
   signal axilWriteSlave  : AxiLiteWriteSlaveType;             

   signal rstLoopL : slv(SACI_NUM_CHIPS_G-1 downto 0);
   signal exec     : slv(SACI_NUM_CHIPS_G-1 downto 0);
   signal ack      : slv(SACI_NUM_CHIPS_G-1 downto 0) := (others => '0');
   signal readL    : slv(SACI_NUM_CHIPS_G-1 downto 0);
   signal cmd      : slv7Array(SACI_NUM_CHIPS_G-1 downto 0);
   signal addr     : slv12Array(SACI_NUM_CHIPS_G-1 downto 0);
   signal wrData   : slv32Array(SACI_NUM_CHIPS_G-1 downto 0);
   signal rdData   : slv32Array(SACI_NUM_CHIPS_G-1 downto 0);

begin

   -- component instantiation
   U_AxiLiteSaciMaster2 : entity work.AxiLiteSaciMaster2
      generic map (
         TPD_G              => TPD_G,
         AXIL_ERROR_RESP_G  => AXIL_ERROR_RESP_G,
         AXIL_CLK_PERIOD_G  => AXIL_CLK_PERIOD_G,
         AXIL_TIMEOUT_G     => AXIL_TIMEOUT_G,
         SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
         SACI_CLK_FREERUN_G => SACI_CLK_FREERUN_G,
         SACI_NUM_CHIPS_G   => SACI_NUM_CHIPS_G,
         SACI_RSP_BUSSED_G  => SACI_RSP_BUSSED_G)
      port map (
         saciClk         => saciClk,          -- [out]
         saciCmd         => saciCmd,          -- [out]
         saciSelL        => saciSelL,         -- [out]
         saciRsp         => saciRsp,          -- [in]
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         axilReadMaster  => axilReadMaster,   -- [in]
         axilReadSlave   => axilReadSlave,    -- [out]
         axilWriteMaster => axilWriteMaster,  -- [in]
         axilWriteSlave  => axilWriteSlave);  -- [out]

   SLAVE_GEN : for i in 0 to SACI_NUM_CHIPS_G-1 generate
      U_SaciSlave2_1 : entity work.SaciSlave2
         generic map (
            TPD_G => TPD_G)
         port map (
            rstL     => axilRstL,       -- [in]
            saciClk  => saciClk,        -- [in]
            saciSelL => saciSelL(i),    -- [in]
            saciCmd  => saciCmd,        -- [in]
            saciRsp  => saciRsp(i),     -- [out]
            rstOutL  => rstLoopL(i),    -- [out]
            rstInL   => rstLoopL(i),    -- [in]
            exec     => exec(i),        -- [out]
            ack      => ack(i),         -- [in]
            readL    => readL(i),       -- [out]
            cmd      => cmd(i),         -- [out]
            addr     => addr(i),        -- [out]
            wrData   => wrData(i),      -- [out]
            rdData   => rdData(i));     -- [in]

      U_DualPortRam_1 : entity work.DualPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            BRAM_EN_G      => false,
            REG_EN_G       => false,
            DOA_REG_G      => false,
            DOB_REG_G      => false,
            MODE_G         => "read-first",
            BYTE_WR_EN_G   => false,
            DATA_WIDTH_G   => 32,
            ADDR_WIDTH_G   => 12)
         port map (
            clka  => saciClk,           -- [in]
            ena   => exec(i),           -- [in]
            wea   => readL(i),          -- [in]
            rsta  => axilRst,           -- [in]
            addra => addr(i),           -- [in]
            dina  => wrData(i),         -- [in]
            douta => rdData(i));        -- [out]

      ackproc : process is
      begin
         wait until saciClk = '1';
         if (exec(i) = '1') then
            for i in 0 to 20 loop
               wait until saciClk = '1';
            end loop;
            ack(i) <= '1';
            wait until saciClk = '1';
            ack(i) <= '0';
         end if;
      end process;
   end generate SLAVE_GEN;

   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 8 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axilClk,
         rst  => axilRst,
         rstL => axilRstL);

   AXIL : process is
      variable axilAddr : slv(31 downto 0);
      variable data     : slv(31 downto 0);
   begin

      wait until axilRst = '1';
      axilWriteMaster <= AXI_LITE_WRITE_MASTER_INIT_C;
      axilReadMaster  <= AXI_LITE_READ_MASTER_INIT_C;
      wait until axilRst = '0';
      wait for 1 us;
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00000000", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00000000", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00000004", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00000004", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00000004", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00000FFC", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00000FFC", X"abcdef12", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00000FFC", data, true);

      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00400000", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00400000", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00400004", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00400004", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00400004", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00400FFC", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00400FFC", X"abcdef12", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00400FFC", data, true);

      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00800000", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00800000", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00800004", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00800004", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00800004", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00800FFC", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00800FFC", X"abcdef12", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00800FFC", data, true);

      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00C00000", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00C00000", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00C00004", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00C00004", X"12345678", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00C00004", data, true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00C00FFC", data, true);
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, X"00C00FFC", X"abcdef12", true);
      axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, X"00C00FFC", data, true);
      wait;
   end process;

end architecture sim;

----------------------------------------------------------------------------------------------------
