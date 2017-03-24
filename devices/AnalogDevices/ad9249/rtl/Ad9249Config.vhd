-------------------------------------------------------------------------------
-- File       : Ad9249Config.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2016-12-12
-------------------------------------------------------------------------------
-- Description: AD9249 Configuration/Status Module
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

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity Ad9249Config is

   generic (
      TPD_G             : time            := 1 ns;
      NUM_CHIPS_G       : positive        := 1;
      SCLK_PERIOD_G     : real            := 1.0e-6;
      AXIL_CLK_PERIOD_G : real            := 8.0e-9;
      AXIL_ERR_RESP_G   : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      axilClk : in sl;
      axilRst : in sl;

      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      adcPdwn : out   slv(NUM_CHIPS_G-1 downto 0);
      adcSclk : out   sl;
      adcSdio : inout sl;
      adcCsb  : out   slv(NUM_CHIPS_G*2-1 downto 0)

      );

end entity Ad9249Config;

architecture rtl of Ad9249Config is

   -- AdcCore Outputs
   signal rdData : slv(23 downto 0);
   signal rdEn   : sl;

   -- Adc Core Chip IO
   signal coreSclk   : sl;
   signal coreSDin   : sl;
   signal coreSDout  : sl;
   signal coreCsb    : slv(NUM_CHIPS_G*2-1 downto 0);
   signal sdioDir    : sl;
   signal shiftCount : slv(bitSize(24)-1 downto 0);


   constant CHIP_SEL_WIDTH_C : integer                       := log2(NUM_CHIPS_G*2);
   constant PWDN_ADDR_BIT_C  : integer                       := 11 + CHIP_SEL_WIDTH_C;
   constant PWDN_ADDR_C      : slv(PWDN_ADDR_BIT_C downto 0) := toSlv(2**PWDN_ADDR_BIT_C, PWDN_ADDR_BIT_C+1);

   type StateType is (WAIT_AXI_TXN_S, WAIT_CYCLE_S, WAIT_SPI_TXN_DONE_S);

   -- Registers
   type RegType is record
      state          : StateType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      -- Adc Core Inputs
      chipSel        : slv(CHIP_SEL_WIDTH_C-1 downto 0);
      wrData         : slv(23 downto 0);
      wrEn           : sl;
      pdwn           : slv(NUM_CHIPS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_AXI_TXN_S,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      chipSel        => (others => '0'),
      wrData         => (others => '0'),
      wrEn           => '0',
      pdwn           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilRst, axilReadMaster, axilWriteMaster, r, rdData, rdEn) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);


      case (r.state) is
         when WAIT_AXI_TXN_S =>

            -- Chip powerdown signal is local registers
            for i in 0 to NUM_CHIPS_G-1 loop
               axiSlaveRegister(axilEp, PWDN_ADDR_C + i*4, 0, v.pdwn(i));
            end loop;

            -- Any other address is forwarded to the chip via SPI
            if (axilEp.axiStatus.writeEnable = '1' and axilWriteMaster.awaddr(PWDN_ADDR_BIT_C) = '0') then
               v.wrData(23)           := '0';      -- Write bit
               v.wrData(22 downto 21) := "00";     -- Number of bytes (1)
               v.wrData(20 downto 17) := "0000";  -- Unused address bits
               v.wrData(16 downto 8)  := axilWriteMaster.awaddr(10 downto 2);  -- Address
               v.wrData(7 downto 0)   := axilWriteMaster.wdata(7 downto 0);    -- Data
               v.chipSel              := axilWriteMaster.awaddr(11+CHIP_SEL_WIDTH_C-1 downto 11);  -- Bank select
               v.wrEn                 := '1';
               v.state                := WAIT_CYCLE_S;
            end if;

            if (axilEp.axiStatus.readEnable = '1' and axilReadMaster.araddr(PWDN_ADDR_BIT_C) = '0') then
               v.wrData(23)           := '1';              -- read bit
               v.wrData(22 downto 21) := "00";             -- Number of bytes (1)
               v.wrData(20 downto 17) := "0000";          -- Unused address bits
               v.wrData(16 downto 8)  := axilReadMaster.araddr(10 downto 2);  -- Address
               v.wrData(7 downto 0)   := (others => '1');  -- Make bus float to Z so slave can
                                                           -- drive during data segment
               v.chipSel              := axilReadMaster.araddr(11+CHIP_SEL_WIDTH_C-1 downto 11);  -- Bank Select
               v.wrEn                 := '1';
               v.state                := WAIT_CYCLE_S;
            end if;

            axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXIL_ERR_RESP_G, v.wrEn);            

         when WAIT_CYCLE_S =>
            -- Wait 1 cycle for rdEn to drop
            v.wrEn  := '0';
            v.state := WAIT_SPI_TXN_DONE_S;

         when WAIT_SPI_TXN_DONE_S =>

            if (rdEn = '1') then
               v.state := WAIT_AXI_TXN_S;
               if (r.wrData(23) = '0') then
                  -- Finish write
                  axiSlaveWriteResponse(axilEp.axiWriteSlave);
                  v.axilWriteSlave := axilEp.axiWriteSlave;
               else
                  -- Finish read
                  axilEp.axiReadSlave.rdata             := (others => '0');
                  axilEp.axiReadSlave.rdata(7 downto 0) := rdData(7 downto 0);
                  axiSlaveReadResponse(axilEp.axiReadSlave);
                  v.axilReadSlave := axilEp.axiReadSlave;
               end if;
            end if;

         when others => null;
      end case;



      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      adcPdwn        <= r.pdwn;


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SpiMaster_1 : entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => NUM_CHIPS_G*2,
         DATA_SIZE_G       => 24,
         CPHA_G            => '0',      -- Sample on leading edge
         CPOL_G            => '0',      -- Sample on rising edge
         CLK_PERIOD_G      => AXIL_CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SCLK_PERIOD_G)
      port map (
         clk        => axilClk,
         sRst       => axilRst,
         chipSel    => r.chipSel,
         wrEn       => r.wrEn,
         wrData     => r.wrData,
         rdEn       => rdEn,
         rdData     => rdData,
         shiftCount => shiftCount,
         spiCsL     => coreCsb,
         spiSclk    => coreSclk,
         spiSdi     => coreSDout,
         spiSdo     => coreSDin);

   -- Bus lines float to Z when not being driven to '0'.
   -- Lines should all have resistor pullups off chip
--    SCLK_OBUFT : OBUFT
--       port map (
--          I => '0',
--          O => adcSclk,
--          T => coreSclk);
   adcSclk <= coreSclk;

   -- Allow input when doing a read and in the data segment of the shift operation
   sdioDir <= '1' when shiftCount >= 16 and r.wrData(23)='1' else '0';
   SDIO_IOBUFT : IOBUF
      port map (
         I  => coreSDout,
         O  => coreSDin,
         IO => adcSdio,
         T  => sdioDir);

--    CSB_OBUFT : for i in NUM_CHIPS_G*2-1 downto 0 generate
--       CSB0_OBUFT : OBUFT
--          port map (
--             I => '0',
--             O => adcCsb(i),
--             T => coreCsb(i));
--    end generate;
   adcCsb <= coreCsb;

end architecture rtl;
