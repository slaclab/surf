-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx XPM FIFO module
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
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library altera_mf;
use altera_mf_altera_mf_components.all;

entity FifoAlteraMf is
   generic (
      TPD_G           : time     := 1 ns;
      RST_POLARITY_G  : sl       := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G     : boolean  := false;
      FWFT_EN_G       : boolean  := false;
      GEN_SYNC_FIFO_G : boolean  := false;
      MEMORY_TYPE_G   : string   := "auto";
      SYNC_STAGES_G   : positive := 3;
      PIPE_STAGES_G   : natural  := 0;
      DATA_WIDTH_G    : positive := 18;
      ADDR_WIDTH_G    : positive := 10;
      FULL_THRES_G    : positive := 16;
      EMPTY_THRES_G   : positive := 16);
   port (
      -- Asynchronous Reset
      rst           : in  sl;
      -- Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl;
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl;
      -- Read Ports (rd_clk domain)
      rd_clk        : in  sl;
      rd_en         : in  sl;
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
end FifoAlteraMf;

architecture mapping of FifoAlteraMf is

   constant FWFT_EN_C : string := ite(FWFT_EN_G, "ON", "OFF");

   signal reset   : sl;
   signal sRdEn   : sl;
   signal sValid  : sl;
   signal dataOut : slv(DATA_WIDTH_G-1 downto 0);

   signal fifoFull  : sl;
   signal fifoEmpty : sl;
   signal wrCount   : slv(ADDR_WIDTH_G-1 downto 0);
   signal rdCount   : slv(ADDR_WIDTH_G-1 downto 0);

begin

   GEN_ASYNC : if (GEN_SYNC_FIFO_G = false) generate
      U_dcfifo : dcfifo
         generic map (
            ram_block_type     => MEMORY_TYPE_G,
            lpm_numwords       => (2**ADDR_WIDTH_G),
            lpm_showahead      => FWFT_EN_C,
            lpm_type           => "dcfifo",
            lpm_width          => DATA_WIDTH_G,
            lpm_widthu         => ADDR_WIDTH_G,
            overflow_checking  => "ON",
            underflow_checking => "ON")
         port map (
            aclr    => reset,
            -- Write Ports
            wrclk   => wr_clk,
            wrreq   => wr_en,
            data    => din,
            wrfull  => fifoFull,
            wrusedw => wrCount,
            -- Read Ports
            rdclk   => rd_clk,
            rdreq   => sRdEn,
            q       => dout,
            rdempty => fifoEmpty,
            rdusedw => rdCount);

   end generate;

   GEN_SYNC : if (GEN_SYNC_FIFO_G = true) generate
      U_scfifo : scfifo
         generic map (
            ram_block_type     => MEMORY_TYPE_G,
            lpm_numwords       => (2**ADDR_WIDTH_G),
            lpm_showahead      => FWFT_EN_C,
            lpm_type           => "scfifo",
            lpm_width          => DATA_WIDTH_G,
            lpm_widthu         => ADDR_WIDTH_G,
            overflow_checking  => "ON",
            underflow_checking => "ON")
         port map (
            sclr  => reset,
            aclr  => '0',
            clock => wr_clk,
            -- Write Ports
            wrreq => wr_en,
            data  => din,
            full  => fifoFull,
            usedw => wrCount,
            -- Read Ports
            rdreq => sRdEn,
            q     => dout,
            empty => fifoEmpty);

      rdCount <= wrCount;

   end generate;

   reset <= rst when(RST_POLARITY_G = '1') else not(rst);

   full     <= fifoFull;
   not_full <= not(fifoFull);
   wr_ack   <= wr_en and not fifoFull;
   overflow <= wr_en and fifoFull;

   wr_data_count <= wrCount;
   rd_data_count <= rdCount;

   process(fifoEmpty, fifoFull, rdCount, wrCount)
   begin
      --------------------------------------------
      if fifoFull = '1' then
         prog_full   <= '1';
         almost_full <= '1';
      else
         if wrCount >= FULL_THRES_G then
            prog_full <= '1';
         else
            prog_full <= '0';
         end if;
         if wrCount >= ((2**ADDR_WIDTH_G)-2) then
            almost_full <= '1';
         else
            almost_full <= '0';
         end if;
      end if;
      --------------------------------------------
      if fifoEmpty = '1' then
         prog_empty   <= '1';
         almost_empty <= '1';
      else
         if rdCount <= EMPTY_THRES_G then
            prog_empty <= '1';
         else
            prog_empty <= '0';
         end if;
         if rdCount <= 1 then
            almost_empty <= '1';
         else
            almost_empty <= '0';
         end if;
      end if;
   --------------------------------------------
   end process;

   empty     <= fifoEmpty;
   underflow <= sRdEn and fifoEmpty;
   sValid    <= not(fifoEmpty);

   BYPASS_PIPE : if ((FWFT_EN_G = false) or (PIPE_STAGES_G = 0)) generate

      sRdEn <= rd_en;
      valid <= sValid;
      dout  <= dataOut;

   end generate;

   GEN_PIPE : if ((FWFT_EN_G = true) and (PIPE_STAGES_G /= 0)) generate

      U_Pipeline : entity surf.FifoOutputPipeline
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            PIPE_STAGES_G  => PIPE_STAGES_G)
         port map (
            -- Slave Port
            sData  => dataOut,
            sValid => sValid,
            sRdEn  => sRdEn,
            -- Master Port
            mData  => dout,
            mValid => valid,
            mRdEn  => rd_en,
            -- Clock and Reset
            clk    => rd_clk,
            rst    => rst);

   end generate;

end mapping;
