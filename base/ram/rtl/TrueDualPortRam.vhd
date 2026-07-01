-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: True dual port RAM with backend selection
--
-- Supported RAM memory configurations:
--
-- SYNTH_MODE_G | MEMORY_TYPE_G | Effective READ_LATENCY_A_G/B_G
-- "inferred"   | "block"       |      1 ~ 2
-- "xpm"        | delegated to TrueDualPortRamXpm/vendor rules
-- "altera_mf"  | delegated to TrueDualPortRamAlteraMf/vendor rules, shared A/B latency only
--
-- The inferred implementation remains the legacy block RAM implementation,
-- now named TrueDualPortRamInferred. Its base read latency is one clock cycle.
-- DOA_REG_G and DOB_REG_G add the historical output registers. MODE_G keeps
-- the legacy {"no-change", "read-first", "write-first"} spelling and is
-- translated to XPM WRITE_MODE_G spelling when SYNTH_MODE_G = "xpm".
-- READ_LATENCY_A_G and READ_LATENCY_B_G default to -1, which selects the
-- shared READ_LATENCY_G value for that port. DO*_REG_G remains the legacy way
-- to select the 2-cycle registered-output path and must not be combined with
-- explicit shared or per-port read latency settings.
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

entity TrueDualPortRam is
   -- MODE_G = {"no-change","read-first","write-first"}
   generic (
      TPD_G               : time                       := 1 ns;
      RST_POLARITY_G      : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G         : boolean                    := false;
      DOA_REG_G           : boolean                    := false;  -- Extra output register on doutA.
      DOB_REG_G           : boolean                    := false;  -- Extra output register on doutB.
      MODE_G              : string                     := "read-first";
      BYTE_WR_EN_G        : boolean                    := false;
      DATA_WIDTH_G        : integer range 1 to (2**24) := 18;
      BYTE_WIDTH_G        : integer                    := 8;  -- Should be multiple of 8 or 9.
      ADDR_WIDTH_G        : integer range 1 to (2**24) := 9;
      INIT_G              : slv                        := "0";
      SYNTH_MODE_G        : string                     := "inferred";
      COMMON_CLK_G        : boolean                    := false;
      MEMORY_TYPE_G       : string                     := "block";
      MEMORY_INIT_FILE_G  : string                     := "none";
      MEMORY_INIT_PARAM_G : string                     := "0";
      READ_LATENCY_G      : natural range 0 to 100     := 1;
      READ_LATENCY_A_G    : integer range -1 to 100    := -1;
      READ_LATENCY_B_G    : integer range -1 to 100    := -1);
   port (
      -- Port A
      clka    : in  sl                                                    := '0';
      ena     : in  sl                                                    := '1';
      wea     : in  sl                                                    := '0';
      weaByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '0');
      rsta    : in  sl                                                    := not(RST_POLARITY_G);
      addra   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      dina    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
      douta   : out slv(DATA_WIDTH_G-1 downto 0);
      regcea  : in  sl                                                    := '1';  -- Clock enable for extra output reg. Only used when DOA_REG_G = true
      -- Port B
      clkb    : in  sl                                                    := '0';
      enb     : in  sl                                                    := '1';
      web     : in  sl                                                    := '0';
      webByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '0');
      rstb    : in  sl                                                    := not(RST_POLARITY_G);
      addrb   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      dinb    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
      doutb   : out slv(DATA_WIDTH_G-1 downto 0);
      regceb  : in  sl                                                    := '1');  -- Clock enable for extra output reg. Only used when DOB_REG_G = true
end TrueDualPortRam;

architecture rtl of TrueDualPortRam is

   function toXpmWriteMode(mode : string) return string is
   begin
      if (mode = "no-change") then
         return "no_change";
      elsif (mode = "read-first") then
         return "read_first";
      elsif (mode = "write-first") then
         return "write_first";
      else
         return mode;
      end if;
   end function;

   constant READ_LATENCY_A_BASE_C : natural := ite(READ_LATENCY_A_G < 0, READ_LATENCY_G, READ_LATENCY_A_G);
   constant READ_LATENCY_B_BASE_C : natural := ite(READ_LATENCY_B_G < 0, READ_LATENCY_G, READ_LATENCY_B_G);
   constant READ_LATENCY_A_C      : natural := ite(DOA_REG_G and (READ_LATENCY_A_BASE_C = 1), 2, READ_LATENCY_A_BASE_C);
   constant READ_LATENCY_B_C      : natural := ite(DOB_REG_G and (READ_LATENCY_B_BASE_C = 1), 2, READ_LATENCY_B_BASE_C);
   constant READ_LATENCY_C        : natural := ite(READ_LATENCY_A_C > READ_LATENCY_B_C, READ_LATENCY_A_C, READ_LATENCY_B_C);
   constant DOA_REG_C             : boolean := (READ_LATENCY_A_C = 2);
   constant DOB_REG_C             : boolean := (READ_LATENCY_B_C = 2);
   constant WRITE_MODE_C          : string  := toXpmWriteMode(MODE_G);

   signal weaVector : slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0);
   signal webVector : slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0);

