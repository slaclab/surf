-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module infers either Block RAM or distributed RAM
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


library surf;
use surf.StdRtlPkg.all;

entity DualPortRam is
   -- MODE_G = {"no-change","read-first","write-first"}
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low      
      MEMORY_TYPE_G  : string                     := "block";
      REG_EN_G       : boolean                    := true;   -- This generic only with BRAM
      DOA_REG_G      : boolean                    := false;  -- This generic only with BRAM
      DOB_REG_G      : boolean                    := false;  -- This generic only with LUTRAM
      MODE_G         : string                     := "read-first";
      BYTE_WR_EN_G   : boolean                    := false;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      BYTE_WIDTH_G   : integer                    := 8;    -- If BRAM, should be multiple of 8 or 9
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A     
      clka    : in  sl                                                    := '0';
      ena     : in  sl                                                    := '1';
      wea     : in  sl                                                    := '0';
      weaByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '1');
      rsta    : in  sl                                                    := not(RST_POLARITY_G);
      addra   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      dina    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
      douta   : out slv(DATA_WIDTH_G-1 downto 0);
      regcea  : in  sl                                                    := '1';
      -- Port B
      clkb    : in  sl                                                    := '0';
      enb     : in  sl                                                    := '1';
      rstb    : in  sl                                                    := not(RST_POLARITY_G);
      addrb   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutb   : out slv(DATA_WIDTH_G-1 downto 0);
      regceb  : in  sl                                                    := '1');
end DualPortRam;

architecture mapping of DualPortRam is

   constant FORCE_RST_C : sl := not(RST_POLARITY_G);

begin

   GEN_BRAM : if (MEMORY_TYPE_G/="distributed") generate
      TrueDualPortRam_Inst : entity surf.TrueDualPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            DOA_REG_G      => DOA_REG_G,
            DOB_REG_G      => DOB_REG_G,
            MODE_G         => MODE_G,
            BYTE_WR_EN_G   => BYTE_WR_EN_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            BYTE_WIDTH_G   => BYTE_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_G)
         port map (
            -- Port A     
            clka    => clka,
            ena     => ena,
            wea     => wea,
            weaByte => weaByte,
            rsta    => rsta,
            addra   => addra,
            dina    => dina,
            douta   => douta,
            regcea  => regcea,
            -- Port B
            clkb    => clkb,
            enb     => enb,
            web     => '0',
            rstb    => rstb,
            addrb   => addrb,
            dinb    => (others => '0'),
            doutb   => doutb,
            regceb  => regceb);
   end generate;

   GEN_LUTRAM : if (MEMORY_TYPE_G="distributed") generate
      QuadPortRam_Inst : entity surf.QuadPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            REG_EN_G       => REG_EN_G,
            MODE_G         => MODE_G,
            BYTE_WR_EN_G   => BYTE_WR_EN_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            BYTE_WIDTH_G   => BYTE_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_G)
         port map (
            -- Port A     
            clka    => clka,
            en_a    => ena,
            wea     => wea,
            weaByte => weaByte,
            rsta    => rsta,
            addra   => addra,
            dina    => dina,
            douta   => douta,
            -- Port B
            clkb    => clkb,
            en_b    => enb,
            rstb    => rstb,
            addrb   => addrb,
            doutb   => doutb,
            -- Port C
            clkc    => '0',
            en_c    => '0',
            rstc    => FORCE_RST_C,
            addrc   => (others => '0'),
            doutc   => open,
            -- Port C
            clkd    => '0',
            en_d    => '0',
            rstd    => FORCE_RST_C,
            addrd   => (others => '0'),
            doutd   => open);
   end generate;

end mapping;
