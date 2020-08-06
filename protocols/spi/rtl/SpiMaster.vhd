-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;

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
      clk        : in  sl;
      sRst       : in  sl;
      -- Parallel interface
      freeRunClk : in  sl                                := '0';
      chipSel    : in  slv(log2(NUM_CHIPS_G)-1 downto 0);
      wrEn       : in  sl;
      wrData     : in  slv(DATA_SIZE_G-1 downto 0);
      dataSize   : in  slv(log2(DATA_SIZE_G)-1 downto 0) := toSlv(DATA_SIZE_G-1, log2(DATA_SIZE_G));
      rdEn       : out sl;
      rdData     : out slv(DATA_SIZE_G-1 downto 0);
      shiftCount : out slv(bitSize(DATA_SIZE_G)-1 downto 0);
      --SPI interface
      spiCsL     : out slv(NUM_CHIPS_G-1 downto 0);
      spiSclk    : out sl;
      spiSdi     : out sl;
      spiSdo     : in  sl);
end SpiMaster;

architecture rtl of SpiMaster is

   constant SPI_CLK_PERIOD_DIV2_CYCLES_C : integer := integer(SPI_SCLK_PERIOD_G / (2.0*CLK_PERIOD_G));
   constant SCLK_COUNTER_SIZE_C          : integer := bitSize(SPI_CLK_PERIOD_DIV2_CYCLES_C);


   -- Types
   type StateType is (
      IDLE_S,
      FREE_RUNNING_CLK_S,
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

   comb : process (chipSel, dataSize, freeRunClk, r, sRst, spiSdoRes, wrData,
                   wrEn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the signals
            v.spiSclk     := CPOL_G;
            v.spiSdi      := '0';
            v.dataCounter := (others => '0');
            v.sclkCounter := (others => '0');
            v.rdEn        := '1';  -- rdEn always valid between txns, indicates ready for next txn
            -- Check for the start of a transaction
            if (wrEn = '1') then
               -- Setup for the SPI transaction
               v.rdEn   := '0';
               v.wrData := wrData;
               v.rdData := (others => '0');
               v.spiCsL := not (decode(chipSel)(NUM_CHIPS_G-1 downto 0));
               -- Check if rising edge sampling
               if (CPHA_G = '0') then
                  -- Sample on first sclk edge so shift here before that happens
                  v.spiSdi := wrData(DATA_SIZE_G-1);
                  v.wrData := wrData(DATA_SIZE_G-2 downto 0) & '0';
                  -- Next state
                  v.state  := SAMPLE_S;
               else
                  -- Next state
                  v.state := SHIFT_S;
               end if;
            -- Check if free running the SCLK between commands
            elsif (freeRunClk = '1') then
               -- Next state
               v.state := FREE_RUNNING_CLK_S;
            end if;
         ----------------------------------------------------------------------
         when FREE_RUNNING_CLK_S =>
            -- Wait half a clock period then shift out the next data bit
            v.sclkCounter := r.sclkCounter + 1;
            -- Check for max count
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               -- Reset the counter
               v.sclkCounter := (others => '0');
               -- Toggle the clock
               v.spiSclk     := not(r.spiSclk);
               -- Check if next cycle in phase of IDLE
               if (v.spiSclk = CPOL_G) then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SHIFT_S =>
            -- Wait half a clock period then shift out the next data bit
            v.sclkCounter := r.sclkCounter + 1;
            -- Check for max count
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               -- Reset the counter
               v.sclkCounter := (others => '0');
               -- Toggle the clock
               v.spiSclk     := not(r.spiSclk);
               -- Shift the data
               v.spiSdi      := r.wrData(DATA_SIZE_G-1);
               v.wrData      := r.wrData(DATA_SIZE_G-2 downto 0) & '0';
               -- Next state (default)
               v.state       := SAMPLE_S;
               -- Check if rising edge sampling
               if (CPHA_G = '0') then
                  -- Increment the counter
                  v.dataCounter := r.dataCounter + 1;
                  -- Check if last bit sent
                  if (r.dataCounter = dataSize) then
                     -- Next state
                     v.state := DONE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SAMPLE_S =>
            -- Wait half a clock period then sample the next data bit
            v.sclkCounter := r.sclkCounter + 1;
            -- Check for max count
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               -- Reset the counter
               v.sclkCounter := (others => '0');
               -- Toggle the clock
               v.spiSclk     := not(r.spiSclk);
               -- Shift the data
               v.rdData      := r.rdData(DATA_SIZE_G-2 downto 0) & spiSdoRes;
               -- Next state (default)
               v.state       := SHIFT_S;
               -- Check if falling edge sampling
               if (CPHA_G = '1') then
                  -- Increment the counter
                  v.dataCounter := r.dataCounter + 1;
                  -- Check if last bit sent
                  if (r.dataCounter = dataSize) then
                     -- Next state
                     v.state := DONE_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Assert rdEn after half a SPI clk period
            -- Go back to idle after one SPI clk period
            -- Otherwise back to back operations happen too fast.
            v.sclkCounter := r.sclkCounter + 1;
            -- Check for max count
            if (r.sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               -- Reset the counter
               v.sclkCounter := (others => '0');
               -- De-assert the chip select bus
               v.spiCsL      := (others => '1');
               -- Check if falling edge sampling
               if (r.spiCsL = slvOne(NUM_CHIPS_G)) then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      spiSclk    <= r.spiSclk;
      spiSdi     <= r.spiSdi;
      spiCsL     <= r.spiCsL;
      rdEn       <= r.rdEn;
      rdData     <= r.rdData;
      shiftCount <= r.dataCounter;

      -- Reset
      if (sRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
