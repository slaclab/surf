-------------------------------------------------------------------------------
-- Title      : AXI-Lite Ring Buffer
-------------------------------------------------------------------------------
-- File       : AxiLiteRingBuffer.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-02-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for simple BRAM based ring buffer with AXI-Lite interface
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteRingBuffer is
   generic (
      -- General Configurations
      TPD_G            : time                        := 1 ns;
      BRAM_EN_G        : boolean                     := true;
      REG_EN_G         : boolean                     := true;
      DATA_WIDTH_G     : positive range 1 to 32      := 32;
      RAM_ADDR_WIDTH_G : positive range 1 to (2**24) := 10;
      AXI_ERROR_RESP_G : slv(1 downto 0)             := AXI_RESP_DECERR_C);
   port (
      -- Data to store in ring buffer
      dataClk         : in  sl;
      dataRst         : in  sl := '0';
      dataValid       : in  sl := '1';
      dataValue       : in  slv(DATA_WIDTH_G-1 downto 0);
      dataLogEn       : in  sl := '0';
      dataLogClr      : in  sl := '0';
      -- AXI-Lite interface for readout
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiLiteRingBuffer;

architecture rtl of AxiLiteRingBuffer is

   ------------------------------
   -- Stream clock domain signals
   ------------------------------
   type DataRegType is record
      wea       : sl;
      firstAddr : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      nextAddr  : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   end record;

   constant DATA_REG_INIT_C : DataRegType := (
      wea       => '0',
      firstAddr => (others => '0'),
      nextAddr  => (others => '0'));

   signal dataR   : DataRegType := DATA_REG_INIT_C;
   signal dataRin : DataRegType;

   signal dataLogEnable   : sl;
   signal dataBufferClear : sl;

   --------------------------------
   -- AXI-Lite clock domain signals
   --------------------------------
   constant AXIL_ADDR_WIDTH_C : integer := RAM_ADDR_WIDTH_G+3;

   type AxilRegType is record
      logEn          : sl;
      bufferClear    : sl;
      ramRdAddr      : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      axilRdEn       : slv(1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      logEn          => '1',
      bufferClear    => '0',
      ramRdAddr      => (others => '0'),
      axilRdEn       => "00",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   signal axilRamRdData : slv(DATA_WIDTH_G-1 downto 0);

   signal axilFirstAddr : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   signal axilNextAddr  : slv(RAM_ADDR_WIDTH_G-1 downto 0);

   signal extDataLogEn  : sl;
   signal extdataLogClr : sl;

begin

   ----------------------
   -- Instantiate the RAM
   ----------------------
   DualPortRam_1 : entity work.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         REG_EN_G     => REG_EN_G,
         MODE_G       => "read-first",
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_G)
      port map (
         clka  => dataClk,
         wea   => dataR.wea,
         rsta  => dataRst,
         addra => dataR.nextAddr,
         dina  => dataValue,
         douta => open,
         clkb  => axilClk,
         rstb  => axilRst,
         addrb => axilR.ramRdAddr,
         doutb => axilRamRdData);

   -------------------------------
   -- Synchronize logEn to dataClk
   -------------------------------
   Synchronizer_logEn : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.logEn,
         dataOut => dataLogEnable);

   Synchronizer_bufferClear : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.bufferClear,
         dataOut => dataBufferClear);

   --------------------------
   -- Main AXI-Stream process
   --------------------------
   dataComb : process (dataBufferClear, dataLogClr, dataLogEn, dataLogEnable, dataR, dataRst,
                       dataValid) is
      variable v : DataRegType;
   begin
      -- Latch the current value
      v := dataR;

      -- Reset strobes
      v.wea := '0';

      -- Increment the addresses on each valid if logging enabled
      if (dataValid = '1') and ((dataLogEnable = '1') or (dataLogEn = '1')) then
         -- Set the flag
         v.wea      := '1';
         -- Increment the address
         v.nextAddr := dataR.nextAddr + 1;
         -- Check if the write pointer = read pointer
         if (v.nextAddr = dataR.firstAddr) then
            v.firstAddr := dataR.firstAddr + 1;
         end if;
      end if;

      -- Synchronous Reset
      if (dataRst = '1') or (dataBufferClear = '1') or (dataLogClr = '1') then
         v := DATA_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      dataRin <= v;
      
   end process;

   dataSeq : process (dataClk) is
   begin
      if rising_edge(dataClk) then
         dataR <= dataRin after TPD_G;
      end if;
   end process;

   -----------------------------------------------------
   -- Synchronize write address across to AXI-Lite clock
   -----------------------------------------------------
   SynchronizerFifo_1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => RAM_ADDR_WIDTH_G)
      port map (
         rst    => axilRst,
         wr_clk => dataClk,
         din    => dataR.firstAddr,
         rd_clk => axilClk,
         dout   => axilFirstAddr);

   SynchronizerFifo_2 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => RAM_ADDR_WIDTH_G)
      port map (
         rst    => axilRst,
         wr_clk => dataClk,
         din    => dataR.nextAddr,
         rd_clk => axilClk,
         dout   => axilNextAddr);

   Synchronizer_dataLogEn : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => dataLogEn,
         dataOut => extDataLogEn);

   Synchronizer_dataLogClr : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => dataLogClr,
         dataOut => extdataLogClr);         

   ------------------------
   -- Main AXI-Lite process
   ------------------------
   axiComb : process (axilFirstAddr, axilNextAddr, axilR, axilRamRdData, axilReadMaster, axilRst,
                      axilWriteMaster, extDataLogEn, extdataLogClr) is
      variable v            : AxilRegType;
      variable axilStatus   : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := axilR;

      -- Reset strobes
      v.bufferClear := '0';

      -- Update Shift Register
      v.axilRdEn := axilR.axilRdEn(0) & '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Check for write request
      if (axilStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Check for first mapped address access (which is the control register)
         if (axilWriteMaster.awaddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = 0) then
            v.logEn       := axilWriteMaster.wdata(0);
            v.bufferClear := axilWriteMaster.wdata(1);
         else
            -- Unmapped write register access
            axiWriteResp := AXI_ERROR_RESP_G;
         end if;
         -- Set the Slave's response
         axiSlaveWriteResponse(v.axilWriteSlave, axiWriteResp);
      end if;

      -- Check for read request
      if (axilStatus.readEnable = '1') then
         -- Reset the read data bus
         v.axilReadSlave.rdata := (others => '0');
         -- Check for an out of 32 bit aligned address
         axiReadResp           := ite(axilReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Check for first mapped address access (which is the control register)
         if (axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = 0) then
            v.axilReadSlave.rdata(31)                          := axilR.logEn;
            v.axilReadSlave.rdata(30)                          := axilR.bufferClear;
            v.axilReadSlave.rdata(29)                          := extDataLogEn;
            v.axilReadSlave.rdata(28)                          := extdataLogClr;
            v.axilReadSlave.rdata(27 downto 20)                := toSlv(RAM_ADDR_WIDTH_G, 8);  -- Let the software know the configuration
            v.axilReadSlave.rdata(RAM_ADDR_WIDTH_G-1 downto 0) := axilNextAddr - axilFirstAddr;  -- Calculate the length
            axiSlaveReadResponse(v.axilReadSlave, axiReadResp);
         else
            -- AXI-Lite address is automatically offset by firstAddr.
            -- Thus axil address 0 always pulls from firstAddr, etc
            v.ramRdAddr   := axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) + axilFirstAddr - 1;  -- minus 1 corrects for araddr=0x4 start offset
            -- If output of ram is registered, read data will be ready 2 cycles after address asserted
            -- If not registered it will be ready on next cycle
            v.axilRdEn(0) := '1';
            if (axilR.axilRdEn(1) = '1') then
               -- Reset the shift register
               v.axilRdEn                                     := "00";
               -- Update the read data bus
               v.axilReadSlave.rdata(DATA_WIDTH_G-1 downto 0) := axilRamRdData;
               -- Set the Slave's response
               axiSlaveReadResponse(v.axilReadSlave, axiReadResp);
            end if;
         end if;
      end if;

      -- Synchronous Reset
      if (axilRst = '1') then
         v := AXIL_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      axilRin <= v;

      -- Outputs
      axilReadSlave  <= axilR.axilReadSlave;
      axilWriteSlave <= axilR.axilWriteSlave;

   end process;

   axiSeq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         axilR <= axilRin after TPD_G;
      end if;
   end process;
   
end rtl;
