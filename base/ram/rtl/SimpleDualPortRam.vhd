-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple dual port RAM with backend selection
--
-- Supported RAM memory configurations:
--
-- SYNTH_MODE_G | MEMORY_TYPE_G                 | READ_LATENCY_G
-- "inferred"   | "block", "distributed", etc.  |      1 ~ 2
-- "xpm"        | delegated to SimpleDualPortRamXpm/vendor rules
-- "altera_mf"  | delegated to SimpleDualPortRamAlteraMf/vendor rules
--
-- The inferred implementation remains the legacy synchronous-read
-- SimpleDualPortRam, now named SimpleDualPortRamInferred. Its base read
-- latency is one clkb cycle for every MEMORY_TYPE_G value, including
-- "distributed". DOB_REG_G adds the historical B-side output register.
-- In contrast, inferred distributed zero-latency LUTRAM is implemented by
-- other RAM helpers such as LutRam/DualPortRam and is not implied here.
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

library surf;
use surf.StdRtlPkg.all;

entity SimpleDualPortRam is
   generic (
      TPD_G               : time                       := 1 ns;
      RST_POLARITY_G      : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G         : boolean                    := false;
      MEMORY_TYPE_G       : string                     := "block";
      DOB_REG_G           : boolean                    := false;  -- Extra reg on doutb (folded into BRAM)
      BYTE_WR_EN_G        : boolean                    := false;
      DATA_WIDTH_G        : integer range 1 to (2**24) := 16;
      BYTE_WIDTH_G        : integer                    := 8;  -- If BRAM, should be multiple or 8 or 9
      ADDR_WIDTH_G        : integer range 1 to (2**24) := 4;
      INIT_G              : slv                        := "0";
      SYNTH_MODE_G        : string                     := "inferred";
      COMMON_CLK_G        : boolean                    := false;
      MEMORY_INIT_FILE_G  : string                     := "none";
      MEMORY_INIT_PARAM_G : string                     := "0";
      READ_LATENCY_G      : natural range 0 to 100     := 1);
   port (
      -- Port A
      clka    : in  sl                                                    := '0';
      ena     : in  sl                                                    := '1';
      wea     : in  sl                                                    := '0';
      weaByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '0');
      addra   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      dina    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
      -- Port B
      clkb    : in  sl                                                    := '0';
      enb     : in  sl                                                    := '1';
      regceb  : in  sl                                                    := '1';
      rstb    : in  sl                                                    := not(RST_POLARITY_G);
      addrb   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutb   : out slv(DATA_WIDTH_G-1 downto 0));
end SimpleDualPortRam;

architecture rtl of SimpleDualPortRam is

   component SimpleDualPortRamInferred is
      generic (
         TPD_G          : time                       := 1 ns;
         RST_POLARITY_G : sl                         := '1';
         RST_ASYNC_G    : boolean                    := false;
         MEMORY_TYPE_G  : string                     := "block";
         DOB_REG_G      : boolean                    := false;
         BYTE_WR_EN_G   : boolean                    := false;
         DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
         BYTE_WIDTH_G   : integer                    := 8;
         ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
         INIT_G         : slv                        := "0");
      port (
         clka    : in  sl                                                    := '0';
         ena     : in  sl                                                    := '1';
         wea     : in  sl                                                    := '0';
         weaByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '0');
         addra   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
         dina    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
         clkb    : in  sl                                                    := '0';
         enb     : in  sl                                                    := '1';
         regceb  : in  sl                                                    := '1';
         rstb    : in  sl                                                    := not(RST_POLARITY_G);
         addrb   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
         doutb   : out slv(DATA_WIDTH_G-1 downto 0));
   end component;

   component SimpleDualPortRamXpm is
      generic (
         TPD_G               : time                       := 1 ns;
         COMMON_CLK_G        : boolean                    := false;
         RST_POLARITY_G      : sl                         := '1';
         MEMORY_TYPE_G       : string                     := "block";
         MEMORY_INIT_FILE_G  : string                     := "none";
         MEMORY_INIT_PARAM_G : string                     := "0";
         READ_LATENCY_G      : natural range 0 to 100     := 1;
         DATA_WIDTH_G        : integer range 1 to (2**24) := 16;
         BYTE_WR_EN_G        : boolean                    := false;
         BYTE_WIDTH_G        : integer range 8 to 9       := 8;
         ADDR_WIDTH_G        : integer range 1 to (2**24) := 4);
      port (
         clka   : in  sl                                                                          := '0';
         ena    : in  sl                                                                          := '1';
         wea    : in  slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0) := (others => '0');
         addra  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
         dina   : in  slv(DATA_WIDTH_G-1 downto 0)                                                := (others => '0');
         clkb   : in  sl                                                                          := '0';
         enb    : in  sl                                                                          := '1';
         regceb : in  sl                                                                          := '1';
         rstb   : in  sl                                                                          := not(RST_POLARITY_G);
         addrb  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
         doutb  : out slv(DATA_WIDTH_G-1 downto 0));
   end component;

   component SimpleDualPortRamAlteraMf is
      generic (
         TPD_G          : time                       := 1 ns;
         COMMON_CLK_G   : boolean                    := false;
         RST_POLARITY_G : sl                         := '1';
         MEMORY_TYPE_G  : string                     := "block";
         READ_LATENCY_G : natural range 0 to 100     := 1;
         DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
         BYTE_WR_EN_G   : boolean                    := false;
         BYTE_WIDTH_G   : integer range 8 to 9       := 8;
         ADDR_WIDTH_G   : integer range 1 to (2**24) := 4);
      port (
         clka   : in  sl                                                                          := '0';
         ena    : in  sl                                                                          := '1';
         wea    : in  slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0) := (others => '0');
         addra  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
         dina   : in  slv(DATA_WIDTH_G-1 downto 0)                                                := (others => '0');
         clkb   : in  sl                                                                          := '0';
         enb    : in  sl                                                                          := '1';
         regceb : in  sl                                                                          := '1';
         rstb   : in  sl                                                                          := not(RST_POLARITY_G);
         addrb  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
         doutb  : out slv(DATA_WIDTH_G-1 downto 0));
   end component;

   constant DOB_REG_C      : boolean := DOB_REG_G or (READ_LATENCY_G = 2);
   constant READ_LATENCY_C : natural := ite(DOB_REG_C and READ_LATENCY_G = 1, 2, READ_LATENCY_G);

   signal weaVector : slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0);

