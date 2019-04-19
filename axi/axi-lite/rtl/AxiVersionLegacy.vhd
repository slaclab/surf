-------------------------------------------------------------------------------
-- File       : AxiVersionLegacy.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible registers containing configuration
-- information. This is a legacy version for backward compatibility.
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiVersionLegacy is
   generic (
      TPD_G              : time             := 1 ns;
      BUILD_INFO_G       : BuildInfoType;
      SIM_DNA_VALUE_G    : slv              := X"000000000000000000000000";
      DEVICE_ID_G        : slv(31 downto 0) := (others => '0');
      CLK_PERIOD_G       : real             := 8.0E-9;     -- units of seconds
      XIL_DEVICE_G       : string           := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      EN_DEVICE_DNA_G    : boolean          := false;
      EN_DS2411_G        : boolean          := false;
      EN_ICAP_G          : boolean          := false;
      USE_SLOWCLK_G      : boolean          := false;
      BUFR_CLK_DIV_G     : positive         := 8;
      AUTO_RELOAD_EN_G   : boolean          := false;
      AUTO_RELOAD_TIME_G : positive         := 10;         -- units of seconds
      AUTO_RELOAD_ADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      -- AXI-Lite Interface
      axiClk         : in    sl;
      axiRst         : in    sl;
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Optional: User Reset
      userReset      : out   sl;
      -- Optional: FPGA Reloading Interface
      fpgaEnReload   : in    sl                  := '1';
      fpgaReload     : out   sl;
      fpgaReloadAddr : out   slv(31 downto 0);
      upTimeCnt      : out   slv(31 downto 0);
      -- Optional: Serial Number outputs
      slowClk        : in    sl                  := '0';
      dnaValueOut    : out   slv(127 downto 0);
      fdValueOut     : out   slv(63 downto 0);
      -- Optional: user values
      userValues     : in    Slv32Array(0 to 63) := (others => X"00000000");
      -- Optional: DS2411 interface
      fdSerSdio      : inout sl                  := 'Z');
end AxiVersionLegacy;

architecture rtl of AxiVersionLegacy is

   constant TIMEOUT_1HZ_C  : natural          := (getTimeRatio(1.0, CLK_PERIOD_G) -1);
   constant COUNTER_ZERO_C : slv(31 downto 0) := X"00000000";

   constant BUILD_INFO_C       : BuildInfoRetType    := toBuildInfo(BUILD_INFO_G);
   constant BUILD_STRING_ROM_C : Slv32Array(0 to 63) := BUILD_INFO_C.buildString;

   type RegType is record
      upTimeCnt      : slv(31 downto 0);
      timer          : natural range 0 to TIMEOUT_1HZ_C;
      scratchPad     : slv(31 downto 0);
      reloadTimer    : slv(31 downto 0);
      userReset      : sl;
      fpgaReload     : sl;
      haltReload     : sl;
      fpgaReloadAddr : slv(31 downto 0);
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      upTimeCnt      => (others => '0'),
      timer          => 0,
      scratchPad     => (others => '0'),
      reloadTimer    => (others => '0'),
      userReset      => '1',            -- Asserted on powerup
      fpgaReload     => '0',
      haltReload     => '0',
      fpgaReloadAddr => AUTO_RELOAD_ADDR_G,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValue : slv(127 downto 0) := (others => '0');
   signal fdValue  : slv(63 downto 0)  := (others => '0');

   attribute rom_style                         : string;
   attribute rom_style of BUILD_STRING_ROM_C   : constant is "distributed";
   attribute rom_extract                       : string;
   attribute rom_extract of BUILD_STRING_ROM_C : constant is "TRUE";
   attribute syn_keep                          : string;
   attribute syn_keep of BUILD_STRING_ROM_C    : constant is "TRUE";

