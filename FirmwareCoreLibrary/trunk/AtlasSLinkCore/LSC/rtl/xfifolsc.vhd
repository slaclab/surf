-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : xfifolsc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-12
-- Last update: 2014-10-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity xfifolsc is
   generic (
      LOG2DEPTH : integer);   
   port (
      din           : in  std_logic_vector(33 downto 0);
      wr_en         : in  std_logic;
      wr_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rd_clk        : in  std_logic;
      rst           : in  std_logic;
      dout          : out std_logic_vector(33 downto 0);
      full          : out std_logic;    -- sync. to wr_clk
      overflow      : out std_logic;    -- sync. to wr_clk
      empty         : out std_logic;    -- sync. to rd_clk
      wr_data_count : out std_logic_vector((LOG2DEPTH - 1) downto 0));
end xfifolsc;

architecture mapping of xfifolsc is

begin

   FifoAsync_Inst : entity work.FifoAsync
      generic map (
         TPD_G          => 1 ns,
         RST_POLARITY_G => '1',
         BRAM_EN_G      => true,
         FWFT_EN_G      => false,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         SYNC_STAGES_G  => 3,
         PIPE_STAGES_G  => 0,
         DATA_WIDTH_G   => 34,
         ADDR_WIDTH_G   => LOG2DEPTH,
         INIT_G         => "0",
         FULL_THRES_G   => ((2**LOG2DEPTH)/2),
         EMPTY_THRES_G  => 1)
      port map (
         rst           => rst,
         wr_clk        => wr_clk,
         wr_en         => wr_en,
         din           => din,
         wr_data_count => wr_data_count,
         wr_ack        => open,
         overflow      => overflow,
         prog_full     => open,
         almost_full   => open,
         full          => full,
         not_full      => open,
         rd_clk        => rd_clk,
         rd_en         => rd_en,
         dout          => dout,
         rd_data_count => open,
         valid         => open,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => empty);

end mapping;
