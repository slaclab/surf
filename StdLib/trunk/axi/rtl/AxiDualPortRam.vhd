-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiDualPortRam.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-17
-- Last update: 2014-08-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A wrapper of StdLib DualPortRam that places an AxiLite
-- interface on the read/write port. 
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

entity AxiDualPortRam is
   
   generic (
      TPD_G        : time                       := 1 ns;
      BRAM_EN_G    : boolean                    := true;
      REG_EN_G     : boolean                    := true;
      MODE_G       : string                     := "write-first";
      ADDR_WIDTH_G : integer range 1 to (2**24) := 4;
      DATA_WIDTH_G : integer range 1 to 32      := 32;
      INIT_G       : slv                        := "0");

   port (
      -- Axi Port
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Standard Port
      clk  : in  sl                           := '0';
      en   : in  sl                           := '1';
      rst  : in  sl                           := '0';
      addr : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dout : out slv(DATA_WIDTH_G-1 downto 0));

end entity AxiDualPortRam;

architecture rtl of AxiDualPortRam is
   
   type RegType is record
      axiWriteSlave : AxiLiteWriteSlaveType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiAddr       : slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData     : slv(DATA_WIDTH_G-1 downto 0);
      axiWrEn       : sl;
      axiRdEn       : slv(1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiAddr       => (others => '0'),
      axiWrData     => (others => '0'),
      axiWrEn       => '0',
      axiRdEn       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal douta : slv(DATA_WIDTH_G-1 downto 0);
   
begin

   DualPortRam_1 : entity work.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         REG_EN_G     => REG_EN_G,
         MODE_G       => MODE_G,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G,
         INIT_G       => INIT_G)
      port map (
         clka  => axiClk,
         ena   => '1',
         wea   => r.axiWrEn,
         rsta  => axiRst,
         addra => r.axiAddr,
         dina  => r.axiWrData,
         douta => douta,

         clkb  => clk,
         enb   => en,
         rstb  => rst,
         addrb => addr,
         doutb => dout);

   comb : process (axiReadMaster, axiRst, axiWriteMaster, douta, r) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      v.axiWrEn                                     := '0';
      v.axiRdEn                                     := r.axiRdEn(0) & '0';
      v.axiReadSlave.rdata(DATA_WIDTH_G-1 downto 0) := douta;
      v.axiWrData                                   := axiWriteMaster.wdata(DATA_WIDTH_G-1 downto 0);

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      if (axiStatus.writeEnable = '1') then
         v.axiAddr := axiWriteMaster.awaddr(ADDR_WIDTH_G+2-1 downto 2);

         v.axiWrEn := '1';
         axiSlaveWriteResponse(v.axiWriteSlave);
         
      elsif (axiStatus.readEnable = '1' and r.axiRdEn="00") then
         v.axiAddr := axiReadMaster.araddr(ADDR_WIDTH_G+2-1 downto 2);
         -- If output of ram is registered, read data will be ready 2 cycles after address asserted
         -- If not registered it will be ready on next cycle
         if (REG_EN_G or BRAM_EN_G) then
            v.axiRdEn := "01";          -- read in 2 cycles
         else
            v.axiRdEn := "10";          -- read on next cycle
         end if;
      end if;

      if (r.axiRdEn(1) = '1') then
         -- Output data now ready if using async read mode
         axiSlaveReadResponse(v.axiReadSlave);
      end if;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin           <= v;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
