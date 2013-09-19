-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoMux.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-24
-- Last update: 2013-09-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--
-- Dependencies:  ^/StdLib/trunk/rtl/Fifo.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity FifoMux is
   generic (
      TPD_G           : time                       := 1 ns;
      RST_POLARITY_G  : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G     : boolean                    := false;
      GEN_SYNC_FIFO_G : boolean                    := false;
      BRAM_EN_G       : boolean                    := true;
      FWFT_EN_G       : boolean                    := true;
      USE_DSP48_G     : string                     := "no";
      ALTERA_SYN_G    : boolean                    := false;
      ALTERA_RAM_G    : string                     := "M9K";
      USE_BUILT_IN_G  : boolean                    := false;  --if set to true, this module is only xilinx compatible only!!!
      XIL_DEVICE_G    : string                     := "7SERIES";  --xilinx only generic parameter    
      SYNC_STAGES_G   : integer range 2 to (2**24) := 2;
      WR_DATA_WIDTH_G : integer range 1 to (2**24) := 64;
      RD_DATA_WIDTH_G : integer range 1 to (2**24) := 16;
      LITTLE_ENDIAN_G : boolean                    := false;
      ADDR_WIDTH_G    : integer range 4 to 48      := 10;
      INIT_G          : slv                        := "0";
      FULL_THRES_G    : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G   : integer range 0 to (2**24) := 0);
   port (
      -- Resets
      rst          : in  sl := '0';     --  Reset
      --Write Ports (wr_clk domain)
      wr_clk       : in  sl;
      wr_en        : in  sl := '0';
      din          : in  slv(WR_DATA_WIDTH_G-1 downto 0);
--      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack       : out sl;
      overflow     : out sl;
      prog_full    : out sl;
      almost_full  : out sl;
      full         : out sl;
      --Read Ports (rd_clk domain)
      rd_clk       : in  sl;            --unused if GEN_SYNC_FIFO_G = true
      rd_en        : in  sl := '0';
      dout         : out slv(RD_DATA_WIDTH_G-1 downto 0);
--      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid        : out sl;
      underflow    : out sl;
      prog_empty   : out sl;
      almost_empty : out sl;
      empty        : out sl);
begin
   assert ((WR_DATA_WIDTH_G >= RD_DATA_WIDTH_G and WR_DATA_WIDTH_G mod RD_DATA_WIDTH_G = 0) or
           (RD_DATA_WIDTH_G > WR_DATA_WIDTH_G and RD_DATA_WIDTH_G mod WR_DATA_WIDTH_G = 0))
      report "Data widths must be even number multipes of each other" severity failure;
end FifoMux;

architecture rtl of FifoMux is

   constant FIFO_DATA_WIDTH_C : integer := ite(WR_DATA_WIDTH_G > RD_DATA_WIDTH_G, WR_DATA_WIDTH_G, RD_DATA_WIDTH_G);

   -------------------------------------------------------------------------------------------------
   constant WR_LOGIC_EN_C : boolean := (WR_DATA_WIDTH_G < RD_DATA_WIDTH_G);
   constant WR_SIZE_C     : integer := ite(WR_LOGIC_EN_C, RD_DATA_WIDTH_G / WR_DATA_WIDTH_G, 1);

   type WrDataArray is array (0 to WR_SIZE_C-1) of slv(WR_DATA_WIDTH_G-1 downto 0);
   type WrRegType is record
      count  : unsigned(log2(WR_SIZE_C)-1 downto 0);
      wrData : WrDataArray;
      wrEn   : sl;
   end record WrRegType;

   constant WR_REG_INIT_C : WrRegType := (
      count  => (others => '0'),
      wrData => (others => (others => '0')),
      wrEn   => '0');

   signal   wrR, wrRin    : WrRegType := WR_REG_INIT_C;
   signal   fifo_din      : slv(FIFO_DATA_WIDTH_C-1 downto 0);
   signal   fifo_wr_en    : sl;
   signal   wrRst         : sl;
   -------------------------------------------------------------------------------------------------
   constant RD_LOGIC_EN_C : boolean   := (RD_DATA_WIDTH_G < WR_DATA_WIDTH_G);
   constant RD_SIZE_C     : integer   := ite(RD_LOGIC_EN_C, WR_DATA_WIDTH_G / RD_DATA_WIDTH_G, 1);

   type RdRegType is record
      count  : unsigned(log2(RD_SIZE_C)-1 downto 0);
      rdData : slv(RD_DATA_WIDTH_G-1 downto 0);
      rdEn   : sl;
      valid  : sl;
      empty  : sl;
   end record RdRegType;

   constant RD_REG_INIT_C : RdRegType := (
      count  => to_unsigned(ite(FWFT_EN_G, 0, RD_SIZE_C-1), log2(RD_SIZE_C)),
      rdData => (others => '0'),
      rdEn   => '0',
      valid  => '0',
      empty  => '1');

   type RdDataArray is array (0 to RD_SIZE_C-1) of slv(RD_DATA_WIDTH_G-1 downto 0);


   signal rdR, rdRin : RdRegType := RD_REG_INIT_C;
   signal fifo_dout  : slv(FIFO_DATA_WIDTH_C-1 downto 0);
   signal fifo_valid : sl;
   signal fifo_rd_en : sl;
   signal fifo_empty : sl;
   signal rdRst      : sl;
   -------------------------------------------------------------------------------------------------

   
