
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiPkgTb is

end entity AxiPkgTb;

architecture tb of AxiPkgTb is

   constant AXI_CFG_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,               -- 32-bit address interface
      DATA_BYTES_C => 16,               -- 128-bit data interface (matches the AXIS stream)
      ID_BITS_C    => 5,                -- Up to 32 DMA IDS
      LEN_BITS_C   => 8);               -- 8-bit awlen/arlen interface

   signal burstBytes : integer          := 4096;
   signal totalBytes : slv(31 downto 0) := X"7FFF0000";
   signal address    : slv(31 downto 0) := (others => '0');
   signal len        : slv(7 downto 0)  := (others => '0');

   signal clk : sl := '0';

begin

   clkproc : process is
   begin
      wait for 10 ns;
      while (true) loop
         clk <= not clk;
         wait for 5 ns;
      end loop;
   end process;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         len        <= getAxiLen(AXI_CFG_C, burstBytes, totalBytes, address) after 1 ns;
         totalBytes <= totalBytes + 1                                        after 1 ns;
      end if;
   end process seq;

end architecture tb;
