-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiLiteRingBuffer.vhd
-- Author     : 
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2015-11-06
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiLiteRingBuffer is
   generic (
      -- General Configurations
      TPD_G            : time                        := 1 ns;
      BRAM_EN_G        : boolean                     := true;
      REG_EN_G         : boolean                     := true;
      DATA_WIDTH_G     : positive range 1 to 32      := 32;
      RAM_ADDR_WIDTH_G : positive range 1 to (2**24) := 10);

   port (
      -- Data to store in ring buffer
      dataClk   : in sl;
      dataRst   : in sl;
      dataValid : in sl;
      dataValue : in slv(DATA_WIDTH_G-1 downto 0);

   -- Axi Lite interface for readout
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end AxiLiteRingBuffer;

architecture rtl of AxiLiteRingBuffer is

   -------------------------------------------------------------------------------------------------
   -- Stream clock domain signals
   -------------------------------------------------------------------------------------------------
   type DataRegType is record
      firstAddr : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      nextAddr  : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   end record;

   constant DATA_REG_INIT_C : DataRegType := (
      firstAddr => (others => '0'),
      nextAddr  => (others => '0'));

   signal dataR   : DataRegType := DATA_REG_INIT_C;
   signal dataRin : DataRegType;

   signal dataLogEn       : sl;
   signal dataBufferClear : sl;

   -------------------------------------------------------------------------------------------------
   -- AXI-Lite clock domain signals
   -------------------------------------------------------------------------------------------------
   constant AXIL_ADDR_WIDTH_C : integer := RAM_ADDR_WIDTH_G+3;

   type AxilRegType is record
      logEn          : sl;
      bufferClear    : sl;
      ramRdAddr      : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      axilRdEn        : slv(1 downto 0);
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


begin

   -------------------------------------------------------------------------------------------------
   -- Instantiate the ram
   -------------------------------------------------------------------------------------------------
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
         wea   => dataValid,
         rsta  => dataRst,
         addra => dataR.nextAddr,
         dina  => dataValue,
         douta => open,
         clkb  => axilClk,
         rstb  => axilRst,
         addrb => axilR.ramRdAddr,
         doutb => axilRamRdData);

   -------------------------------------------------------------------------------------------------
   -- Synchronize logEn to dataClk
   -------------------------------------------------------------------------------------------------
   Synchronizer_logEn : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.logEn,
         dataOut => dataLogEn);

   Synchronizer_bufferClear : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => dataClk,
         rst     => dataRst,
         dataIn  => axilR.bufferClear,
         dataOut => dataBufferClear);

   -------------------------------------------------------------------------------------------------
   -- Main AXI-Stream process
   -------------------------------------------------------------------------------------------------
   dataComb : process (dataBufferClear, dataLogEn, dataR, dataRst, dataValid) is
      variable v : DataRegType;
   begin
      -- Latch the current value
      v := dataR;

      -- Increment the addresses on each valid if logging enabled
      if (dataValid = '1' and dataLogEn = '1') then
         v.nextAddr := dataR.nextAddr + 1;
         if (v.nextAddr = dataR.firstAddr) then
            v.firstAddr := dataR.firstAddr + 1;
         end if;
      end if;

      -- If logging not enabled, will keep writing to nextAddr, which is never read

      -- Synchronous Reset
      if (dataRst = '1' or dataBufferClear = '1') then
         v := DATA_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      dataRin <= v;

      -- Outputs

   end process;

   dataSeq : process (dataClk) is
   begin
      if rising_edge(dataClk) then
         dataR <= dataRin after TPD_G;
      end if;
   end process;

   -------------------------------------------------------------------------------------------------
   -- Synchronize write address across to axilite clock
   -------------------------------------------------------------------------------------------------
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

   axiComb : process (axilFirstAddr, axilNextAddr, axilR, axilRamRdData, axilReadMaster, axilRst,
                      axilWriteMaster) is
      variable v          : AxilRegType;
      variable axilStatus : AxiLiteStatusType;

   begin
      -- Latch the current value
      v := axilR;

      v.bufferClear := '0';
      v.axilRdEn     := axilR.axilRdEn(0) & '0';

      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      if (axilStatus.writeEnable = '1') then
         if (axilWriteMaster.awaddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = slvOne(RAM_ADDR_WIDTH_G)) then
            v.logEn       := axilWriteMaster.wdata(0);
            v.bufferClear := axilWriteMaster.wdata(1);
         end if;
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      if (axilStatus.readEnable = '1') then
         v.axilReadSlave.rdata := (others => '0');
         if (axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) = slvOne(RAM_ADDR_WIDTH_G)) then
            v.axilReadSlave.rdata(0)            := axilR.logEn;
            v.axilReadSlave.rdata(1)            := axilR.bufferClear;
            v.axilReadSlave.rdata(19 downto  8) := resize(axilFirstAddr,12);
            v.axilReadSlave.rdata(31 downto 20) := resize(axilNextAddr,12);
            axiSlaveReadResponse(v.axilReadSlave);
         else
            -- AXI-Lite address is automatically offset by firstAddr.
            -- Thus axil address 0 always pulls from firstAddr, etc
            v.ramRdAddr := axilReadMaster.araddr(RAM_ADDR_WIDTH_G+2-1 downto 2) + axilFirstAddr;

            -- If output of ram is registered, read data will be ready 2 cycles after address asserted
            -- If not registered it will be ready on next cycle
            v.axilRdEn(0) := '1';
            if (axilR.axilRdEn(1) = '1') then
               v.axilRdEn := "00";
               v.axilReadSlave.rdata(DATA_WIDTH_G-1 downto 0) := axilRamRdData;
               axiSlaveReadResponse(v.axilReadSlave);
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