begin

   -------------------------------------------------------------------------------------------------
   -- Write Logic
   -------------------------------------------------------------------------------------------------
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

   -------------------------------------------------------------------------------------------------
   -- Read logic
   -------------------------------------------------------------------------------------------------
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

      if (FWFT_EN_G) then

         -- Increment counter every external read
         if (rd_en = '1') then
            v.count := rdR.count + 1;
            if (rdR.count = RD_SIZE_C-1) then
               v.count := (others => '0');
            end if;
         end if;

         -- Delay valid by 1 cycle to matchup with data
         v.empty := fifo_empty;
         v.valid := fifo_valid;

         -- Separate fifo_dout into an array of RD_DATA_WIDTH_G sized vectors
         for i in 0 to RD_SIZE_C-1 loop
            index     := ite(LITTLE_ENDIAN_G, i, RD_SIZE_C-1-i);
            high      := index * RD_DATA_WIDTH_G + RD_DATA_WIDTH_G - 1;
            low       := index * RD_DATA_WIDTH_G;
            rdData(i) := fifo_dout(high downto low);
         end loop;

         -- Select word for output
         if (fifo_valid = '1') then
            v.rdData := rdData(to_integer(v.count));
         end if;

         -- Send read to fifo so next word will be ready as last of current word goes out
         v.rdEn := '0';
         if (v.count = RD_SIZE_C-2) then
            v.rdEn := '1';
         end if;

         
      end if;

      rdRin <= v;

      if (RD_DATA_WIDTH_G < WR_DATA_WIDTH_G) then
         fifo_rd_en <= rdR.rdEn;
         dout       <= rdR.rdData;
         valid      <= rdR.valid;
         empty      <= rdR.empty;
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

   -------------------------------------------------------------------------------------------------
   -- Fifo
   -------------------------------------------------------------------------------------------------
   Fifo_1 : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         BRAM_EN_G       => BRAM_EN_G,
         FWFT_EN_G       => FWFT_EN_G,
         USE_DSP48_G     => USE_DSP48_G,
         ALTERA_SYN_G    => ALTERA_SYN_G,
         ALTERA_RAM_G    => ALTERA_RAM_G,
         USE_BUILT_IN_G  => USE_BUILT_IN_G,
         XIL_DEVICE_G    => XIL_DEVICE_G,
         SYNC_STAGES_G   => SYNC_STAGES_G,
         DATA_WIDTH_G    => FIFO_DATA_WIDTH_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_G,
         INIT_G          => INIT_G,
         FULL_THRES_G    => FULL_THRES_G,
         EMPTY_THRES_G   => EMPTY_THRES_G)
      port map (
         rst           => rst,
         wr_clk        => wr_clk,
         wr_en         => fifo_wr_en,
         din           => fifo_din,
         wr_data_count => open,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => prog_full,
         almost_full   => almost_full,
         full          => full,
         rd_clk        => rd_clk,
         rd_en         => fifo_rd_en,
         dout          => fifo_dout,
         rd_data_count => open,
         valid         => fifo_valid,
         underflow     => underflow,
         prog_empty    => prog_empty,
         almost_empty  => almost_empty,
         empty         => fifo_empty);

end architecture rtl;
