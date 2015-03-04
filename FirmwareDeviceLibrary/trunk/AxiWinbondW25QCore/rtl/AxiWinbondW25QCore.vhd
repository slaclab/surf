-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiWinbondW25QCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2015-03-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to W25Q FLASH Memory IC
--
--    Note: This module doesn't support DSPI or QSPI interface yet.
--
--    Note: Set the addrBits on the crossbar for this module to 10 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiWinbondW25QPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiWinbondW25QCore is
   generic (
      TPD_G            : time                := 1 ns;
      MEM_ADDR_MASK_G  : slv(23 downto 0)    := x"000000";
      AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G   : real                := 50.0E+6;   -- units of Hz
      AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);     
   port (
      -- FLASH Memory Ports
      spiOut         : out   AxiWinbondW25QOutType;
      spiInOut       : inout AxiWinbondW25QInOutType;
      spiSck         : out   sl;  -- Copy of serial clock for use with STARTUPE2 when interfacing to FPGA's CCLK
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- AXI Streaming Interface (Optional)
      mAxisMaster    : out   AxiStreamMasterType;
      mAxisSlave     : in    AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      sAxisMaster    : in    AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out   AxiStreamSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiWinbondW25QCore;

architecture mapping of AxiWinbondW25QCore is
   
   signal sck  : sl;
   signal csL  : sl;
   signal dout : slv(3 downto 0);
   signal din  : slv(3 downto 0);
   signal oeL  : slv(3 downto 0);
   
begin
   -- Check SPI_CLK_FREQ_G
   -- Note: Max. read frequency is 50 MHz
   assert (SPI_CLK_FREQ_G <= 50.0E+6)
      report "SPI_CLK_FREQ_G must be <= 50.0E+6"
      severity failure;
   -- Check AXI_CLK_FREQ_G >= 2*SPI_CLK_FREQ_G
   assert (AXI_CLK_FREQ_G >= getRealMult(2.0, SPI_CLK_FREQ_G))
      report "AXI_CLK_FREQ_G must be >= 2*SPI_CLK_FREQ_G"
      severity failure;

   spiOut.csL <= csL;
   spiOut.sck <= sck;
   spiSck     <= sck;

   GEN_SDIO :
   for i in 0 to 3 generate
      IOBUF_inst : IOBUF
         port map (
            O  => din(i),               -- Buffer output
            IO => spiInOut.sdio(i),     -- Buffer inout port (connect directly to top-level port)
            I  => dout(i),              -- Buffer input
            T  => oeL(i));              -- 3-state enable input, high=input, low=output        
   end generate GEN_SDIO;

   AxiWinbondW25QReg_Inst : entity work.AxiWinbondW25QReg
      generic map(
         TPD_G            => TPD_G,
         MEM_ADDR_MASK_G  => MEM_ADDR_MASK_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         SPI_CLK_FREQ_G   => SPI_CLK_FREQ_G,
         AXI_CONFIG_G     => AXI_CONFIG_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
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
         -- AXI Streaming Interface (Optional)
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => mAxisSlave,
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);   

end mapping;
