-------------------------------------------------------------------------------
-- File       : Dsp48Comparator4x12b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-02
-- Last update: 2014-10-02
-------------------------------------------------------------------------------
-- Description: This module is a quad 12-bit digital comparator using a DSP48
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Dsp48Comparator4x12b is
   generic (
      TPD_G              : time    := 1 ns;
      EN_GREATER_EQUAL_G : boolean := false);  -- true is ">=" operation and false is ">" operation
   port (
      -- Data and Threshold Signals 
      polarity : in  sl := '0';
      dataIn   : in  Slv12Array(0 to 3);
      threshIn : in  Slv12Array(0 to 3);
      -- Hit detected Signals      
      compOut  : out slv(3 downto 0);          -- '1' when data > threshold
      -- Clock and Reset Signals      
      clk      : in  sl;
      rst      : in  sl := '0');
end Dsp48Comparator4x12b;

architecture mapping of Dsp48Comparator4x12b is

   signal carryOut : slv(3 downto 0);
   signal din      : slv(47 downto 0);
   signal A        : slv(29 downto 0);
   signal B        : slv(17 downto 0);
   signal C        : slv(47 downto 0);
   signal reset,
      rstDly : sl;

begin

   -- Map the data signals into C bus
   C(47 downto 36) <= dataIn(3);
   C(35 downto 24) <= dataIn(2);
   C(23 downto 12) <= dataIn(1);
   C(11 downto 0)  <= dataIn(0);

   -- Map the threshold signal into A:B bus
   din(47 downto 36) <= threshIn(3);
   din(35 downto 24) <= threshIn(2);
   din(23 downto 12) <= threshIn(1);
   din(11 downto 0)  <= threshIn(0);

   A <= din(47 downto 18);
   B <= din(17 downto 0);

   -- Reduce the fanout of the reset signal to help with timing
   process(clk)
   begin
      if rising_edge(clk) then
         reset  <= rstDly after TPD_G;
         rstDly <= rst    after TPD_G;
      end if;
   end process;

   GEN_HIT :
   for i in 3 downto 0 generate

      process(clk)
      begin
         if rising_edge(clk) then
            -- Check for only ">" operation
            if (EN_GREATER_EQUAL_G = false) and (dataIn(i) = threshIn(i)) then
               compOut(i) <= '0' after TPD_G;
            else
               -- Check the polarity configuration
               if polarity = '1' then
                  compOut(i) <= not(carryOut(i)) after TPD_G;  -- negative pulse polarity
               else
                  compOut(i) <= carryOut(i) after TPD_G;       -- positive pulse polarity
               end if;
            end if;
         end if;
      end process;
      
   end generate GEN_HIT;

   DSP48E1_Inst : DSP48E1
      generic map (
         -- Feature Control Attributes: Data Path Selection
         A_INPUT            => "DIRECT",  -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
         B_INPUT            => "DIRECT",  -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
         USE_DPORT          => false,   -- Select D port usage (TRUE or FALSE)
         USE_MULT           => "NONE",  -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
         -- Pattern Detector Attributes: Pattern Detection Configuration
         AUTORESET_PATDET   => "NO_RESET",       -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
         MASK               => x"FFFFFFFFFFFF",  -- 48-bit mask value for pattern detect (1=ignore)
         PATTERN            => x"000000000000",  -- 48-bit pattern match for pattern detect
         SEL_MASK           => "MASK",  -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
         SEL_PATTERN        => "PATTERN",        -- Select pattern value ("PATTERN" or "C")
         USE_PATTERN_DETECT => "NO_PATDET",      -- Enable pattern detect ("PATDET" or "NO_PATDET")
         -- Register Control Attributes: Pipeline Register Configuration
         ACASCREG           => 1,  -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
         ADREG              => 0,       -- Number of pipeline stages for pre-adder (0 or 1)
         ALUMODEREG         => 0,       -- Number of pipeline stages for ALUMODE (0 or 1)
         AREG               => 1,       -- Number of pipeline stages for A (0, 1 or 2)
         BCASCREG           => 1,  -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
         BREG               => 1,       -- Number of pipeline stages for B (0, 1 or 2)
         CARRYINREG         => 0,       -- Number of pipeline stages for CARRYIN (0 or 1)
         CARRYINSELREG      => 0,       -- Number of pipeline stages for CARRYINSEL (0 or 1)
         CREG               => 1,       -- Number of pipeline stages for C (0 or 1)
         DREG               => 0,       -- Number of pipeline stages for D (0 or 1)
         INMODEREG          => 0,       -- Number of pipeline stages for INMODE (0 or 1)
         MREG               => 0,       -- Number of multiplier pipeline stages (0 or 1)
         OPMODEREG          => 0,       -- Number of pipeline stages for OPMODE (0 or 1)
         PREG               => 1,       -- Number of pipeline stages for P (0 or 1)
         USE_SIMD           => "FOUR12")  -- SIMD selection ("ONE48", "TWO24", "FOUR12")
      port map (
         -- Cascade: 30-bit (each) output: Cascade Ports
         ACOUT          => open,        -- 30-bit output: A port cascade output
         BCOUT          => open,        -- 18-bit output: B port cascade output
         CARRYCASCOUT   => open,        -- 1-bit output: Cascade carry output
         MULTSIGNOUT    => open,        -- 1-bit output: Multiplier sign cascade output
         PCOUT          => open,        -- 48-bit output: Cascade output
         -- Control: 1-bit (each) output: Control Inputs/Status Bits
         OVERFLOW       => open,        -- 1-bit output: Overflow in add/acc output
         PATTERNBDETECT => open,        -- 1-bit output: Pattern bar detect output
         PATTERNDETECT  => open,        -- 1-bit output: Pattern detect output
         UNDERFLOW      => open,        -- 1-bit output: Underflow in add/acc output
         -- Data: 4-bit (each) output: Data Ports
         CARRYOUT       => carryOut,    -- 4-bit output: Carry output
         P              => open,        -- 48-bit output: Primary data output
         -- Cascade: 30-bit (each) input: Cascade Ports
         ACIN           => (others => '0'),      -- 30-bit input: A cascade data input
         BCIN           => (others => '0'),      -- 18-bit input: B cascade input
         CARRYCASCIN    => '0',         -- 1-bit input: Cascade carry input
         MULTSIGNIN     => '0',         -- 1-bit input: Multiplier sign input
         PCIN           => (others => '0'),      -- 48-bit input: P cascade input
         -- Control: 4-bit (each) input: Control Inputs/Status Bits
         ALUMODE        => "0011",      -- 4-bit input: ALU control input
         CARRYINSEL     => "000",       -- 3-bit input: Carry select input
         CEINMODE       => '1',         -- 1-bit input: Clock enable input for INMODEREG
         CLK            => clk,         -- 1-bit input: Clock input
         INMODE         => "00011",     -- 5-bit input: INMODE control input
         OPMODE         => "0110011",   -- 7-bit input: Operation mode input
         RSTINMODE      => reset,       -- 1-bit input: Reset input for INMODEREG
         -- Data: 30-bit (each) input: Data Ports         
         A              => A,           -- 30-bit input: A data input
         B              => B,           -- 18-bit input: B data input
         C              => C,           -- 48-bit input: C data input
         CARRYIN        => '0',         -- 1-bit input: Carry input signal
         D              => (others => '0'),      -- 25-bit input: D data input
         -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
         CEA1           => '1',         -- 1-bit input: Clock enable input for 1st stage AREG
         CEA2           => '1',         -- 1-bit input: Clock enable input for 2nd stage AREG
         CEAD           => '1',         -- 1-bit input: Clock enable input for ADREG
         CEALUMODE      => '1',         -- 1-bit input: Clock enable input for ALUMODERE
         CEB1           => '1',         -- 1-bit input: Clock enable input for 1st stage BREG
         CEB2           => '1',         -- 1-bit input: Clock enable input for 2nd stage BREG
         CEC            => '1',         -- 1-bit input: Clock enable input for CREG
         CECARRYIN      => '1',         -- 1-bit input: Clock enable input for CARRYINREG
         CECTRL         => '1',  -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
         CED            => '1',         -- 1-bit input: Clock enable input for DREG
         CEM            => '1',         -- 1-bit input: Clock enable input for MREG
         CEP            => '1',         -- 1-bit input: Clock enable input for PREG
         RSTA           => reset,       -- 1-bit input: Reset input for AREG
         RSTALLCARRYIN  => reset,       -- 1-bit input: Reset input for CARRYINREG
         RSTALUMODE     => reset,       -- 1-bit input: Reset input for ALUMODEREG
         RSTB           => reset,       -- 1-bit input: Reset input for BREG
         RSTC           => reset,       -- 1-bit input: Reset input for CREG
         RSTCTRL        => reset,       -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
         RSTD           => reset,       -- 1-bit input: Reset input for DREG and ADREG
         RSTM           => reset,       -- 1-bit input: Reset input for MREG
         RSTP           => reset);      -- 1-bit input: Reset input for PREG
end mapping;
