-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Decoder8b10b.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-15
-- Last update: 2013-05-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;

entity Decoder8b10b is
   
   generic (
      TPD_G       : time     := 1 ns;
      NUM_BYTES_G : positive := 2);

   port (
      clk      : in  sl;
      rstL     : in  sl;
      dataIn   : in  slv(NUM_BYTES_G*10-1 downto 0);
      dataOut  : out slv(NUM_BYTES_G*8-1 downto 0);
      dataKOut : out slv(NUM_BYTES_G-1 downto 0);
      codeErr  : out slv(NUM_BYTES_G-1 downto 0);
      dispErr  : out slv(NUM_BYTES_G-1 downto 0));

end entity Decoder8b10b;

architecture rtl of Decoder8b10b is

   type RegType is record
      runDisp  : sl;
      dataOut  : slv(NUM_BYTES_G*8-1 downto 0);
      dataKOut : slv(NUM_BYTES_G-1 downto 0);
      codeErr  : slv(NUM_BYTES_G-1 downto 0);
      dispErr  : slv(NUM_BYTES_G-1 downto 0);
   end record RegType;

   signal r, rin : RegType;

begin

   comb : process (r, dataIn) is
      variable v            : RegType;
      variable dispChainVar : sl;
   begin
      v            := r;
      dispChainVar := r.runDisp;
      for i in 0 to NUM_BYTES_G-1 loop
         decode8b10b(dataIn   => dataIn(i*10+9 downto i*10),
                     dispIn   => dispChainVar,
                     dataOut  => v.dataOut(i*8+7 downto i*8),
                     dataKOut => v.dataKOut(i),
                     dispOut  => dispChainVar,
                     codeErr  => v.codeErr(i),
                     dispErr  => v.dispErr(i));
      end loop;
      v.runDisp := dispChainVar;

      rin      <= v;
      dataOut  <= r.dataOut;
      dataKOut <= r.dataKOut;
      codeErr  <= r.codeErr;
      dispErr  <= r.dispErr;
   end process comb;

   seq : process (clk, rstL) is
   begin
      if (rstL = '0') then
         r.runDisp  <= '0';
         r.dataOut  <= (others => '0');
         r.dataKOut <= (others => '0');
         r.codeErr  <= (others => '0');
         r.dispErr  <= (others => '0');
      elsif (rising_edge(clk)) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
