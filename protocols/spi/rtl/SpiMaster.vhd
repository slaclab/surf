-------------------------------------------------------------------------------
-- File       : SpiMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-24
-- Last update: 2016-12-06
-------------------------------------------------------------------------------
-- Description: Generic SPI Master Module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;
use work.StdRtlPkg.all;

entity SpiMaster is
   generic (
      TPD_G             : time                  := 1 ns;
      NUM_CHIPS_G       : positive range 1 to 8 := 4;
      DATA_SIZE_G       : natural               := 16;
      CPHA_G            : sl                    := '0';
      CPOL_G            : sl                    := '0';
      CLK_PERIOD_G      : real                  := 8.0E-9;
      SPI_SCLK_PERIOD_G : real                  := 1.0E-6);  -- 1 MHz
   port (
      --Global Signals
      clk     : in  sl;
      sRst    : in  sl;
      -- Parallel interface
      chipSel : in  slv(log2(NUM_CHIPS_G)-1 downto 0);
      wrEn    : in  sl;
      wrData  : in  slv(DATA_SIZE_G-1 downto 0);
      dataSize : in slv(log2(DATA_SIZE_G)-1 downto 0) := toSlv(DATA_SIZE_G-1, log2(DATA_SIZE_G));
      rdEn    : out sl;
      rdData  : out slv(DATA_SIZE_G-1 downto 0);
      shiftCount : out slv(bitSize(DATA_SIZE_G)-1 downto 0);
      --SPI interface
      spiCsL  : out slv(NUM_CHIPS_G-1 downto 0);
      spiSclk : out sl;
      spiSdi  : out sl;
      spiSdo  : in  sl);                
end SpiMaster;

architecture rtl of SpiMaster is

   constant SPI_CLK_PERIOD_DIV2_CYCLES_C : integer := integer(SPI_SCLK_PERIOD_G / (2.0*CLK_PERIOD_G));
   constant SCLK_COUNTER_SIZE_C          : integer := bitSize(SPI_CLK_PERIOD_DIV2_CYCLES_C);


   -- Types
   type StateType is (
      IDLE_S,
      SHIFT_S,
      SAMPLE_S,
      DONE_S);

   type RegType is record
      state       : StateType;
      rdEn        : sl;
      rdData      : slv(DATA_SIZE_G-1 downto 0);
      wrData      : slv(DATA_SIZE_G-1 downto 0);
      dataCounter : slv(bitSize(DATA_SIZE_G)-1 downto 0);
      sclkCounter : slv(SCLK_COUNTER_SIZE_C-1 downto 0);

      spiCsL  : slv(NUM_CHIPS_G-1 downto 0);
      spiSclk : sl;
      spiSdi  : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      rdEn        => '0',
      rdData      => (others => '0'),
      wrData      => (others => '0'),
      dataCounter => (others => '0'),
      sclkCounter => (others => '0'),
      spiCsL      => (others => '1'),
      spiSclk     => '0',
      spiSdi      => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal spiSdoRes : sl;

begin

   spiSdoRes <= to_x01z(spiSdo);

   comb : process (chipSel, dataSize, r, sRst, spiSdoRes, wrData, wrEn) is
      variable v : RegType;
   begin
      v := r;

      case (r.state) is
         when IDLE_S =>

            v.spiSclk     := CPOL_G;
            v.spiSdi      := '0';
            v.dataCounter := (others => '0');
            v.sclkCounter := (others => '0');
            v.rdEn        := '1';  -- rdEn always valid between txns, indicates ready for next txn

            if (wrEn = '1') then
               v.rdEn   := '0';
               v.wrData := wrData;
               v.rdData := (others => '0');
               v.spiCsL := not (decode(chipSel)(NUM_CHIPS_G-1 downto 0));

               if (CPHA_G = '0') then
                  -- Sample on first sclk edge so shift here before that happens
                  v.spiSdi := wrData(DATA_SIZE_G-1);
                  v.wrData := wrData(DATA_SIZE_G-2 downto 0) & '0';
                  v.state  := SAMPLE_S;
               else
                  v.state := SHIFT_S;
               end if;
            end if;

         when SHIFT_S =>
            -- Wait half a clock period then shift out the next data bit
            v.sclkCounter := r.sclkCounter + 1;
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               v.sclkCounter := (others => '0');
               v.spiSclk     := not r.spiSclk;
               v.spiSdi      := r.wrData(DATA_SIZE_G-1);
               v.wrData      := r.wrData(DATA_SIZE_G-2 downto 0) & '0';
               v.state       := SAMPLE_S;

               if (CPHA_G = '0') then
                  v.dataCounter := r.dataCounter + 1;
                  if (r.dataCounter = dataSize) then
                     v.state := DONE_S;
                  end if;
               end if;
            end if;

         when SAMPLE_S =>
            -- Wait half a clock period then sample the next data bit
            v.sclkCounter := r.sclkCounter + 1;
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               v.sclkCounter := (others => '0');
               v.spiSclk     := not r.spiSclk;
               v.rdData      := r.rdData(DATA_SIZE_G-2 downto 0) & spiSdoRes;
               v.state       := SHIFT_S;

               if (CPHA_G = '1') then
                  v.dataCounter := r.dataCounter + 1;
                  if (r.dataCounter = dataSize) then
                     v.state := DONE_S;
                  end if;
               end if;
            end if;
            
         when DONE_S =>
            -- Assert rdEn after half a SPI clk period
            -- Go back to idle after one SPI clk period
            -- Otherwise back to back operations happen too fast.
            v.sclkCounter := r.sclkCounter + 1;
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               v.sclkCounter := (others => '0');
               v.spiCsL      := (others => '1');

               if (r.spiCsL = slvOne(NUM_CHIPS_G)) then
                  v.state := IDLE_S;
               end if;
            end if;
         when others => null;
      end case;

      if (sRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      spiSclk <= r.spiSclk;
      spiSdi  <= r.spiSdi;
      spiCsL  <= r.spiCsL;

      rdEn   <= r.rdEn;
      rdData <= r.rdData;
      shiftCount <= r.dataCounter;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
