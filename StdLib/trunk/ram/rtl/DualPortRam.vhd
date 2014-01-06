-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DualPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-18
-- Last update: 2013-12-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module infers either Block RAM or distributed RAM
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity DualPortRam is
   -- MODE_G = {"no-change","read-first","write-first"}
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low      
      BRAM_EN_G      : boolean                    := true;
      REG_EN_G       : boolean                    := true;
      MODE_G         : string                     := "write-first";
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A     
      clka  : in  sl                           := '0';
      ena   : in  sl                           := '1';
      wea   : in  sl                           := '0';
      rsta  : in  sl                           := not(RST_POLARITY_G);
      addra : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dina  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      douta : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port B
      clkb  : in  sl                           := '0';
      enb   : in  sl                           := '1';
      rstb  : in  sl                           := not(RST_POLARITY_G);
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0));
end DualPortRam;

architecture mapping of DualPortRam is
   
   constant FORCE_RST_C : sl := not(RST_POLARITY_G);

begin

   GEN_BRAM : if (BRAM_EN_G = true) generate
      TrueDualPortRam_Inst : entity work.TrueDualPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            MODE_G         => MODE_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_G)
         port map (
            -- Port A     
            clka  => clka,
            ena   => ena,
            wea   => wea,
            rsta  => rsta,
            addra => addra,
            dina  => dina,
            douta => douta,
            -- Port B
            clkb  => clkb,
            enb   => enb,
            web   => '0',
            rstb  => rstb,
            addrb => addrb,
            dinb  => (others => '0'),
            doutb => doutb);           
   end generate;

   GEN_LUTRAM : if (BRAM_EN_G = false) generate
      QuadPortRam_Inst : entity work.QuadPortRam
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            REG_EN_G       => REG_EN_G,
            MODE_G         => MODE_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_G)
         port map (
            -- Port A     
            clka  => clka,
            en_a  => ena,
            wea   => wea,
            rsta  => rsta,
            addra => addra,
            dina  => dina,
            douta => douta,
            -- Port B
            clkb  => clkb,
            en_b  => enb,
            rstb  => rstb,
            addrb => addrb,
            doutb => doutb,
            -- Port C
            clkc  => '0',
            en_c  => '0',
            rstc  => FORCE_RST_C,
            addrc => (others => '0'),
            doutc => open,
            -- Port C
            clkd  => '0',
            en_d  => '0',
            rstd  => FORCE_RST_C,
            addrd => (others => '0'),
            doutd => open);
   end generate;
   
end mapping;
