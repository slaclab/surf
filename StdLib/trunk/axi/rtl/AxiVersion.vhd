-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-20
-- Last update: 2015-10-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible registers containing configuration
-- information.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      AXI_ERROR_RESP_G   : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      CLK_PERIOD_G       : real                   := 8.0E-9;     -- units of seconds
      XIL_DEVICE_G       : string                 := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      EN_DEVICE_DNA_G    : boolean                := false;
      EN_DS2411_G        : boolean                := false;
      EN_ICAP_G          : boolean                := false;
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
      -- Optional: Serial Number outputs
      dnaValueOut    : out   slv(63 downto 0);
      fdSerialOut    : out   slv(63 downto 0);
      -- Optional: user values
      userValues     : in    Slv32Array(0 to 63) := (others => X"00000000");
      -- Optional: DS2411 interface
      fdSerSdio      : inout sl                  := 'Z');
end AxiVersion;

architecture rtl of AxiVersion is

   constant RELOAD_COUNT_C : integer := integer(AUTO_RELOAD_TIME_G / CLK_PERIOD_G);

   type RomType is array (0 to 63) of slv(31 downto 0);

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

   signal stringRom : RomType := makeStringRom;


   type RegType is record
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
   
begin

   dnaValueOut <= dnaValue;
   fdSerialOut <= fdSerial;

   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G) generate
      DeviceDna_1 : entity work.DeviceDna
         generic map (
            TPD_G        => TPD_G,
            XIL_DEVICE_G => XIL_DEVICE_G)
         port map (
            clk      => axiClk,
            rst      => axiRst,
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
            TPD_G        => TPD_G,
            XIL_DEVICE_G => XIL_DEVICE_G)
         port map (
            clk         => axiClk,
            rst         => axiRst,
            start       => r.fpgaReload,
            bootAddress => r.fpgaReloadAddr);
   end generate;

   comb : process (axiReadMaster, axiRst, axiWriteMaster, dnaValid, dnaValue, fdSerial, fdValid,
                   fpgaEnReload, r, stringRom, userValues) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;

      -- Wrapper procedures to make calls cleaner.
      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv; cA : in boolean := false; cV : in slv := "0") is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg, cA, cV);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;


      procedure axiSlaveDefault (
         axiResp : in slv(1 downto 0)) is
      begin
         axiSlaveDefault(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, axiResp);
      end procedure;

   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.masterReset := '0';

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------      

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      axiSlaveRegisterR(X"000", 0, FPGA_VERSION_C);
      axiSlaveRegisterW(X"004", 0, v.scratchPad);
      axiSlaveRegisterR(X"008", 0, ite(dnaValid = '1', dnaValue(63 downto 32), X"00000000"));
      axiSlaveRegisterR(X"00C", 0, ite(dnaValid = '1', dnaValue(31 downto 0), X"00000000"));
      axiSlaveRegisterR(X"010", 0, ite(fdValid = '1', fdSerial(63 downto 32), X"00000000"));
      axiSlaveRegisterR(X"014", 0, ite(fdValid = '1', fdSerial(31 downto 0), X"00000000"));
      axiSlaveRegisterW(X"018", 0, v.masterReset);

      axiSlaveRegisterW(X"01C", 0, v.fpgaReload);
      axiSlaveRegisterW(X"020", 0, v.fpgaReloadAddr);
      axiSlaveRegisterW(X"024", 0, v.counter, true, X"00000000");
      axiSlaveRegisterW(X"028", 0, v.haltReload);

      axiSlaveRegisterR("01----------", 0, userValues(conv_integer(axiReadMaster.araddr(7 downto 2))));
      axiSlaveRegisterR("10----------", 0, stringRom(conv_integer(axiReadMaster.araddr(7 downto 2))));

      axiSlaveDefault(AXI_ERROR_RESP_G);

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