begin

   dnaValueOut <= dnaValue;
   fdValueOut  <= fdValue;

   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G) generate
      DeviceDna_1 : entity work.DeviceDna
         generic map (
            TPD_G           => TPD_G,
            USE_SLOWCLK_G   => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G  => BUFR_CLK_DIV_G,
            XIL_DEVICE_G    => XIL_DEVICE_G,
            SIM_DNA_VALUE_G => SIM_DNA_VALUE_G)
         port map (
            clk      => axiClk,
            rst      => axiRst,
            slowClk  => slowClk,
            dnaValue => dnaValue);
   end generate GEN_DEVICE_DNA;

   GEN_DS2411 : if (EN_DS2411_G) generate
      DS2411Core_1 : entity work.DS2411Core
         generic map (
            TPD_G        => TPD_G,
            CLK_PERIOD_G => CLK_PERIOD_G)
         port map (
            clk       => axiClk,
            rst       => axiRst,
            fdSerSdio => fdSerSdio,
            fdValue   => fdValue);
   end generate GEN_DS2411;

   GEN_ICAP : if (EN_ICAP_G) generate
      Iprog_1 : entity work.Iprog
         generic map (
            TPD_G          => TPD_G,
            USE_SLOWCLK_G  => USE_SLOWCLK_G,
            BUFR_CLK_DIV_G => BUFR_CLK_DIV_G,
            XIL_DEVICE_G   => XIL_DEVICE_G)
         port map (
            clk         => axiClk,
            rst         => axiRst,
            slowClk     => slowClk,
            start       => r.fpgaReload,
            bootAddress => r.fpgaReloadAddr);
   end generate;

   comb : process (axiReadMaster, axiRst, axiWriteMaster, dnaValue, fdValue,
                   fpgaEnReload, r, userValues) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      axiSlaveRegisterR(axilEp, X"000", 0, BUILD_INFO_C.fwVersion);
      axiSlaveRegister(axilEp, X"004", 0, v.scratchPad);
      axiSlaveRegisterR(axilEp, X"008", 0, dnaValue(63 downto 0));
      axiSlaveRegisterR(axilEp, X"010", 0, fdValue);
      axiSlaveRegister(axilEp, X"018", 0, v.userReset);

      axiSlaveRegister(axilEp, X"01C", 0, v.fpgaReload);
      axiSlaveRegister(axilEp, X"020", 0, v.fpgaReloadAddr);
      axiSlaveRegister(axilEp, X"024", 0, v.reloadTimer, COUNTER_ZERO_C);
      axiSlaveRegister(axilEp, X"028", 0, v.haltReload);
      axiSlaveRegisterR(axilEp, X"02C", 0, r.upTimeCnt);
      axiSlaveRegisterR(axilEp, X"030", 0, DEVICE_ID_G);

      axiSlaveRegisterR(axilEp, X"100", 0, BUILD_INFO_C.gitHash(63 downto 32));

      axiSlaveRegisterR(axilEp, X"400", userValues);
      axiSlaveRegisterR(axilEp, X"800", BUILD_STRING_ROM_C);

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axiWriteSlave, v.axiReadSlave, AXI_RESP_DECERR_C);

      ---------------------------------
      -- Uptime counter
      ---------------------------------      
      if r.timer = TIMEOUT_1HZ_C then
         -- Reset the counter
         v.timer := 0;

         -- Increment the Counter
         v.upTimeCnt := r.upTimeCnt + 1;

         ---------------------------------
         -- First Stage Boot Loader (FSBL)
         ---------------------------------
         -- Check if timer enabled
         if (fpgaEnReload = '1') and (r.reloadTimer /= AUTO_RELOAD_TIME_G) then
            v.reloadTimer := r.reloadTimer + 1;
         end if;

         -- Check for reload condition
         if AUTO_RELOAD_EN_G and (r.reloadTimer = AUTO_RELOAD_TIME_G) and (fpgaEnReload = '1') and (r.haltReload = '0') then
            v.fpgaReload := '1';
         end if;

      else
         v.timer := r.timer + 1;
      end if;

      --------
      -- Reset
      --------
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      fpgaReload     <= r.fpgaReload;
      fpgaReloadAddr <= r.fpgaReloadAddr;
      userReset      <= r.userReset;
      upTimeCnt      <= r.upTimeCnt;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