begin

   assert (SYNTH_MODE_G = "inferred") or (SYNTH_MODE_G = "xpm") or (SYNTH_MODE_G = "altera_mf")
      report "SimpleDualPortRam: SYNTH_MODE_G must be inferred, xpm, or altera_mf"
      severity failure;

   assert (SYNTH_MODE_G /= "inferred") or (READ_LATENCY_C = 1) or (READ_LATENCY_C = 2)
      report "SimpleDualPortRam: inferred mode supports READ_LATENCY_G = 1 or 2 because the legacy SimpleDualPortRam implementation is synchronous-read for all MEMORY_TYPE_G values"
      severity failure;

   weaVector <= weaByte when BYTE_WR_EN_G else (others => wea);

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_RAM : SimpleDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            RST_POLARITY_G      => RST_POLARITY_G,
            COMMON_CLK_G        => COMMON_CLK_G,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => MEMORY_INIT_PARAM_G,
            READ_LATENCY_G      => READ_LATENCY_C,
            DATA_WIDTH_G        => DATA_WIDTH_G,
            BYTE_WR_EN_G        => BYTE_WR_EN_G,
            BYTE_WIDTH_G        => BYTE_WIDTH_G,
            ADDR_WIDTH_G        => ADDR_WIDTH_G)
         port map (
            clka   => clka,
            ena    => ena,
            wea    => weaVector,
            addra  => addra,
            dina   => dina,
            clkb   => clkb,
            enb    => enb,
            regceb => regceb,
            rstb   => rstb,
            addrb  => addrb,
            doutb  => doutb);
   end generate;

   GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
      U_RAM : SimpleDualPortRamAlteraMf
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            COMMON_CLK_G   => COMMON_CLK_G,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => READ_LATENCY_C,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            BYTE_WR_EN_G   => BYTE_WR_EN_G,
            BYTE_WIDTH_G   => BYTE_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G)
         port map (
            clka   => clka,
            ena    => ena,
            wea    => weaVector,
            addra  => addra,
            dina   => dina,
            clkb   => clkb,
            enb    => enb,
            regceb => regceb,
            rstb   => rstb,
            addrb  => addrb,
            doutb  => doutb);
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
      U_RAM : SimpleDualPortRamInferred
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            DOB_REG_G      => DOB_REG_C,
            BYTE_WR_EN_G   => BYTE_WR_EN_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            BYTE_WIDTH_G   => BYTE_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_G)
         port map (
            clka    => clka,
            ena     => ena,
            wea     => wea,
            weaByte => weaByte,
            addra   => addra,
            dina    => dina,
            clkb    => clkb,
            enb     => enb,
            regceb  => regceb,
            rstb    => rstb,
            addrb   => addrb,
            doutb   => doutb);
   end generate;

end rtl;
