-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiW25Q128Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-25
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to W25Q128 FLASH Memory IC
--
--    Note: This module doesn't support DSPI or QSPI interface yet.
--
--    Note: Set the addrBits on the crossbar for this module to 10 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiW25Q128Pkg.all;

entity AxiW25Q128Core is
   generic (
      TPD_G                 : time            := 1 ns;
      FORCE_ADDR_MSB_HIGH_G : boolean         := false;  -- Set true to prevent any operation in the lower half of the address space
      BRAM_EN_G             : boolean         := false;
      AXI_CLK_FREQ_G        : real            := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G        : real            := 50.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G      : slv(1 downto 0) := AXI_RESP_SLVERR_C);     
   port (
      -- FLASH Memory Ports
      spiOut         : out   AxiW25Q128OutType;
      spiInOut       : inout AxiW25Q128InOutType;
      spiSck         : out   sl;  -- Copy of serial clock for use with STARTUPE2 when interfacing to FPGA's CCLK
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
begin
   -- Check SPI_CLK_FREQ_G
   -- Note: Max. read frequency is 50 MHz
   assert (SPI_CLK_FREQ_G <= 50.0E+6)
      report "SPI_CLK_FREQ_G must be <= 50.0E+6"
      severity failure;
   -- Check AXI_CLK_FREQ_G >= 2*SPI_CLK_FREQ_G
   assert (AXI_CLK_FREQ_G >= getRealMult(2, SPI_CLK_FREQ_G))
      report "AXI_CLK_FREQ_G must be >= 2*SPI_CLK_FREQ_G"
      severity failure;
end AxiW25Q128Core;

architecture mapping of AxiW25Q128Core is
   
   signal sck,
      csL : sl;
   signal dout,
      din,
      oeL : slv(3 downto 0);
   
begin

   spiOut.csL <= csL;
   spiOut.sck <= sck;
   spiSck     <= sck;

   GEN_SDIO :
   for i in 0 to 3 generate
      spiInOut.sdio(i) <= dout(i) when(oeL(i) = '0') else 'Z';
      din(i)           <= sfpInOut.sdio(i);
   end generate GEN_SDIO;

   AxiW25Q128Reg_Inst : entity work.AxiW25Q128Reg
      generic map(
         TPD_G                 => TPD_G,
         FORCE_ADDR_MSB_HIGH_G => FORCE_ADDR_MSB_HIGH_G,
         BRAM_EN_G             => BRAM_EN_G,
         AXI_CLK_FREQ_G        => AXI_CLK_FREQ_G,
         SPI_CLK_FREQ_G        => SPI_CLK_FREQ_G,
         AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G)
      port map(
         -- FLASH Memory Ports
         csL            => csL,
         sck            => sck,
         din            => din,
         dout           => dout,
         oeL            => oeL,
         -- AXI-Lite Register Interface    
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);   

end mapping;