begin

   assert (SYNTH_MODE_G = "inferred") or (SYNTH_MODE_G = "xpm") or (SYNTH_MODE_G = "altera_mf")
      report "TrueDualPortRam: SYNTH_MODE_G must be inferred, xpm, or altera_mf"
      severity failure;

   assert (MODE_G = "no-change") or (MODE_G = "read-first") or (MODE_G = "write-first")
      report "TrueDualPortRam: MODE_G must be no-change, read-first, or write-first"
      severity failure;

   assert (not RST_ASYNC_G) or (SYNTH_MODE_G = "inferred")
      report "TrueDualPortRam: RST_ASYNC_G is supported only for SYNTH_MODE_G = inferred"
      severity failure;

   assert (not DOA_REG_G) or (READ_LATENCY_A_G < 0)
      report "TrueDualPortRam: DOA_REG_G must not be combined with explicit READ_LATENCY_A_G"
      severity failure;

   assert (not DOB_REG_G) or (READ_LATENCY_B_G < 0)
      report "TrueDualPortRam: DOB_REG_G must not be combined with explicit READ_LATENCY_B_G"
      severity failure;

   assert (not DOA_REG_G) or (READ_LATENCY_G = 1)
      report "TrueDualPortRam: DOA_REG_G must not be combined with READ_LATENCY_G /= 1"
      severity failure;

   assert (not DOB_REG_G) or (READ_LATENCY_G = 1)
      report "TrueDualPortRam: DOB_REG_G must not be combined with READ_LATENCY_G /= 1"
      severity failure;

   assert (not DOA_REG_G) or (READ_LATENCY_A_BASE_C /= 0)
      report "TrueDualPortRam: DOA_REG_G is incompatible with effective READ_LATENCY_A_G = 0"
      severity failure;

   assert (not DOB_REG_G) or (READ_LATENCY_B_BASE_C /= 0)
      report "TrueDualPortRam: DOB_REG_G is incompatible with effective READ_LATENCY_B_G = 0"
      severity failure;

   assert (READ_LATENCY_A_C <= 100) and (READ_LATENCY_B_C <= 100)
      report "TrueDualPortRam: effective read latency must be <= 100"
      severity failure;

   assert (SYNTH_MODE_G /= "inferred") or (MEMORY_TYPE_G = "block")
      report "TrueDualPortRam: inferred mode supports MEMORY_TYPE_G = block"
      severity failure;

   assert (SYNTH_MODE_G /= "inferred") or
      (((READ_LATENCY_A_C = 1) or (READ_LATENCY_A_C = 2)) and
       ((READ_LATENCY_B_C = 1) or (READ_LATENCY_B_C = 2)))
      report "TrueDualPortRam: inferred mode supports effective READ_LATENCY_A_G/B_G = 1 or 2 because the legacy TrueDualPortRam implementation is synchronous-read"
      severity failure;

   assert (SYNTH_MODE_G /= "altera_mf") or (READ_LATENCY_A_C = READ_LATENCY_B_C)
      report "TrueDualPortRam: altera_mf mode supports only shared A/B read latency"
      severity failure;

   weaVector <= weaByte when BYTE_WR_EN_G else (others => wea);
   webVector <= webByte when BYTE_WR_EN_G else (others => web);

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_RAM : entity surf.TrueDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            RST_POLARITY_G      => RST_POLARITY_G,
            COMMON_CLK_G        => COMMON_CLK_G,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => MEMORY_INIT_PARAM_G,
            WRITE_MODE_G        => WRITE_MODE_C,
            READ_LATENCY_G      => READ_LATENCY_C,
            READ_LATENCY_A_G    => READ_LATENCY_A_C,
            READ_LATENCY_B_G    => READ_LATENCY_B_C,
            DATA_WIDTH_G        => DATA_WIDTH_G,
            BYTE_WR_EN_G        => BYTE_WR_EN_G,
            BYTE_WIDTH_G        => BYTE_WIDTH_G,
            ADDR_WIDTH_G        => ADDR_WIDTH_G)
         port map (
            clka   => clka,
            ena    => ena,
            wea    => weaVector,
            regcea => regcea,
            rsta   => rsta,
            addra  => addra,
            dina   => dina,
            douta  => douta,
            clkb   => clkb,
            enb    => enb,
            web    => webVector,
            regceb => regceb,
            rstb   => rstb,
            addrb  => addrb,
            dinb   => dinb,
            doutb  => doutb);
   end generate;

   GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
      U_RAM : entity surf.TrueDualPortRamAlteraMf
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
            regcea => regcea,
            rsta   => rsta,
            addra  => addra,
            dina   => dina,
            douta  => douta,
            clkb   => clkb,
            enb    => enb,
            web    => webVector,
            regceb => regceb,
            rstb   => rstb,
            addrb  => addrb,
            dinb   => dinb,
            doutb  => doutb);
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
      U_RAM : entity surf.TrueDualPortRamInferred
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            DOA_REG_G      => DOA_REG_C,
            DOB_REG_G      => DOB_REG_C,
            MODE_G         => MODE_G,
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
            rsta    => rsta,
            addra   => addra,
            dina    => dina,
            douta   => douta,
            regcea  => regcea,
            clkb    => clkb,
            enb     => enb,
            web     => web,
            webByte => webByte,
            rstb    => rstb,
            addrb   => addrb,
            dinb    => dinb,
            doutb   => doutb,
            regceb  => regceb);
   end generate;

end rtl;
