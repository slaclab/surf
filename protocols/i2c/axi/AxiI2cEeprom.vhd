-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for AxiI2cEepromCore
--
-- Supported Devices:
--    24AA01F/24LC01F/24FC01F    (1kb:   ADDR_WIDTH_G = 7)
--    24AA02F/24LC02F/24FC02F    (2kb:   ADDR_WIDTH_G = 8)
--    24AA04F/24LC04F/24FC04F    (4kb:   ADDR_WIDTH_G = 9)
--    24AA08F/24LC08F/24FC08F    (8kb:   ADDR_WIDTH_G = 10)
--    24AA16F/24LC16F/24FC16F    (16kb:  ADDR_WIDTH_G = 11)
--    24AA32F/24LC32F/24FC32F    (32kb:  ADDR_WIDTH_G = 12)
--    24AA64F/24LC64F/24FC64F    (64kb:  ADDR_WIDTH_G = 13)
--    24AA128F/24LC128F/24FC128F (128kb: ADDR_WIDTH_G = 14)
--    24AA256F/24LC256F/24FC256F (256kb: ADDR_WIDTH_G = 15)
--    24AA512F/24LC512F/24FC512F (512kb: ADDR_WIDTH_G = 16)
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

entity AxiI2cEeprom is
   generic (
      TPD_G           : time            := 1 ns;
      AXIL_PROXY_G    : boolean         := false;
      ADDR_WIDTH_G    : positive        := 16;
      POLL_TIMEOUT_G  : positive        := 16;
      I2C_ADDR_G      : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G  : real            := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real            := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real            := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      scl             : inout sl;
      sda             : inout sl;
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axilClk         : in    sl;
      axilRst         : in    sl);
end AxiI2cEeprom;

architecture mapping of AxiI2cEeprom is

   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

   signal proxyReadMaster  : AxiLiteReadMasterType;
   signal proxyReadSlave   : AxiLiteReadSlaveType;
   signal proxyWriteMaster : AxiLiteWriteMasterType;
   signal proxyWriteSlave  : AxiLiteWriteSlaveType;

begin

   BYP_PROXY : if (AXIL_PROXY_G = false) generate
      proxyReadMaster  <= axilReadMaster;
      axilReadSlave    <= proxyReadSlave;
      proxyWriteMaster <= axilWriteMaster;
      axilWriteSlave   <= proxyWriteSlave;
   end generate BYP_PROXY;

   GEN_PROXY : if (AXIL_PROXY_G = true) generate
      U_AxiLiteMasterProxy : entity surf.AxiLiteMasterProxy
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clocks and Resets
            axiClk          => axilClk,
            axiRst          => axilRst,
            -- AXI-Lite Register Interface
            sAxiReadMaster  => axilReadMaster,
            sAxiReadSlave   => axilReadSlave,
            sAxiWriteMaster => axilWriteMaster,
            sAxiWriteSlave  => axilWriteSlave,
            -- AXI-Lite Register Interface
            mAxiReadMaster  => proxyReadMaster,
            mAxiReadSlave   => proxyReadSlave,
            mAxiWriteMaster => proxyWriteMaster,
            mAxiWriteSlave  => proxyWriteSlave);
   end generate GEN_PROXY;

   U_AxiI2cEepromCore : entity surf.AxiI2cEepromCore
      generic map (
         TPD_G           => TPD_G,
         ADDR_WIDTH_G    => ADDR_WIDTH_G,
         POLL_TIMEOUT_G  => POLL_TIMEOUT_G,
         I2C_ADDR_G      => I2C_ADDR_G,
         I2C_SCL_FREQ_G  => I2C_SCL_FREQ_G,
         I2C_MIN_PULSE_G => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G  => AXI_CLK_FREQ_G)
      port map (
         -- I2C Interface
         i2ci            => i2ci,
         i2co            => i2co,
         -- AXI-Lite Register Interface
         axilReadMaster  => proxyReadMaster,
         axilReadSlave   => proxyReadSlave,
         axilWriteMaster => proxyWriteMaster,
         axilWriteSlave  => proxyWriteSlave,
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst);

   IOBUF_SCL : entity surf.IoBufWrapper
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);  -- 3-state enable input, high=input, low=output

   IOBUF_SDA : entity surf.IoBufWrapper
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);  -- 3-state enable input, high=input, low=output

end mapping;
