-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-08
-- Last update: 2015-12-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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

entity AxiPcieCtrl is
   generic (
      TPD_G            : time                   := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      XIL_DEVICE_G     : string                 := "7SERIES");  -- Either "7SERIES" or "ULTRASCALE"      
   port (
      -- System Interface
      irqEnable       : out sl;
      irqReq          : out sl;
      irqActive       : in  sl;
      irqDma          : in  slv(15 downto 0);
      serialNumber    : out slv(63 downto 0);
      -- AXI Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clock and Resets
      pciClk          : in  sl;
      pciRst          : in  sl);
end AxiPcieCtrl;

architecture rtl of AxiPcieCtrl is

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
      irqDmaMask     : slv(15 downto 0);
      irqReq         : sl;
      irqEnable      : sl;
      fpgaReload     : sl;
      fpgaReloadAddr : slv(31 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      scratchPad     => (others => '0'),
      irqDmaMask     => (others => '0'),
      irqReq         => '0',
      irqEnable      => '0',
      fpgaReload     => '0',
      fpgaReloadAddr => (others => '0'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValid : sl               := '0';
   signal dnaValue : slv(63 downto 0) := (others => '0');
   
begin

   serialNumber <= dnaValue;

   U_DeviceDna : entity work.DeviceDna
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G)
      port map (
         clk      => pciClk,
         rst      => pciRst,
         dnaValue => dnaValue,
         dnaValid => dnaValid);

   U_Iprog : entity work.Iprog
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G)
      port map (
         clk         => pciClk,
         rst         => pciRst,
         start       => r.fpgaReload,
         bootAddress => r.fpgaReloadAddr);   

   comb : process (axilReadMaster, axilWriteMaster, dnaValid, dnaValue, irqActive, irqDma, pciRst,
                   r, stringRom) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable i         : natural;

      -- Wrapper procedures to make calls cleaner.
      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv; cA : in boolean := false; cV : in slv := "0") is
      begin
         axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, addr, offset, reg, cA, cV);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
      begin
         axiSlaveRegister(axilReadMaster, v.axilReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
      begin
         axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
      begin
         axiSlaveRegister(axilReadMaster, v.axilReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveDefault (
         axiResp : in slv(1 downto 0)) is
      begin
         axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, axiResp);
      end procedure;

   begin
      -- Latch the current value
      v := r;

      -- Generate the IRQ
      v.irqReq := '0';
      for i in 15 downto 0 loop
         if (irqDma(i) = '1') and (r.irqDmaMask(i) = '0') then
            v.irqReq := '1';
         end if;
      end loop;

      -- AXI-Lite Transactions
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus);

      axiSlaveRegisterR(X"000", 0, FPGA_VERSION_C);
      axiSlaveRegisterW(X"004", 0, v.scratchPad);
      axiSlaveRegisterR(X"008", 0, ite(dnaValid = '1', dnaValue(31 downto 0), X"00000000"));
      axiSlaveRegisterR(X"00C", 0, ite(dnaValid = '1', dnaValue(63 downto 32), X"00000000"));
      axiSlaveRegisterW(X"010", 0, v.fpgaReload);
      axiSlaveRegisterW(X"014", 0, v.fpgaReloadAddr);
      axiSlaveRegisterR(X"018", 0, toSlv(DMA_SIZE_G, 32));
      axiSlaveRegisterR(X"01C", 0, irqDma);
      axiSlaveRegisterW(X"020", 0, v.irqDmaMask);
      axiSlaveRegisterR(X"024", 0, r.irqReq);
      axiSlaveRegisterR(X"028", 1, irqActive);
      axiSlaveRegisterW(X"028", 0, v.irqEnable);

      axiSlaveRegisterR("1-----------", 0, stringRom(conv_integer(axilReadMaster.araddr(7 downto 2))));

      axiSlaveDefault(AXI_ERROR_RESP_G);

      -- Check for reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      irqEnable      <= r.irqEnable;
      irqReq         <= r.irqReq;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if (rising_edge(pciClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
