-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This will infer this module as Block RAM only
--
-- NOTE: TDP ram with read enable logic is not supported.
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

entity TrueDualPortRam is
   -- MODE_G = {"no-change","read-first","write-first"}
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      DOA_REG_G      : boolean                    := false;  -- Extra output register on doutA.
      DOB_REG_G      : boolean                    := false;  -- Extra output register on doutB.
      MODE_G         : string                     := "read-first";
      BYTE_WR_EN_G   : boolean                    := false;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 18;
      BYTE_WIDTH_G   : integer                    := 8;  -- Should be multiple of 8 or 9.
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 9;
      INIT_G         : slv                        := "0");
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
      regceb  : in  sl                                                    := '1');  -- Clock enable for extra output reg. Only used when DOA_REG_G = true
end TrueDualPortRam;

architecture rtl of TrueDualPortRam is

   -- Set byte width to word width if byte writes not enabled
   -- Otherwise block ram parity bits wont be utilized
   constant BYTE_WIDTH_C : natural := ite(BYTE_WR_EN_G, BYTE_WIDTH_G, DATA_WIDTH_G);
   constant NUM_BYTES_C       : natural := wordCount(DATA_WIDTH_G, BYTE_WIDTH_C);
   constant FULL_DATA_WIDTH_C : natural := NUM_BYTES_C*BYTE_WIDTH_C;

   constant INIT_C : slv(FULL_DATA_WIDTH_C-1 downto 0) := ite(INIT_G = "0", slvZero(FULL_DATA_WIDTH_C), INIT_G);

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(FULL_DATA_WIDTH_C-1 downto 0);
   shared variable mem : mem_type := (others => INIT_C);

   signal doutAInt : slv(FULL_DATA_WIDTH_C-1 downto 0);
   signal doutBInt : slv(FULL_DATA_WIDTH_C-1 downto 0);

   signal weaByteInt : slv(weaByte'range);
   signal webByteInt : slv(webByte'range);

   -- Attribute for XST (Xilinx Synthesizer)
   attribute ram_style        : string;
   attribute ram_style of mem : variable is "block";

   attribute ram_extract        : string;
   attribute ram_extract of mem : variable is "TRUE";

   attribute keep        : boolean;           --"keep" is same for XST and Altera
   attribute keep of mem : variable is true;  --"keep" is same for XST and Altera

   -- Attribute for Synplicity Synthesizer 
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : variable is "block";

   attribute syn_keep        : string;
   attribute syn_keep of mem : variable is "TRUE";

begin

   -- MODE_G check
   assert (MODE_G = "no-change") or (MODE_G = "read-first") or (MODE_G = "write-first")
      report "MODE_G must be either no-change, read-first, or write-first"
      severity failure;

   weaByteInt <= weaByte when BYTE_WR_EN_G else (others => wea);
   webByteInt <= webByte when BYTE_WR_EN_G else (others => web);   

   -------------------------------------------------------------------------------------------------
   -- No Change Mode
   -------------------------------------------------------------------------------------------------
   NO_CHANGE_MODE : if MODE_G = "no-change" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if (ena = '1') then
               for i in 0 to NUM_BYTES_C-1 loop
                  if (weaByteInt(i) = '1') then
                     mem(conv_integer(addra))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
            end if;
         end if;
      end process;

      -- Vivado does crazy stupid things if output isn't broken out into its own process in
      -- no-change mode
      process (clka) is
      begin
         if (rising_edge(clka)) then
            if (ena = '1' and weaByte = 0 and wea = '0') then
               doutAInt <= mem(conv_integer(addra)) after TPD_G;
            end if;
            if rsta = RST_POLARITY_G and DOA_REG_G = false then
               doutAInt <= INIT_C after TPD_G;
            end if;
         end if;
      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if (enb = '1') then
               for i in 0 to NUM_BYTES_C-1 loop
                  if (webByteInt(i) = '1') then
                     mem(conv_integer(addrb))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dinb(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
            end if;
         end if;
      end process;

      process (clkb) is
      begin
         if (rising_edge(clkb)) then
            if (enb = '1' and webByte = 0 and web = '0') then
               doutBInt <= mem(conv_integer(addrb)) after TPD_G;
            end if;
            if rstb = RST_POLARITY_G and DOB_REG_G = false then
               doutBInt <= INIT_C after TPD_G;
            end if;
         end if;
      end process;

   end generate;

   -------------------------------------------------------------------------------------------------
   -- Read first mode
   -------------------------------------------------------------------------------------------------
   READ_FIRST_MODE : if MODE_G = "read-first" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if (ena = '1') then
               doutAInt <= mem(conv_integer(addra)) after TPD_G;
               for i in 0 to NUM_BYTES_C-1 loop
                  if (weaByteInt(i) = '1') then
                     mem(conv_integer(addra))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
            end if;
            if rsta = RST_POLARITY_G and DOA_REG_G = false then
               doutAInt <= INIT_C after TPD_G;
            end if;
         end if;
      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if (enb = '1') then
               doutBInt <= mem(conv_integer(addrb)) after TPD_G;
               for i in 0 to NUM_BYTES_C-1 loop
                  if (webByteInt(i) = '1') then
                     mem(conv_integer(addrb))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dinb(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
            end if;
            if rstb = RST_POLARITY_G and DOB_REG_G = false then
               doutBInt <= INIT_C after TPD_G;
            end if;
         end if;
      end process;

   end generate;

   -------------------------------------------------------------------------------------------------
   -- Write first mode
   -------------------------------------------------------------------------------------------------
   WRITE_FIRST_MODE : if MODE_G = "write-first" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if (ena = '1') then
               for i in 0 to NUM_BYTES_C-1 loop
                  if (weaByteInt(i) = '1') then
                     mem(conv_integer(addra))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dina(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
               doutAInt <= mem(conv_integer(addra)) after TPD_G;
            end if;
            if rsta = RST_POLARITY_G and DOA_REG_G = false then
               doutAInt <= INIT_C after TPD_G;
            end if;
         end if;

      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if (enb = '1') then
               for i in 0 to NUM_BYTES_C-1 loop
                  if (webByteInt(i) = '1') then
                     mem(conv_integer(addrb))((i+1)*BYTE_WIDTH_C-1 downto i*BYTE_WIDTH_C) :=
                        resize(dinb(minimum(DATA_WIDTH_G-1, (i+1)*BYTE_WIDTH_C-1) downto i*BYTE_WIDTH_C), BYTE_WIDTH_C);
                  end if;
               end loop;
               doutBInt <= mem(conv_integer(addrb)) after TPD_G;
            end if;
            if rstb = RST_POLARITY_G and DOB_REG_G = false then
               doutBInt <= INIT_C after TPD_G;
            end if;
         end if;

      end process;

   end generate;

   -------------------------------------------------------------------------------------------------
   -- Optional data output registers
   -------------------------------------------------------------------------------------------------
   NO_DOUT_A_REG : if (not DOA_REG_G) generate
      douta <= doutAInt(DATA_WIDTH_G-1 downto 0);
   end generate NO_DOUT_A_REG;

   DOUT_A_REG : if (DOA_REG_G) generate
      process (clka) is
      begin
         if (rising_edge(clka)) then
            if (rstA = RST_POLARITY_G) then
               douta <= (others => '0') after TPD_G;
            elsif (regcea = '1') then
               douta <= doutAInt(DATA_WIDTH_G-1 downto 0) after TPD_G;
            end if;
         end if;
      end process;
   end generate DOUT_A_REG;

   NO_DOUT_B_REG : if (not DOB_REG_G) generate
      doutb <= doutBInt(DATA_WIDTH_G-1 downto 0);
   end generate NO_DOUT_B_REG;

   DOUT_B_REG : if (DOB_REG_G) generate
      process (clkb) is
      begin
         if (rising_edge(clkb)) then
            if (rstB = RST_POLARITY_G) then
               doutb <= (others => '0') after TPD_G;
            elsif (regceb = '1') then
               doutb <= doutBInt(DATA_WIDTH_G-1 downto 0) after TPD_G;
            end if;
         end if;
      end process;
   end generate DOUT_B_REG;

end rtl;
