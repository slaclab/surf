-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-20
-- Last update: 2016-07-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible registers containing configuration
-- information.
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
use work.Version.all;
--use work.TextUtilPkg.all;

entity AxiVersion is
   generic (
      TPD_G              : time                   := 1 ns;
      SIM_DNA_VALUE_G    : slv                    := X"000000000000000000000000";
      AXI_ERROR_RESP_G   : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      DEVICE_ID_G        : slv(31 downto 0)       := (others => '0');
      CLK_PERIOD_G       : real                   := 8.0E-9;     -- units of seconds
      XIL_DEVICE_G       : string                 := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      EN_DEVICE_DNA_G    : boolean                := false;
      EN_DS2411_G        : boolean                := false;
      EN_ICAP_G          : boolean                := false;
      USE_SLOWCLK_G      : boolean                := false;
      BUFR_CLK_DIV_G     : positive               := 8;
      AUTO_RELOAD_EN_G   : boolean                := false;
      AUTO_RELOAD_TIME_G : real range 0.0 to 30.0 := 10.0;       -- units of seconds
      AUTO_RELOAD_ADDR_G : slv(31 downto 0)       := (others => '0'));
   port (
      -- AXI-Lite Interface
      axiClk         : in    sl;
      axiRst         : in    sl;
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Optional: Master Reset
      masterReset    : out   sl;
      -- Optional: FPGA Reloading Interface
      fpgaEnReload   : in    sl                  := '1';
      fpgaReload     : out   sl;
      fpgaReloadAddr : out   slv(31 downto 0);
      upTimeCnt      : out   slv(31 downto 0);
      -- Optional: Serial Number outputs
      slowClk        : in    sl                  := '0';
      dnaValueOut    : out   slv(63 downto 0);
      fdSerialOut    : out   slv(63 downto 0);
      -- Optional: user values
      userValues     : in    Slv32Array(0 to 63) := (others => X"00000000");
      -- Optional: DS2411 interface
      fdSerSdio      : inout sl                  := 'Z');
end AxiVersion;

architecture rtl of AxiVersion is

   constant RELOAD_COUNT_C : integer := integer(AUTO_RELOAD_TIME_G / CLK_PERIOD_G);
   constant TIMEOUT_1HZ_C  : natural := (getTimeRatio(1.0, CLK_PERIOD_G) -1);

   subtype RomType is Slv32Array(0 to 63);

   function makeStringRom return RomType is
      variable ret : RomType := (others => (others => '0'));
      variable c   : character;
   begin
      for i in BUILD_STAMP_C'range loop
         c := BUILD_STAMP_C(i);
         ret((i-1)/4)(8*((i-1) mod 4)+7 downto 8*((i-1) mod 4)) :=
            toSlv(character'pos(c), 8);
      end loop;
      return ret;
   end function makeStringRom;

   constant STRING_ROM_C : RomType := makeStringRom;

   type RegType is record
      upTimeCnt      : slv(31 downto 0);
      timer          : natural range 0 to TIMEOUT_1HZ_C;
      scratchPad     : slv(31 downto 0);
      counter        : slv(31 downto 0);
      counterRst     : sl;
      masterReset    : sl;
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
      counter        => (others => '0'),
      counterRst     => '0',
      masterReset    => '0',
      fpgaReload     => '0',
      haltReload     => '0',
      fpgaReloadAddr => AUTO_RELOAD_ADDR_G,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValid     : sl               := '0';
   signal dnaValue     : slv(63 downto 0) := (others => '0');
   signal fdValid      : sl               := '0';
   signal fdSerial     : slv(63 downto 0) := (others => '0');
   signal masterRstDet : sl               := '0';
   signal asyncRst     : sl               := '0';

   attribute rom_style                   : string;
   attribute rom_style of STRING_ROM_C   : constant is "distributed";
   attribute rom_extract                 : string;
   attribute rom_extract of STRING_ROM_C : constant is "TRUE";
   attribute syn_keep                    : string;
   attribute syn_keep of STRING_ROM_C    : constant is "TRUE";

begin

   dnaValueOut <= dnaValue;
   fdSerialOut <= fdSerial;

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
            dnaValue => dnaValue,
            dnaValid => dnaValid);
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
            fdSerial  => fdSerial,
            fdValid   => fdValid);
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


   comb : process (axiReadMaster, axiRst, axiWriteMaster, dnaValid, dnaValue, fdSerial,
                   fpgaEnReload, r, userValues) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.masterReset := '0';

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------      

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      axiSlaveRegisterR(axilEp, X"000", 0, FPGA_VERSION_C);
      axiSlaveRegister(axilEp, X"004", 0, v.scratchPad);
      axiSlaveRegisterR(axilEp, X"008", 0, ite(dnaValid = '1', dnaValue, X"0000000000000000"));
      axiSlaveRegisterR(axilEp, X"010", 0, ite(fdValid = '1', fdSerial, X"0000000000000000"));
      axiSlaveRegister(axilEp, X"018", 0, v.masterReset);

      axiSlaveRegister(axilEp, X"01C", 0, v.fpgaReload);
      axiSlaveRegister(axilEp, X"020", 0, v.fpgaReloadAddr);
      axiSlaveRegister(axilEp, X"024", 0, v.counter, X"00000000");
      axiSlaveRegister(axilEp, X"028", 0, v.haltReload);
      axiSlaveRegisterR(axilEp, X"02C", 0, r.upTimeCnt);
      axiSlaveRegisterR(axilEp, X"030", 0, DEVICE_ID_G);

      axiSlaveRegisterR(axilEp, X"400", userValues);
      axiSlaveRegisterR(axilEp, X"800", STRING_ROM_C);

      axiSlaveDefault(axilEp, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);

      ---------------------------------
      -- Uptime counter
      ---------------------------------      
      if r.timer = TIMEOUT_1HZ_C then
         v.timer     := 0;
         v.upTimeCnt := r.upTimeCnt + 1;
      else
         v.timer := r.timer + 1;
      end if;

      ---------------------------------
      -- First Stage Boot Loader (FSBL)
      ---------------------------------

      -- Check if timer enabled
      if fpgaEnReload = '1' then
         v.counter := r.counter + 1;
      end if;

      -- Check for reload condition
      if AUTO_RELOAD_EN_G and (r.counter = RELOAD_COUNT_C) and (fpgaEnReload = '1') and (r.haltReload = '0') then
         v.fpgaReload := '1';
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
      masterRstDet   <= v.masterReset;
      upTimeCnt      <= r.upTimeCnt;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   asyncRst <= axiRst or masterRstDet;

   U_RstSync : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => axiClk,
         asyncRst => asyncRst,
         syncRst  => masterReset);

end architecture rtl;
