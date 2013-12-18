-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-18
-- Last update: 2013-12-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module infers a Quad Port PARM 
--                as distributed RAM (series 7 FPGAs)
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity QuadPortRam is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      REG_EN_G       : boolean                    := true;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A (Read/Write)
      wea   : in  sl                           := '0';
      addra : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dina  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      douta : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port B (Read Only)
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port C (Read Only)
      addrc : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutc : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port D (Read Only)
      addrd : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutd : out slv(DATA_WIDTH_G-1 downto 0);
      -- common 
      clk   : in  sl;
      rst   : in  sl                           := '0');
begin
end QuadPortRam;

architecture rtl of QuadPortRam is
   -- Initial RAM Values
   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   shared variable mem : mem_type := (others => INIT_C);

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : variable is "distributed";

   attribute ram_extract        : string;
   attribute ram_extract of mem : variable is "TRUE";

   -- Attribute for Synplicity Synthesizer 
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : variable is "distributed";

   attribute syn_keep        : string;
   attribute syn_keep of mem : variable is "TRUE";
   
begin

   -- Port A
   process(clk)
   begin
      if rising_edge(clk) then
         if wea = '1' then
            mem(conv_integer(addra)) := dina;
         end if;
      end if;
   end process;

   PORT_A_REG : if (REG_EN_G = true) generate
      process(clk)
      begin
         if rising_edge(clk) then
            if rst = RST_POLARITY_G then
               douta <= INIT_C after TPD_G;
            else
               douta <= mem(conv_integer(addra)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_A_NOT_REG : if (REG_EN_G = false) generate
      process(addra)
      begin
         douta <= mem(conv_integer(addra));
      end process;
   end generate;

   -- Port B
   PORT_B_REG : if (REG_EN_G = true) generate
      process(clk)
      begin
         if rising_edge(clk) then
            if rst = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            else
               doutb <= mem(conv_integer(addrb)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_B_NOT_REG : if (REG_EN_G = false) generate
      process(addrb)
      begin
         doutb <= mem(conv_integer(addrb));
      end process;
   end generate;

   -- Port C
   PORT_C_REG : if (REG_EN_G = true) generate
      process(clk)
      begin
         if rising_edge(clk) then
            if rst = RST_POLARITY_G then
               doutc <= INIT_C after TPD_G;
            else
               doutc <= mem(conv_integer(addrc)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_C_NOT_REG : if (REG_EN_G = false) generate
      process(addrc)
      begin
         doutc <= mem(conv_integer(addrc));
      end process;
   end generate;

   -- Port D
   PORT_D_REG : if (REG_EN_G = true) generate
      process(clk)
      begin
         if rising_edge(clk) then
            if rst = RST_POLARITY_G then
               doutd <= INIT_C after TPD_G;
            else
               doutd <= mem(conv_integer(addrd)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_D_NOT_REG : if (REG_EN_G = false) generate
      process(addrd)
      begin
         doutd <= mem(conv_integer(addrd));
      end process;
   end generate;
   
end rtl;
