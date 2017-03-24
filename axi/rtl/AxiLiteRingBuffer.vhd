-------------------------------------------------------------------------------
-- File       : AxiLiteRingBuffer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-02-05
-------------------------------------------------------------------------------
-- Description: Wrapper for simple BRAM based ring buffer with AXI-Lite interface
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

entity AxiLiteRingBuffer is
   generic (
      -- General Configurations
      TPD_G            : time                   := 1 ns;
      BRAM_EN_G        : boolean                := true;
      REG_EN_G         : boolean                := true;
      DATA_WIDTH_G     : positive range 1 to 32 := 32;
      RAM_ADDR_WIDTH_G : positive range 1 to 19 := 10;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C);
   port (
      -- Data to store in ring buffer
      dataClk         : in  sl;
      dataRst         : in  sl := '0';
      dataValid       : in  sl := '1';
      dataValue       : in  slv(DATA_WIDTH_G-1 downto 0);
      bufferEnable    : in  sl := '0';
      bufferClear     : in  sl := '0';
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
      ramWrEn      : sl;
      ramWrData    : slv(DATA_WIDTH_G-1 downto 0);
      bufferLength : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      firstAddr    : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      nextAddr     : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   end record;

   constant DATA_REG_INIT_C : DataRegType := (
      ramWrEn      => '0',
      ramWrData    => (others => '0'),
      bufferLength => (others => '0'),
      firstAddr    => (others => '0'),
      nextAddr     => (others => '0'));

   signal dataR   : DataRegType := DATA_REG_INIT_C;
   signal dataRin : DataRegType;

   signal axilBufferEnable : sl;        -- Synchronized AXI register
   signal axilBufferClear  : sl;        -- Synchronized AXI register

   --------------------------------
   -- AXI-Lite clock domain signals
   --------------------------------
   constant AXIL_ADDR_WIDTH_C : integer := RAM_ADDR_WIDTH_G+3;

   type AxilRegType is record
      bufferEnable   : sl;
      bufferClear    : sl;
      ramRdAddr      : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      axilRdEn       : slv(2 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      bufferEnable   => '0',
      bufferClear    => '0',
      ramRdAddr      => (others => '0'),
      axilRdEn       => "000",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   signal axilRamRdData : slv(DATA_WIDTH_G-1 downto 0);
   signal axilFirstAddr : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   signal axilLength    : slv(RAM_ADDR_WIDTH_G-1 downto 0);

   signal extBufferEnable : sl;
   signal extBufferClear  : sl;

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
         DOB_REG_G    => REG_EN_G,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => RAM_ADDR_WIDTH_G)
      port map (
         clka  => dataClk,
         wea   => dataR.ramWrEn,
         rsta  => dataRst,
         addra => dataR.nextAddr,
         dina  => dataR.ramWrData,
         douta => open,
         clkb  => axilClk,
         rstb  => axilRst,
         addrb => axilR.ramRdAddr,
         doutb => axilRamRdData);

   -------------------------------
   -- Synchronize AXI registers to data clock dataClk
   -------------------------------
   Synchronizer_bufferEn : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.bufferEnable,
         dataOut => axilBufferEnable);

   Synchronizer_bufferClear : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.bufferClear,
         dataOut => axilBufferClear);

   --------------------------
   -- Main AXI-Stream process
   --------------------------
   dataComb : process (axilBufferClear, axilBufferEnable, bufferClear, bufferEnable, dataR, dataRst,
                       dataValid, dataValue) is
      variable v      : DataRegType;
      variable enable : sl;
      variable clear  : sl;
   begin
      -- Latch the current value
      v := dataR;

      -- Reset strobes
      v.ramWrEn := '0';

      -- Default assignment
      v.ramWrData := dataValue;
      enable      := bufferEnable or axilBufferEnable;
      clear       := bufferClear or axilBufferClear;

      -- Increment the addresses on each valid if logging enabled
      if (dataValid = '1') and (enable = '1') then
         -- Trigger a write
         v.ramWrEn := '1';

         -- Increment the address
         v.nextAddr := dataR.nextAddr + 1;
         -- Check if the write pointer = read pointer
         if (v.nextAddr = dataR.firstAddr) then
            v.firstAddr := dataR.firstAddr + 1;
         end if;
         -- Calculate the length of the buffer
         v.bufferLength := dataR.nextAddr - dataR.firstAddr;
      end if;

      -- Synchronous Reset
      if (dataRst = '1') or (clear = '1') then
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
         din    => dataR.bufferLength,
         rd_clk => axilClk,
         dout   => axilLength);   

   Synchronizer_dataBufferEn : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => bufferEnable,
         dataOut => extBufferEnable);

   Synchronizer_dataBufferClr : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => bufferClear,
         dataOut => extbufferClear);

   ------------------------
   -- Main AXI-Lite process
   ------------------------
   axiComb : process (axilFirstAddr, axilLength, axilR, axilRamRdData, axilReadMaster, axilRst,
                      axilWriteMaster, extBufferClear, extBufferEnable) is
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
      v.axilRdEn(0) := '0';
      v.axilRdEn(1) := axilR.axilRdEn(0);
      v.axilRdEn(2) := axilR.axilRdEn(1);

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Check for write request
      if (axilStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axilWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Check for first mapped address access (which is the control register)
         if (axilWriteMaster.awaddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = 0) then
            v.bufferEnable := axilWriteMaster.wdata(31);
            v.bufferClear  := axilWriteMaster.wdata(30);
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
         -- Control register mapped at address 0
         if (axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = 0) then
            v.axilReadSlave.rdata(31)                          := axilR.bufferEnable;
            v.axilReadSlave.rdata(30)                          := axilR.bufferClear;
            v.axilReadSlave.rdata(29)                          := extBufferEnable;
            v.axilReadSlave.rdata(28)                          := extBufferClear;
            v.axilReadSlave.rdata(27 downto 20)                := toSlv(RAM_ADDR_WIDTH_G, 8);  -- Let the software know the configuration
            v.axilReadSlave.rdata(RAM_ADDR_WIDTH_G-1 downto 0) := axilLength;
            axiSlaveReadResponse(v.axilReadSlave, axiReadResp);
         else
            -- All other AXI-Lite addresses are automatically offset by firstAddr.
            -- Thus axil word-address 1 always pulls from firstAddr, etc.
            v.ramRdAddr := axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) + axilFirstAddr - 1;  -- minus 1 corrects for araddr=0x4 start offset

            -- Wait 3 cycles before placing the ram read data on the AXIL bus and responding.
            -- This is enough time to cover every ram type
            -- LUTRAM + !REG_EN_G = 1 Cycle
            -- LUTRAM + REG_EN_G = 2 Cycles
            -- BRAM + !REG_EN_G = 2 Cycles
            -- BRAM + REG_EN_G = 3 Cycles            
            v.axilRdEn(0) := '1';
            if (axilR.axilRdEn(2) = '1') then
               -- Reset the shift register
               v.axilRdEn                                     := "000";
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
