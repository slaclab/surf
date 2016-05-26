-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Ad9249Config.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2016-05-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
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
      TPD_G        : time    := 1 ns;
      SIMULATION_G : boolean := false);

   port (
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      adcSclk : out   sl;
      adcSdio : inout sl;
      adcCsb  : out   sl

      );

end entity Ad9249Config;

architecture rtl of Ad9249Config is

   -- AdcCore Outputs
   signal rdData : slv(23 downto 0);
   signal rdEn   : sl;

   -- Adc Core Chip IO
   signal coreSclk  : sl;
   signal coreSDin  : sl;
   signal coreSDout : sl;
   signal coreCsb   : sl;

   type StateType is (WAIT_AXI_TXN_S, WAIT_CYCLE_S, WAIT_SPI_TXN_DONE_S);

   -- Registers
   type RegType is record
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Adc Core Inputs
      wrData        : slv(23 downto 0);
      wrEn          : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state         => WAIT_AXI_TXN_S,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      wrData        => (others => '0'),
      wrEn          => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, axiReadMaster, axiWriteMaster, r, rdData, rdEn) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      case (r.state) is
         when WAIT_AXI_TXN_S =>

            if (axiStatus.writeEnable = '1') then
               v.wrData(23)           := '0';                                -- Write bit
               v.wrData(22 downto 21) := "00";                               -- Number of bytes (1)
               v.wrData(20 downto 16) := "00000";                            -- Unused address bits
               v.wrData(15 downto 8)  := axiWriteMaster.awaddr(9 downto 2);  -- Address
               v.wrData(7 downto 0)   := axiWriteMaster.wdata(7 downto 0);   -- Data
               v.wrEn                 := '1';
               v.state                := WAIT_CYCLE_S;
            end if;

            if (axiStatus.readEnable = '1') then
               v.wrData(23)           := '1';              -- read bit
               v.wrData(22 downto 21) := "00";             -- Number of bytes (1)
               v.wrData(20 downto 16) := "00000";          -- Unused address bits
               v.wrData(15 downto 8)  := axiReadMaster.araddr(9 downto 2);  -- Address
               v.wrData(7 downto 0)   := (others => '1');  -- Make bus float to Z so slave can
                                                           -- drive during data segment
               v.wrEn                 := '1';
               v.state                := WAIT_CYCLE_S;
            end if;

         when WAIT_CYCLE_S =>
            -- Wait 1 cycle for rdEn to drop
            v.wrEn  := '0';
            v.state := WAIT_SPI_TXN_DONE_S;

         when WAIT_SPI_TXN_DONE_S =>

            if (rdEn = '1') then
               v.state := WAIT_AXI_TXN_S;
               if (r.wrData(23) = '0') then
                  -- Finish write
                  axiSlaveWriteResponse(v.axiWriteSlave);
               else
                  -- Finish read
                  v.axiReadSlave.rdata             := (others => '0');
                  v.axiReadSlave.rdata(7 downto 0) := rdData(7 downto 0);
                  axiSlaveReadResponse(v.axiReadSlave);
               end if;
            end if;

         when others => null;
      end case;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axiWriteSlave <= r.axiWriteSlave;
      axiReadSlave  <= r.axiReadSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SpiMaster_1 : entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 24,
         CPHA_G            => '0',      -- Sample on leading edge
         CPOL_G            => '0',      -- Sample on rising edge
         CLK_PERIOD_G      => 8.0E-9,
         SPI_SCLK_PERIOD_G => ite(SIMULATION_G, 100.0E-9, 100.0E-6))
      port map (
         clk       => axiClk,
         sRst      => axiRst,
         chipSel   => "0",
         wrEn      => r.wrEn,
         wrData    => r.wrData,
         rdEn      => rdEn,
         rdData    => rdData,
         spiCsL(0) => coreCsb,
         spiSclk   => coreSclk,
         spiSdi    => coreSDout,
         spiSdo    => coreSDin);

   -- Bus lines float to Z when not being driven to '0'.
   -- Lines should all have resistor pullups off chip
   SCLK_OBUFT : OBUFT
      port map (
         I => '0',
         O => adcSclk,
         T => coreSclk);

   SDIO_IOBUFT : IOBUF
      port map (
         I => '0',
         O => coreSDin,
         IO => adcSdio,
         T => coreSDout);

   CSB_OBUFT : OBUFT
      port map (
         I => '0',
         O => adcCsb,
         T => coreCsb);
   
--   adcSclk  <= '0' when coreSclk = '0'  else 'Z';
--   adcSdio  <= '0' when coreSDout = '0' else 'Z';
--   coreSDin <= to_x01z(adcSdio);
--   adcCsb   <= '0' when coreCsb = '0'   else 'Z';

end architecture rtl;
