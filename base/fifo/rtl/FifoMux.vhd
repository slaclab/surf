-------------------------------------------------------------------------------
-- File       : FifoMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-24
-- Last update: 2015-01-14
-------------------------------------------------------------------------------
-- Description: Resizing FIFO module
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity FifoMux is
   generic (
      TPD_G              : time                       := 1 ns;
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      LAST_STAGE_ASYNC_G : boolean                    := true;  -- if set to true, the last stage will be the ASYNC FIFO
      RST_POLARITY_G     : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G        : boolean                    := false;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      BRAM_EN_G          : boolean                    := true;
      FWFT_EN_G          : boolean                    := true;
      USE_DSP48_G        : string                     := "no";
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      USE_BUILT_IN_G     : boolean                    := false;  -- If set to true, this module is only Xilinx compatible only!!!
      XIL_DEVICE_G       : string                     := "7SERIES";  -- Xilinx only generic parameter    
      SYNC_STAGES_G      : integer range 3 to (2**24) := 3;
      PIPE_STAGES_G      : natural range 0 to 16      := 0;
      WR_DATA_WIDTH_G    : integer range 1 to (2**24) := 64;
      RD_DATA_WIDTH_G    : integer range 1 to (2**24) := 16;
      LITTLE_ENDIAN_G    : boolean                    := false;
      ADDR_WIDTH_G       : integer range 4 to 48      := 10;
      INIT_G             : slv                        := "0";
      FULL_THRES_G       : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G      : integer range 1 to (2**24) := 1);
   port (
      -- Resets
      rst           : in  sl := '0';    --  Reset
      --Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl := '0';
      din           : in  slv(WR_DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl;
      --Read Ports (rd_clk domain)
      rd_clk        : in  sl;           --unused if GEN_SYNC_FIFO_G = true
      rd_en         : in  sl := '0';
      dout          : out slv(RD_DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
end FifoMux;

architecture rtl of FifoMux is

   constant FIFO_DATA_WIDTH_C : integer := ite(WR_DATA_WIDTH_G > RD_DATA_WIDTH_G, WR_DATA_WIDTH_G, RD_DATA_WIDTH_G);

   ----------------
   -- Write Signals
   ----------------
   constant WR_LOGIC_EN_C : boolean := (WR_DATA_WIDTH_G < RD_DATA_WIDTH_G);
   constant WR_SIZE_C     : integer := ite(WR_LOGIC_EN_C, RD_DATA_WIDTH_G / WR_DATA_WIDTH_G, 1);

   type WrDataArray is array (0 to WR_SIZE_C-1) of slv(WR_DATA_WIDTH_G-1 downto 0);
   type WrRegType is record
      count  : unsigned(bitSize(WR_SIZE_C)-1 downto 0);
      wrData : WrDataArray;
      wrEn   : sl;
   end record WrRegType;

   constant WR_REG_INIT_C : WrRegType := (
      count  => (others => '0'),
      wrData => (others => (others => '0')),
      wrEn   => '0');

   signal wrR, wrRin : WrRegType := WR_REG_INIT_C;
   signal fifo_din   : slv(FIFO_DATA_WIDTH_C-1 downto 0);
   signal fifo_wr_en : sl;
   signal wrRst      : sl;

   ---------------
   -- Read Signals
   ---------------
   constant RD_LOGIC_EN_C : boolean := (RD_DATA_WIDTH_G < WR_DATA_WIDTH_G);
   constant RD_SIZE_C     : integer := ite(RD_LOGIC_EN_C, WR_DATA_WIDTH_G / RD_DATA_WIDTH_G, 1);

   type RdRegType is record
      count : unsigned(bitSize(RD_SIZE_C)-1 downto 0);
   end record RdRegType;

   constant RD_REG_INIT_C : RdRegType := (
      count => (others => '0'));

   type RdDataArray is array (0 to RD_SIZE_C-1) of slv(RD_DATA_WIDTH_G-1 downto 0);

   signal rdR, rdRin   : RdRegType := RD_REG_INIT_C;
   signal fifo_dout    : slv(FIFO_DATA_WIDTH_C-1 downto 0);
   signal fifo_rd_data : slv(RD_DATA_WIDTH_G-1 downto 0);
   signal fifo_valid   : sl;
   signal fifo_rd_en   : sl;
   signal fifo_empty   : sl;
   signal rdRst        : sl;

begin

   assert ((WR_DATA_WIDTH_G >= RD_DATA_WIDTH_G and WR_DATA_WIDTH_G mod RD_DATA_WIDTH_G = 0) or
           (RD_DATA_WIDTH_G > WR_DATA_WIDTH_G and RD_DATA_WIDTH_G mod WR_DATA_WIDTH_G = 0))
      report "FifoMux: Data widths must be even number multiples of each other"
      severity failure;

   assert ((FWFT_EN_G = false and RD_DATA_WIDTH_G >= WR_DATA_WIDTH_G) or FWFT_EN_G)
      report "FifoMux: non-FWFT mode can only be used if the read width is >= the write data width"
      severity failure;

   --------------
   -- Write Logic
   --------------
   wrComb : process (din, wrR, wr_en) is
      variable v     : WrRegType;
      variable index : integer;
      variable high  : integer;
      variable low   : integer;
   begin
      v := wrR;

      v.wrEn := '0';

      if (wr_en = '1') then
         v.wrData(to_integer(wrR.count)) := din;
         v.count                         := wrR.count + 1;
         if (wrR.count = WR_SIZE_C-1) then
            v.count := (others => '0');
            v.wrEn  := '1';
         end if;
      end if;

      wrRin <= v;

      if (RD_DATA_WIDTH_G > WR_DATA_WIDTH_G) then
         for i in 0 to WR_SIZE_C-1 loop
            index                     := ite(LITTLE_ENDIAN_G, i, WR_SIZE_C-1-i);
            high                      := index * WR_DATA_WIDTH_G + WR_DATA_WIDTH_G - 1;
            low                       := index * WR_DATA_WIDTH_G;
            fifo_din(high downto low) <= wrR.wrData(i);
         end loop;
         fifo_wr_en <= wrR.wrEn;
      else
         fifo_din   <= din;
         fifo_wr_en <= wr_en;
      end if;

   end process wrComb;

   wrSeq : process (rst, wr_clk) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         wrR <= WR_REG_INIT_C after TPD_G;
      elsif (rising_edge(wr_clk)) then
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            wrR <= WR_REG_INIT_C after TPD_G;
         else
            wrR <= wrRin after TPD_G;
         end if;
      end if;
   end process wrSeq;

   -------------
   -- Read logic
   -------------
   -- Module reset should be driven by wr_clk
   -- Must synchronize it over to the rd_clk
   RstSync_RdRst : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => RST_POLARITY_G,
         OUT_POLARITY_G => RST_POLARITY_G)
      port map (
         clk      => rd_clk,
         asyncRst => rst,
         syncRst  => rdRst);

   rdComb : process (fifo_dout, fifo_empty, fifo_valid, rdR, rd_en) is
      variable v      : RdRegType;
      variable rdData : RdDataArray;
      variable index  : integer;
      variable high   : integer;
      variable low    : integer;
   begin
      v := rdR;

      --check for normal read
      if (rd_en = '1' and fifo_valid = '1') then
         v.count := rdR.count + 1;
         if (rdR.count = RD_SIZE_C-1) then
            v.count := (others => '0');
         end if;
      end if;

      -- Separate fifo_dout into an array of RD_DATA_WIDTH_G sized vectors
      for i in 0 to RD_SIZE_C-1 loop
         index     := ite(LITTLE_ENDIAN_G, i, RD_SIZE_C-1-i);
         high      := index * RD_DATA_WIDTH_G + RD_DATA_WIDTH_G - 1;
         low       := index * RD_DATA_WIDTH_G;
         rdData(i) := fifo_dout(high downto low);
      end loop;

      rdRin <= v;

      if (RD_DATA_WIDTH_G < WR_DATA_WIDTH_G) then
         fifo_rd_en <= toSl(rdR.count = (RD_SIZE_C-1));
         dout       <= rdData(to_integer(rdR.count));
         valid      <= fifo_valid;
         empty      <= fifo_empty;
      else
         fifo_rd_en <= rd_en;
         dout       <= fifo_dout;
         valid      <= fifo_valid;
         empty      <= fifo_empty;
      end if;
      
   end process rdComb;

   -- If fifo is asynchronous, must use async reset on rd side.
   rdSeq : process (rdRst, rd_clk) is
   begin
      if (GEN_SYNC_FIFO_G = false and rdRst = RST_POLARITY_G) then
         rdR <= RD_REG_INIT_C after TPD_G;
      elsif (rising_edge(rd_clk)) then
         if (GEN_SYNC_FIFO_G and RST_ASYNC_G = false and rdRst = RST_POLARITY_G) then
            rdR <= RD_REG_INIT_C after TPD_G;
         else
            rdR <= rdRin after TPD_G;
         end if;
      end if;
   end process rdSeq;

   --------
   -- Fifo
   --------
   FifoCascade_Inst : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => LAST_STAGE_ASYNC_G,
         RST_POLARITY_G     => RST_POLARITY_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => BRAM_EN_G,
         FWFT_EN_G          => FWFT_EN_G,
         USE_DSP48_G        => USE_DSP48_G,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => SYNC_STAGES_G,
         PIPE_STAGES_G      => PIPE_STAGES_G,
         DATA_WIDTH_G       => FIFO_DATA_WIDTH_C,
         ADDR_WIDTH_G       => ADDR_WIDTH_G,
         INIT_G             => INIT_G,
         FULL_THRES_G       => FULL_THRES_G,
         EMPTY_THRES_G      => EMPTY_THRES_G)
      port map (
         rst           => rst,
         wr_clk        => wr_clk,
         wr_en         => fifo_wr_en,
         din           => fifo_din,
         wr_data_count => wr_data_count,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => prog_full,
         almost_full   => almost_full,
         full          => full,
         not_full      => not_full,
         rd_clk        => rd_clk,
         rd_en         => fifo_rd_en,
         dout          => fifo_dout,
         rd_data_count => rd_data_count,
         valid         => fifo_valid,
         underflow     => underflow,
         prog_empty    => prog_empty,
         almost_empty  => almost_empty,
         empty         => fifo_empty);

end architecture rtl;
