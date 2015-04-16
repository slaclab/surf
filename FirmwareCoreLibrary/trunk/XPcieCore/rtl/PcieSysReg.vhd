-------------------------------------------------------------------------------
-- Title      : PCIe Core
-------------------------------------------------------------------------------
-- File       : PcieSysReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PCIe System Registers
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.PciePkg.all;
use work.Version.all;

entity PcieSysReg is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 32 := 1;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_SLVERR_C);      
   port (
      -- PCIe Interface
      cfgFromPci     : in  PcieCfgOutType;
      irqActive      : in  sl;
      irqEnable      : out  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- System Signals
      serialNumber   : in  slv(63 downto 0);
      cardRst        : out sl;
      cntRst         : out sl;
      reboot         : out sl;
      rebootAddr     : out slv(31 downto 0);
      dmaLoopback    : out slv(DMA_SIZE_G-1 downto 0);
      -- Global Signals
      pciClk         : in  sl;
      pciRst         : in  sl); 
end PcieSysReg;

architecture rtl of PcieSysReg is

   constant MAX_CNT_C : natural := getTimeRatio(125.0E+6, 1.0);

   type RomType is array (0 to 63) of slv(31 downto 0);
   function makeStringRom return RomType is
      variable ret : RomType := (others => (others => '0'));
      variable c   : character;
   begin
      for i in BUILD_STAMP_C'range loop
         c                                                      := BUILD_STAMP_C(i);
         ret((i-1)/4)(8*((i-1) mod 4)+7 downto 8*((i-1) mod 4)) := toSlv(character'pos(c), 8);
      end loop;
      return ret;
   end function makeStringRom;
   signal buildStampString : RomType := makeStringRom;

   type RegType is record
      cardRst       : sl;
      cntRst        : sl;
      rebootEn      : sl;
      reboot        : sl;
      rebootAddr    : slv(31 downto 0);
      rebootTimer   : natural range 0 to MAX_CNT_C;
      irqEnable     : sl;
      dmaLoopback    : slv(DMA_SIZE_G-1 downto 0);
      scratchPad    : slv(31 downto 0);
      -- AXI-Lite
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      cardRst       => '1',
      cntRst        => '0',
      rebootEn      => '0',
      reboot        => '0',
      rebootAddr    => (others => '0'),
      rebootTimer   => 0,
      irqEnable     => '0',
      dmaLoopback    => (others => '0'),
      scratchPad    => (others => '0'),
      -- AXI-Lite
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, buildStampString, cfgFromPci, irqActive, pciRst,
                   r, serialNumber) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable rdPntr    : natural;

      -- Wrapper procedures to make calls cleaner.
      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
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

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Calculate the address pointers
      rdPntr := conv_integer(axiReadMaster.araddr(7 downto 2));

      axiSlaveRegisterR(X"000", 0, FPGA_VERSION_C);
      axiSlaveRegisterR(X"004", 0, serialNumber(63 downto 32));
      axiSlaveRegisterR(X"008", 0, serialNumber(31 downto 0));
      axiSlaveRegisterW(X"00C", 0, v.scratchPad);

      axiSlaveRegisterW(X"010", 0, v.cntRst);
      axiSlaveRegisterW(X"010", 1, v.cardRst);
      axiSlaveRegisterW(X"014", 0, v.irqEnable);
      axiSlaveRegisterR(X"014", 1, irqActive);
      axiSlaveRegisterW(X"018", 0, v.rebootAddr);
      axiSlaveRegisterW(X"01C", 0, v.rebootEn);

      axiSlaveRegisterR(X"020", 0, cfgFromPci.Status);
      axiSlaveRegisterR(X"020", 16, cfgFromPci.command);
      axiSlaveRegisterR(X"024", 0, cfgFromPci.dStatus);
      axiSlaveRegisterR(X"024", 16, cfgFromPci.dCommand);
      axiSlaveRegisterR(X"028", 0, cfgFromPci.lStatus);
      axiSlaveRegisterR(X"028", 16, cfgFromPci.lCommand);
      axiSlaveRegisterR(X"02C", 0, cfgFromPci.busNumber);
      axiSlaveRegisterR(X"02C", 8, cfgFromPci.deviceNumber);
      axiSlaveRegisterR(X"02C", 16, cfgFromPci.functionNumber);
      axiSlaveRegisterR(X"02C", 24, cfgFromPci.linkState);

      axiSlaveRegisterR(X"030", 0, toSlv(DMA_SIZE_G, 32));
      axiSlaveRegisterW(X"034", 0, v.dmaLoopback);

      axiSlaveRegisterR("11--------", 0, buildStampString(rdPntr));

      axiSlaveDefault(AXI_ERROR_RESP_G);

      -- Check for enabled timer
      if r.rebootEn = '1' then
         if r.rebootTimer = MAX_CNT_C then
            v.reboot := '1';
         else
            v.rebootTimer := r.rebootTimer + 1;
         end if;
      else
         v.rebootTimer := 0;
      end if;

      -- Synchronous Reset
      if pciRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      cntRst    <= r.cntRst;
      cardRst   <= r.cardRst;

      irqEnable <= r.irqEnable;
      dmaLoopback <= r.dmaLoopback;
      
      reboot     <= r.reboot;
      rebootAddr <= r.rebootAddr;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
