-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-20
-- Last update: 2014-04-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible registers containing configuration
-- information.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      CLK_PERIOD_G     : real            := 8.0E-9;  -- units of seconds
      EN_DEVICE_DNA_G  : boolean         := false;
      EN_DS2411_G      : boolean         := false);
   port (
      axiClk    : in sl;
      axiClkRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      masterReset : out sl;
      fpgaReload  : out sl;

      -- Optional user values
      userValues : in Slv32Array(0 to 63) := (others => X"00000000");

      -- Optional DS2411 interface
      fdSerSdio : inout sl := 'Z');
end AxiVersion;

architecture rtl of AxiVersion is

   type RomType is array (0 to 63) of slv(31 downto 0);

   function makeStringRom return RomType is
      variable ret : RomType := (others => (others => '0'));
      variable c   : character;
   begin
      for i in BUILD_STAMP_C'range loop
         c                                                      := BUILD_STAMP_C(i);
         ret((i-1)/4)(8*((i-1) mod 4)+7 downto 8*((i-1) mod 4)) :=
            conv_std_logic_vector(character'pos(c), 8);
      end loop;
      return ret;
   end function makeStringRom;

   signal stringRom : RomType := makeStringRom;


   type RegType is record
      scratchPad    : slv(31 downto 0);
      masterReset   : sl;
      fpgaReload    : sl;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      scratchPad    => (others => '0'),
      masterReset   => '0',
      fpgaReload    => '0',
      axiReadSlave  => AXI_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_WRITE_SLAVE_INIT_C);


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValid : sl               := '0';
   signal dnaValue : slv(63 downto 0) := (others => '0');
   signal fdValid  : sl               := '0';
   signal fdSerial : slv(63 downto 0) := (others => '0');
   
begin

   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G) generate
      DeviceDna_1 : entity work.DeviceDna
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => axiClk,
            rst      => axiClkRst,
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
            rst       => axiClkRst,
            fdSerSdio => fdSerSdio,
            fdSerial  => fdSerial,
            fdValid   => fdValid);
   end generate GEN_DS2411;

   comb : process (axiClkRst, axiReadMaster, axiWriteMaster, dnaValid, dnaValue, fdSerial, fdValid,
                   r, stringRom, userValues) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when X"01" =>
               v.scratchPad := axiWriteMaster.wdata;
            when X"06" =>
               v.masterReset := axiWriteMaster.wdata(0);
            when X"07" =>
               v.fpgaReload := axiWriteMaster.wdata(0);
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(11 downto 10)) is
            when "00" =>
               case (axiReadMaster.araddr(9 downto 2)) is
                  when X"00" =>
                     v.axiReadSlave.rdata := FPGA_VERSION_C;
                  when X"01" =>
                     v.axiReadSlave.rdata := r.scratchPad;
                  when X"02" =>
                     v.axiReadSlave.rdata := ite(dnaValid = '1', dnaValue(63 downto 32), X"00000000");
                  when X"03" =>
                     v.axiReadSlave.rdata := ite(dnaValid = '1', dnaValue(31 downto 0), X"00000000");
                  when X"04" =>
                     v.axiReadSlave.rdata := ite(fdValid = '1', fdSerial(63 downto 32), X"00000000");
                  when X"05" =>
                     v.axiReadSlave.rdata := ite(fdValid = '1', fdSerial(31 downto 0), X"00000000");
                  when X"06" =>
                     v.axiReadSlave.rdata(0) := r.masterReset;
                  when X"07" =>
                     v.axiReadSlave.rdata(0) := r.fpgaReload;
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
               
            when "01" =>
               v.axiReadSlave.rdata := userValues(conv_integer(axiReadMaster.araddr(7 downto 2)));
            when "10" =>
               v.axiReadSlave.rdata := stringRom(conv_integer(axiReadMaster.araddr(7 downto 2)));
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiClkRst = '1') then
         v             := REG_INIT_C;
         v.masterReset := r.masterReset;
      end if;

      rin <= v;

      fpgaReload    <= r.fpgaReload;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- masterReset output needs asynchronous reset and this is the easiest way to do it
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => true,
         STAGES_G       => 2,
         INIT_G         => "00")
      port map (
         clk     => axiClk,
         rst     => axiClkRst,
         dataIn  => r.masterReset,
         dataOut => masterReset);

end architecture rtl;
