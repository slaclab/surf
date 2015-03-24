-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : QuadPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-18
-- Last update: 2015-03-23
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
      MODE_G         : string                     := "no-change";
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A (Read/Write)
      clka  : in  sl                           := '0';
      en_a  : in  sl                           := '1';
      wea   : in  sl                           := '0';
      rsta  : in  sl                           := not(RST_POLARITY_G);
      addra : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dina  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      douta : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port B (Read Only)
      clkb  : in  sl                           := '0';
      en_b  : in  sl                           := '1';
      rstb  : in  sl                           := not(RST_POLARITY_G);
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port C (Read Only)
      en_c  : in  sl                           := '1';
      clkc  : in  sl                           := '0';
      rstc  : in  sl                           := not(RST_POLARITY_G);
      addrc : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutc : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port D (Read Only)
      en_d  : in  sl                           := '1';
      clkd  : in  sl                           := '0';
      rstd  : in  sl                           := not(RST_POLARITY_G);
      addrd : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutd : out slv(DATA_WIDTH_G-1 downto 0));
end QuadPortRam;

architecture rtl of QuadPortRam is

   -- Initial RAM Values
   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   signal mem : mem_type := (others => INIT_C);

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : signal is "distributed";

   attribute ram_extract        : string;
   attribute ram_extract of mem : signal is "TRUE";

   -- Attribute for Synplicity Synthesizer 
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : signal is "distributed";

   attribute syn_keep        : string;
   attribute syn_keep of mem : signal is "TRUE";
   
begin

   -- MODE_G check
   assert (MODE_G = "no-change") or (MODE_G = "read-first") or (MODE_G = "write-first")
      report "MODE_G must be either no-change, read-first, or write-first"
      severity failure;

   -- Port A
   PORT_A_NOT_REG : if (REG_EN_G = false) generate
      
      process(clka)
      begin
         if rising_edge(clka) then
            if (en_a = '1') and (wea = '1') then
               mem(conv_integer(addra)) <= dina;
            end if;
         end if;
      end process;

      douta <= mem(conv_integer(addra));

      
   end generate;

   PORT_A_REG : if (REG_EN_G = true) generate
      
      NO_CHANGE_MODE : if MODE_G = "no-change" generate
         process(clka)
         begin
            if rising_edge(clka) then
               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
               elsif en_a = '1' then
                  if wea = '1' then
                     mem(conv_integer(addra)) <= dina;
                  else
                     douta <= mem(conv_integer(addra)) after TPD_G;
                  end if;
               end if;
            end if;
         end process;
      end generate;

      READ_FIRST_MODE : if MODE_G = "read-first" generate
         process(clka)
         begin
            if rising_edge(clka) then
               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
               elsif en_a = '1' then
                  douta <= mem(conv_integer(addra)) after TPD_G;
                  if wea = '1' then
                     mem(conv_integer(addra)) <= dina;
                  end if;
               end if;
            end if;
         end process;
      end generate;

      WRITE_FIRST_MODE : if MODE_G = "write-first" generate
         process(clka)
         begin
            if rising_edge(clka) then
               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
               elsif en_a = '1' then
                  if wea = '1' then
                     mem(conv_integer(addra)) <= dina;
                  end if;
                  douta <= mem(conv_integer(addra)) after TPD_G;
               end if;
            end if;
         end process;
      end generate;

   end generate;

   -- Port B
   PORT_B_REG : if (REG_EN_G = true) generate
      process(clkb)
      begin
         if rising_edge(clkb) then
            if rstb = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            elsif en_b = '1' then
               doutb <= mem(conv_integer(addrb)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_B_NOT_REG : if (REG_EN_G = false) generate
      doutb <= mem(conv_integer(addrb));
   end generate;

   -- Port C
   PORT_C_REG : if (REG_EN_G = true) generate
      process(clkc)
      begin
         if rising_edge(clkc) then
            if rstc = RST_POLARITY_G then
               doutc <= INIT_C after TPD_G;
            elsif en_c = '1' then
               doutc <= mem(conv_integer(addrc)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_C_NOT_REG : if (REG_EN_G = false) generate
      doutc <= mem(conv_integer(addrc));
   end generate;

   -- Port D
   PORT_D_REG : if (REG_EN_G = true) generate
      process(clkd)
      begin
         if rising_edge(clkd) then
            if rstc = RST_POLARITY_G then
               doutd <= INIT_C after TPD_G;
            elsif en_d = '1' then
               doutd <= mem(conv_integer(addrd)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_D_NOT_REG : if (REG_EN_G = false) generate
      doutd <= mem(conv_integer(addrd));
   end generate;
   
end rtl;
