-------------------------------------------------------------------------------
-- Title      : Axi lite interface for a single chip SPI master
-------------------------------------------------------------------------------
-- File       : AxiSpiMaster.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
--            : Uros Legat Modified <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-01-12
-- Last update: 2015-11-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   For multiple chips on single bus connect multiple cores
--                to multiple AXI crossbar slaves and use Chip select outputs
--                (coreCsb) to multiplex select the addressed outputs (coreSDout and
--                coreSclk).
--                The coreCsb is active low. And active only if the corresponding 
--                Axi Crossbar Slave is addressed.
--                DATA_SIZE_G - Corresponds to total read or write command size (not just data size).
--                              Example: DATA_SIZE_G = 24
--                                       1-bit command, 15-bit address word and 8-bit data
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

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
--use work.I2cPkg.all;

entity AxiSpiMaster is
   generic (
      TPD_G             : time            := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0) := AXI_RESP_DECERR_C;
      ADDRESS_SIZE_G    : natural         := 15;
      DATA_SIZE_G       : natural         := 8;
      CLK_PERIOD_G      : real            := 6.4E-9;
      SPI_SCLK_PERIOD_G : real            := 100.0E-6
      );
   port (
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      coreSclk  : out sl;
      coreSDin  : in  sl;
      coreSDout : out sl;
      coreCsb   : out sl
      );
end entity AxiSpiMaster;

architecture rtl of AxiSpiMaster is

   -- AdcCore Outputs
   constant PACKET_SIZE_C : positive := 1+ ADDRESS_SIZE_G + DATA_SIZE_G;  -- "1+" For R/W command bit

   signal rdData : slv(PACKET_SIZE_C-1 downto 0);
   signal rdEn   : sl;

   type StateType is (WAIT_AXI_TXN_S, WAIT_CYCLE_S, WAIT_SPI_TXN_DONE_S);

   -- Registers
   type RegType is record
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Adc Core Inputs
      wrData        : slv(PACKET_SIZE_C-1 downto 0);
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

   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, rdData, rdEn) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      case (r.state) is
         when WAIT_AXI_TXN_S =>

            if (axiStatus.writeEnable = '1') then
               -- Write bit
               v.wrData(PACKET_SIZE_C-1)                                 := '0';
               -- Address (make sure that the assigned AXI address in the crossbar is big enough)               
               v.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G) := axiWriteMaster.awaddr(2+ADDRESS_SIZE_G-1 downto 2);
               -- Data
               v.wrData(DATA_SIZE_G-1 downto 0)                          := axiWriteMaster.wdata(DATA_SIZE_G-1 downto 0);
               v.wrEn                                                    := '1';
               v.state                                                   := WAIT_CYCLE_S;
            end if;

            if (axiStatus.readEnable = '1') then
               -- Read bit
               v.wrData(PACKET_SIZE_C-1)                                 := '1';
               -- Address               
               v.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G) := axiReadMaster.araddr(2+ADDRESS_SIZE_G-1 downto 2);
               -- Make bus float to Z so slave can drive during data segment
               v.wrData(DATA_SIZE_G-1 downto 0)                          := (others => '1');
               v.wrEn                                                    := '1';
               v.state                                                   := WAIT_CYCLE_S;
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
                  v.axiReadSlave.rdata                         := (others => '0');
                  v.axiReadSlave.rdata(DATA_SIZE_G-1 downto 0) := rdData(DATA_SIZE_G-1 downto 0);
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
         DATA_SIZE_G       => PACKET_SIZE_C,
         CPHA_G            => '0',                -- Sample on leading edge
         CPOL_G            => '0',                -- Sample on rising edge
         CLK_PERIOD_G      => CLK_PERIOD_G,       -- 8.0E-9,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)  --ite(SIMULATION_G, 100.0E-9, 100.0E-6))
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
end architecture rtl;
