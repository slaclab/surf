-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for FWFT FIFO count testing
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library surf;
use surf.StdRtlPkg.all;

entity FwftCntWrapper is
   generic (
      TPD_G           : time    := 1 ns;
      GEN_SYNC_FIFO_G : boolean := false;
      MEMORY_TYPE_G   : string  := "block");
   port (
      clk           : in  sl;
      rst           : in  sl;
      wr_en         : in  sl;
      din           : in  slv(9 downto 0);
      wr_data_count : out slv(8 downto 0);
      wr_ack        : out sl;
      full          : out sl;
      rd_en         : in  sl;
      dout          : out slv(9 downto 0);
      rd_data_count : out slv(8 downto 0);
      valid         : out sl;
      empty         : out sl;
      overflow      : out sl;
      underflow     : out sl);
end entity FwftCntWrapper;

architecture rtl of FwftCntWrapper is

   constant ADDR_WIDTH_C : positive := ite(MEMORY_TYPE_G = "distributed", 5, 9);
   constant DATA_WIDTH_C : positive := ADDR_WIDTH_C + 1;

   signal fifoDin         : slv(DATA_WIDTH_C-1 downto 0);
   signal fifoDout        : slv(DATA_WIDTH_C-1 downto 0);
   signal fifoWrDataCount : slv(ADDR_WIDTH_C-1 downto 0);
   signal fifoRdDataCount : slv(ADDR_WIDTH_C-1 downto 0);

begin

   fifoDin <= din(DATA_WIDTH_C-1 downto 0);

   dout <= resize(fifoDout, 10);

   wr_data_count <= resize(fifoWrDataCount, 9);
   rd_data_count <= resize(fifoRdDataCount, 9);

   U_Fifo : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         FWFT_EN_G       => true,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         DATA_WIDTH_G    => DATA_WIDTH_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_C)
      port map (
         rst           => rst,
         wr_clk        => clk,
         wr_en         => wr_en,
         din           => fifoDin,
         wr_data_count => fifoWrDataCount,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => open,
         almost_full   => open,
         full          => full,
         not_full      => open,
         rd_clk        => clk,
         rd_en         => rd_en,
         dout          => fifoDout,
         rd_data_count => fifoRdDataCount,
         valid         => valid,
         underflow     => underflow,
         prog_empty    => open,
         almost_empty  => open,
         empty         => empty);

end architecture rtl;
