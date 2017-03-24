-------------------------------------------------------------------------------
-- File       : OctalPortRam.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-04-12
-- Last update: 2016-04-19
-------------------------------------------------------------------------------
-- Description:   This module infers a Quad Port RAM as distributed RAM
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

use work.StdRtlPkg.all;

entity OctalPortRam is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      REG_EN_G       : boolean                    := true;
      MODE_G         : string                     := "no-change";
      BYTE_WR_EN_G   : boolean                    := false;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      BYTE_WIDTH_G   : integer                    := 8;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A (Read/Write)
      clka    : in  sl                                                    := '0';
      en_a    : in  sl                                                    := '1';
      wea     : in  sl                                                    := '0';
      weaByte : in  slv(wordCount(DATA_WIDTH_G, BYTE_WIDTH_G)-1 downto 0) := (others => '0');
      rsta    : in  sl                                                    := not(RST_POLARITY_G);
      addra   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      dina    : in  slv(DATA_WIDTH_G-1 downto 0)                          := (others => '0');
      douta   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port B (Read Only)
      clkb    : in  sl                                                    := '0';
      en_b    : in  sl                                                    := '1';
      rstb    : in  sl                                                    := not(RST_POLARITY_G);
      addrb   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutb   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port C (Read Only)
      en_c    : in  sl                                                    := '1';
      clkc    : in  sl                                                    := '0';
      rstc    : in  sl                                                    := not(RST_POLARITY_G);
      addrc   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutc   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port D (Read Only)
      en_d    : in  sl                                                    := '1';
      clkd    : in  sl                                                    := '0';
      rstd    : in  sl                                                    := not(RST_POLARITY_G);
      addrd   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutd   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port E (Read Only)
      en_e    : in  sl                                                    := '1';
      clke    : in  sl                                                    := '0';
      rste    : in  sl                                                    := not(RST_POLARITY_G);
      addre   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doute   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port F (Read Only)
      en_f    : in  sl                                                    := '1';
      clkf    : in  sl                                                    := '0';
      rstf    : in  sl                                                    := not(RST_POLARITY_G);
      addrf   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutf   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port G (Read Only)
      en_g    : in  sl                                                    := '1';
      clkg    : in  sl                                                    := '0';
      rstg    : in  sl                                                    := not(RST_POLARITY_G);
      addrg   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      doutg   : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port H (Read Only)
      en_h    : in  sl                                                    := '1';
      clkh    : in  sl                                                    := '0';
      rsth    : in  sl                                                    := not(RST_POLARITY_G);
      addrh   : in  slv(ADDR_WIDTH_G-1 downto 0)                          := (others => '0');
      douth   : out slv(DATA_WIDTH_G-1 downto 0));
end OctalPortRam;

architecture rtl of OctalPortRam is

   -- Initial RAM Values
   constant NUM_BYTES_C       : natural := wordCount(DATA_WIDTH_G, BYTE_WIDTH_G);
   constant FULL_DATA_WIDTH_C : natural := NUM_BYTES_C*BYTE_WIDTH_G;

   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   signal mem : mem_type := (others => INIT_C);

   signal weaByteInt : slv(weaByte'range);

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

   weaByteInt <= weaByte when BYTE_WR_EN_G else (others => wea);


   -- Port A
   PORT_A_NOT_REG : if (REG_EN_G = false) generate

      process(clka)
      begin
         if rising_edge(clka) then
            if (en_a = '1') then
               for i in NUM_BYTES_C-1 downto 0 loop
                  if (weaByteInt(i) = '1') then
                     mem(conv_integer(addra))(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G) <=
                        dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G);
                  end if;
               end loop;
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
               if en_a = '1' then
                  for i in NUM_BYTES_C-1 downto 0 loop
                     if (weaByteInt(i) = '1') then
                        mem(conv_integer(addra))(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G) <=
                           dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G);
                     end if;
                  end loop;
               end if;
            end if;
         end process;

         process(clka)
         begin
            if rising_edge(clka) then
               if (en_a = '1' and weaByteInt = 0) then
                  douta <= mem(conv_integer(addra)) after TPD_G;
               end if;
               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
               end if;
            end if;
         end process;

      end generate;

      READ_FIRST_MODE : if MODE_G = "read-first" generate
         process(clka)
         begin
            if rising_edge(clka) then
               if en_a = '1' then
                  douta <= mem(conv_integer(addra)) after TPD_G;
                  for i in 0 to NUM_BYTES_C-1 loop
                     if (weaByteInt(i) = '1') then
                        mem(conv_integer(addra))(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G) <=
                           dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G);
                     end if;
                  end loop;
               end if;
               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
               end if;
            end if;
         end process;
      end generate;

      WRITE_FIRST_MODE : if MODE_G = "write-first" generate
         process(clka)
         begin
            if rising_edge(clka) then
               if en_a = '1' then
                  for i in NUM_BYTES_C-1 downto 0 loop
                     if (weaByteInt(i) = '1') then
                        mem(conv_integer(addra))(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G) <=
                           dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_G-1) downto i*BYTE_WIDTH_G);
                     end if;
                  end loop;
                  douta <= mem(conv_integer(addra)) after TPD_G;
               end if;

               if rsta = RST_POLARITY_G then
                  douta <= INIT_C after TPD_G;
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
            if rstd = RST_POLARITY_G then
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

   -- Port E
   PORT_E_REG : if (REG_EN_G = true) generate
      process(clke)
      begin
         if rising_edge(clke) then
            if rste = RST_POLARITY_G then
               doute <= INIT_C after TPD_G;
            elsif en_e = '1' then
               doute <= mem(conv_integer(addre)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_E_NOT_REG : if (REG_EN_G = false) generate
      doute <= mem(conv_integer(addre));
   end generate;

   -- Port F
   PORT_F_REG : if (REG_EN_G = true) generate
      process(clkf)
      begin
         if rising_edge(clkf) then
            if rstf = RST_POLARITY_G then
               doutf <= INIT_C after TPD_G;
            elsif en_f = '1' then
               doutf <= mem(conv_integer(addrf)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_F_NOT_REG : if (REG_EN_G = false) generate
      doutf <= mem(conv_integer(addrf));
   end generate;

   -- Port G
   PORT_G_REG : if (REG_EN_G = true) generate
      process(clkg)
      begin
         if rising_edge(clkg) then
            if rstg = RST_POLARITY_G then
               doutg <= INIT_C after TPD_G;
            elsif en_g = '1' then
               doutg <= mem(conv_integer(addrg)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_G_NOT_REG : if (REG_EN_G = false) generate
      doutg <= mem(conv_integer(addrg));
   end generate;

   -- Port H
   PORT_H_REG : if (REG_EN_G = true) generate
      process(clkh)
      begin
         if rising_edge(clkh) then
            if rsth = RST_POLARITY_G then
               douth <= INIT_C after TPD_G;
            elsif en_h = '1' then
               douth <= mem(conv_integer(addrh)) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   PORT_H_NOT_REG : if (REG_EN_G = false) generate
      douth <= mem(conv_integer(addrh));
   end generate;

end rtl;
