-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This will infer this module as either Block RAM or distributed RAM
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
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean                    := false;
      MEMORY_TYPE_G  : string                     := "block";
      DOB_REG_G      : boolean                    := false;  -- Extra reg on doutb (folded into BRAM)
      BYTE_WR_EN_G   : boolean                    := false;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      BYTE_WIDTH_G   : integer                    := 8;  -- If BRAM, should be multiple or 8 or 9
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
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

   -- Set byte width to word width if byte writes not enabled
   -- Otherwise block ram parity bits wont be utilized
   constant BYTE_WIDTH_C      : natural := ite(BYTE_WR_EN_G, BYTE_WIDTH_G, DATA_WIDTH_G);
   constant NUM_BYTES_C       : natural := wordCount(DATA_WIDTH_G, BYTE_WIDTH_C);
   constant FULL_DATA_WIDTH_C : natural := NUM_BYTES_C*BYTE_WIDTH_C;

   constant INIT_C : slv(FULL_DATA_WIDTH_C-1 downto 0) := ite(INIT_G = "0", slvZero(FULL_DATA_WIDTH_C), INIT_G);

   constant XST_BRAM_STYLE_C : string := MEMORY_TYPE_G;

   -- Shared memory
   type MemType is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(FULL_DATA_WIDTH_C-1 downto 0);
   shared variable mem : MemType := (others => INIT_C);

   signal doutBInt : slv(FULL_DATA_WIDTH_C-1 downto 0) := (others => '0');

   signal weaByteInt : slv(weaByte'range) := (others => '0');

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : variable is XST_BRAM_STYLE_C;

   attribute ram_extract        : string;
   attribute ram_extract of mem : variable is "TRUE";

   -- Attribute for Synplicity Synthesizer
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : variable is XST_BRAM_STYLE_C;

   attribute syn_keep        : string;
   attribute syn_keep of mem : variable is "TRUE";

begin

   weaByteInt <= weaByte when BYTE_WR_EN_G else (others => wea);

   -- Port A
   process(clka)
   begin
      if rising_edge(clka) then
         if ena = '1' then
            for i in NUM_BYTES_C-1 downto 0 loop
               if (weaByteInt(i) = '1') then
                  mem(conv_integer(addra))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                     resize(dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
               end if;
            end loop;
         end if;
      end if;
   end process;

   -- Port B
   process(clkb, rstb)
   begin
      if (RST_ASYNC_G and rstb = RST_POLARITY_G) then
         doutBInt <= INIT_C after TPD_G;
      elsif rising_edge(clkb) then
         if (RST_ASYNC_G = false and rstb = RST_POLARITY_G) then
            doutBInt <= INIT_C after TPD_G;
         elsif enb = '1' then
            doutBInt <= mem(conv_integer(addrb)) after TPD_G;
         end if;
      end if;
   end process;

   NO_REG : if (not DOB_REG_G) generate
      doutb <= doutBInt(DATA_WIDTH_G-1 downto 0);
   end generate NO_REG;

   REG : if (DOB_REG_G) generate
      process (clkb)
      begin
         if (rising_edge(clkb)) then
            if regceb = '1' then
               doutb <= doutBInt(DATA_WIDTH_G-1 downto 0) after TPD_G;
            end if;
         end if;
      end process;
   end generate REG;

end rtl;
