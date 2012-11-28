-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Decoder8b10b.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-15
-- Last update: 2012-11-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity Decoder8b10b is
  
  generic (
    TPD_G       : time     := 1 ns;
    NUM_BYTES_G : positive := 1);

  port (
    clk      : in  std_logic;
    rstN     : in  std_logic;
    dataIn   : in  std_logic_vector(NUM_BYTES_G*10-1 downto 0);
    dataOut  : out std_logic_vector(NUM_BYTES_G*8-1 downto 0);
    dataKOut : out std_logic_vector(NUM_BYTES_G-1 downto 0);
    codeErr  : out std_logic_vector(NUM_BYTES_G-1 downto 0);
    dispErr  : out std_logic_vector(NUM_BYTES_G-1 downto 0));

end entity Decoder8b10b;

architecture rtl of Decoder8b10b is

  component decode_8b10b is
    port (
      datain   : in  std_logic_vector(9 downto 0);
      dispin   : in  std_logic;
      dataout  : out std_logic_vector(8 downto 0);
      dispout  : out std_logic;
      code_err : out std_logic;
      disp_err : out std_logic);
  end component;

--  type RegType is record
--    runDisp : std_logic;
--    dataOut  : std_logic_vector(NUM_BYTES_G*8-1 downto 0);
--    dataKOut : std_logic_vector(NUM_BYTES_G-1 downto 0);
--    codeErr  : std_logic_vector(NUM_BYTES_G-1 downto 0);
--    dispErr  : std_logic_vector(NUM_BYTES_G-1 downto 0))
--  end record RegType;

--  signal r, rin : RegType;
  signal dispChain   : std_logic_vector(NUM_BYTES_G-1 downto 0);
  signal intDataOut  : std_logic_vector(NUM_BYTES_G*8-1 downto 0);
  signal intDataKOut : std_logic_vector(NUM_BYTES_G-1 downto 0);
  signal intCodeErr  : std_logic_vector(NUM_BYTES_G-1 downto 0);
  signal intDispErr  : std_logic_vector(NUM_BYTES_G-1 downto 0);
  signal runDisp     : std_logic;

begin


  decode_8b10b_0 : decode_8b10b
    port map (
      datain              => dataIn(9 downto 0),
      dispin              => runDisp,
      dataout(7 downto 0) => intDataOut(7 downto 0),
      dataout(8)          => intDataKOut(0),
      dispout             => dispChain(0),
      code_err            => intCodeErr(0),
      disp_err            => intDispErr(0));

  multi_byte : if (NUM_BYTES_G > 1) generate
    mult_byte_for : for i in 1 to NUM_BYTES_G-1 generate
      decode_8b10b_0 : decode_8b10b
        port map (
          datain              => dataIn(i*10+9 downto i*10),
          dispin              => dispChain(i-1),
          dataout(7 downto 0) => intDataOut(i*8+7 downto i*8),
          dataout(8)          => intDataKOut(i),
          dispout             => dispChain(i),
          code_err            => intCodeErr(i),
          disp_err            => intDispErr(i));
    end generate mult_byte_for;
  end generate multi_byte;

  regs : process (clk, rstN) is
  begin
    if (rstN = '0') then
      dataOut  <= (others => '0') after TPD_G;
      dataKOut <= (others => '0') after TPD_G;
      codeErr  <= (others => '0') after TPD_G;
      dispErr  <= (others => '0') after TPD_G;
      runDisp  <= '0'             after TPD_G;
    elsif (rising_edge(clk)) then
      dataOut  <= intDataOut               after TPD_G;
      dataKOut <= intDataKOut              after TPD_G;
      codeErr  <= intCodeErr               after TPD_G;
      dispErr  <= intDispErr               after TPD_G;
      runDisp  <= dispChain(NUM_BYTES_G-1) after TPD_G;
    end if;
  end process regs;

end architecture rtl;
