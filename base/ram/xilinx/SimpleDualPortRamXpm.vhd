-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for XPM True Dual Port RAM
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

library xpm;
use xpm.vcomponents.all;

entity SimpleDualPortRamXpm is
   generic (
      TPD_G               : time                       := 1 ns;
      COMMON_CLK_G        : boolean                    := false;
      RST_POLARITY_G      : sl                         := '1';  -- '1' for active high rst, '0' for active low       
      MEMORY_TYPE_G       : string                     := "block";
      MEMORY_INIT_FILE_G  : string                     := "none";
      MEMORY_INIT_PARAM_G : string                     := "0";
      READ_LATENCY_G      : natural range 0 to 100     := 1;
      DATA_WIDTH_G        : integer range 1 to (2**24) := 16;
      BYTE_WR_EN_G        : boolean                    := false;
      BYTE_WIDTH_G        : integer range 8 to 9       := 8;  -- If BRAM, should be multiple or 8 or 9
      ADDR_WIDTH_G        : integer range 1 to (2**24) := 4);
   port (
      -- Port A     
      clka   : in  sl                                                                          := '0';
      ena    : in  sl                                                                          := '1';
      wea    : in  slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0) := (others => '0');
      addra  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
      dina   : in  slv(DATA_WIDTH_G-1 downto 0)                                                := (others => '0');
      -- Port B
      clkb   : in  sl                                                                          := '0';
      enb    : in  sl                                                                          := '1';
      regceb : in  sl                                                                          := '1';
      rstb   : in  sl                                                                          := not(RST_POLARITY_G);
      addrb  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
      doutb  : out slv(DATA_WIDTH_G-1 downto 0));
end SimpleDualPortRamXpm;

architecture rtl of SimpleDualPortRamXpm is

   signal resetB : sl;

begin

   U_RAM : xpm_memory_sdpram
      generic map (
         ADDR_WIDTH_A            => ADDR_WIDTH_G,
         ADDR_WIDTH_B            => ADDR_WIDTH_G,
         AUTO_SLEEP_TIME         => 0,  -- 0 - Disable auto-sleep feature
         BYTE_WRITE_WIDTH_A      => ite(BYTE_WR_EN_G, BYTE_WIDTH_G, DATA_WIDTH_G),
         CLOCKING_MODE           => ite(COMMON_CLK_G, "common_clock", "independent_clock"),
         ECC_MODE                => "no_ecc",         -- Default value = no_ecc
         MEMORY_INIT_FILE        => MEMORY_INIT_FILE_G,
         MEMORY_INIT_PARAM       => MEMORY_INIT_PARAM_G,
         MEMORY_OPTIMIZATION     => "true",           -- Default value = true
         MEMORY_PRIMITIVE        => MEMORY_TYPE_G,
         MEMORY_SIZE             => (DATA_WIDTH_G*(2**ADDR_WIDTH_G)),
         MESSAGE_CONTROL         => 0,  -- Default value = 0
         READ_DATA_WIDTH_B       => DATA_WIDTH_G,
         READ_LATENCY_B          => READ_LATENCY_G,
         USE_EMBEDDED_CONSTRAINT => 0,  -- Default value = 0
         USE_MEM_INIT            => 1,  -- Default value = 1
         WAKEUP_TIME             => "disable_sleep",  -- "disable_sleep" to disable dynamic power saving option
         WRITE_DATA_WIDTH_A      => DATA_WIDTH_G,
         WRITE_MODE_B            => ite(READ_LATENCY_G = 0, "read_first", ite(MEMORY_TYPE_G = "block", "no_change", "read_first")))  -- Default value = no_change
      port map (
         -- Write Interface
         ena            => ena,
         clka           => clka,
         addra          => addra,
         dina           => dina,
         wea            => wea,
         -- Read Interface
         enb            => enb,
         clkb           => clkb,
         addrb          => addrb,
         doutb          => doutb,
         regceb         => regceb,
         -- Misc.Interface
         rstb           => resetB,
         dbiterrb       => open,
         sbiterrb       => open,
         injectdbiterra => '0',
         injectsbiterra => '0',
         sleep          => '0');

   resetB <= rstb when(RST_POLARITY_G = '1') else not(rstb);

end rtl;
