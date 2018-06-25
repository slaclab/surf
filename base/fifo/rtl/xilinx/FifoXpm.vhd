-------------------------------------------------------------------------------
-- File       : FifoXpm.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-06-25
-- Last update: 2018-06-25
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

use work.StdRtlPkg.all;

library xpm;
use xpm.vcomponents.all;

entity FifoXpm is
   generic (
      TPD_G           : time     := 1 ns;
      RST_POLARITY_G  : sl       := '1';  -- '1' for active high rst, '0' for active low
      FWFT_EN_G       : boolean  := false;
      GEN_SYNC_FIFO_G : boolean  := false;
      MEMORY_TYPE_G   : string   := "block";
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
end FifoXpm;

architecture mapping of FifoXpm is

   constant WAKEUP_TIME_C : integer  := 0;  -- 0: Disable sleep, 2: Use Sleep Pin
   constant READ_MODE_C   : string   := ite(FWFT_EN_G, "fwft", "std");
   constant DOUT_INIT_C   : string   := "0";
   constant MIN_THRES_C   : positive := 8;
   constant MAX_THRES_C   : positive := 2**ADDR_WIDTH_G - 8;

   constant FULL_THRES_C : positive :=
      ite((FULL_THRES_G < MIN_THRES_C), MIN_THRES_C,
          ite((FULL_THRES_G > MAX_THRES_C), MAX_THRES_C, FULL_THRES_G));

   constant EMPTY_THRES_C : positive :=
      ite((EMPTY_THRES_G < MIN_THRES_C), MIN_THRES_C,
          ite((EMPTY_THRES_G > MAX_THRES_C), MAX_THRES_C, EMPTY_THRES_G));

   -------------------------
   -- USE_ADV_FEATURES_C
   -------------------------
   -- BIT0:  Enable overflow
   -- BIT1:  Enable prog_full
   -- BIT2:  Enable wr_data_count
   -- BIT3:  Enable almost_full
   -- BIT4:  Enable wr_ack
   -- BIT5:  Undefined
   -- BIT6:  Undefined
   -- BIT7:  Undefined
   -- BIT8:  Enable underflow
   -- BIT9:  Enable prog_empty
   -- BIT10: Enable rd_data_count
   -- BIT11: Enable almost_empty
   -- BIT12: Enable data_valid
   constant USE_ADV_FEATURES_C : string := "1F1F";

   signal reset    : sl;
   signal fifoFull : sl;
   signal sRdEn    : sl;
   signal sValid   : sl;
   signal dataOut  : slv(DATA_WIDTH_G-1 downto 0);

begin

   GEN_ASYNC : if (GEN_SYNC_FIFO_G = false) generate
      U_FIFO : xpm_fifo_async
         generic map (
            FIFO_MEMORY_TYPE    => MEMORY_TYPE_G,
            ECC_MODE            => "no_ecc",
            RELATED_CLOCKS      => 0,
            FIFO_WRITE_DEPTH    => (2**ADDR_WIDTH_G),
            WRITE_DATA_WIDTH    => DATA_WIDTH_G,
            WR_DATA_COUNT_WIDTH => ADDR_WIDTH_G,
            PROG_FULL_THRESH    => FULL_THRES_C,
            FULL_RESET_VALUE    => 1,   -- Assert back pressure during reset
            USE_ADV_FEATURES    => USE_ADV_FEATURES_C,
            read_mode           => READ_MODE_C,
            FIFO_READ_LATENCY   => ite(FWFT_EN_G, 0, 1),
            READ_DATA_WIDTH     => DATA_WIDTH_G,
            RD_DATA_COUNT_WIDTH => ADDR_WIDTH_G,
            PROG_EMPTY_THRESH   => EMPTY_THRES_C,
            DOUT_RESET_VALUE    => DOUT_INIT_C,
            CDC_SYNC_STAGES     => SYNC_STAGES_G,
            WAKEUP_TIME         => WAKEUP_TIME_C)
         port map (
            sleep         => '0',
            rst           => reset,
            wr_clk        => wr_clk,
            wr_en         => wr_en,
            din           => din,
            full          => fifoFull,
            overflow      => overflow,
            wr_rst_busy   => open,
            prog_full     => prog_full,
            wr_data_count => wr_data_count,
            almost_full   => almost_full,
            wr_ack        => wr_ack,
            rd_clk        => rd_clk,
            rd_en         => rd_en,
            dout          => dataOut,
            empty         => empty,
            underflow     => underflow,
            rd_rst_busy   => open,
            prog_empty    => prog_empty,
            rd_data_count => rd_data_count,
            almost_empty  => almost_empty,
            data_valid    => sValid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open);
   end generate;

   GEN_SYNC : if (GEN_SYNC_FIFO_G = true) generate
      U_FIFO : xpm_fifo_sync
         generic map (
            FIFO_MEMORY_TYPE    => MEMORY_TYPE_G,
            ECC_MODE            => "no_ecc",
            FIFO_WRITE_DEPTH    => (2**ADDR_WIDTH_G),
            WRITE_DATA_WIDTH    => DATA_WIDTH_G,
            WR_DATA_COUNT_WIDTH => ADDR_WIDTH_G,
            PROG_FULL_THRESH    => FULL_THRES_C,
            FULL_RESET_VALUE    => 1,   -- Assert back pressure during reset
            USE_ADV_FEATURES    => USE_ADV_FEATURES_C,
            read_mode           => READ_MODE_C,
            FIFO_READ_LATENCY   => ite(FWFT_EN_G, 0, 1),
            READ_DATA_WIDTH     => DATA_WIDTH_G,
            RD_DATA_COUNT_WIDTH => ADDR_WIDTH_G,
            PROG_EMPTY_THRESH   => EMPTY_THRES_C,
            DOUT_RESET_VALUE    => DOUT_INIT_C,
            WAKEUP_TIME         => WAKEUP_TIME_C)
         port map (
            rst           => reset,
            wr_clk        => wr_clk,
            wr_en         => wr_en,
            din           => din,
            full          => fifoFull,
            overflow      => overflow,
            wr_rst_busy   => open,
            prog_full     => prog_full,
            wr_data_count => wr_data_count,
            almost_full   => almost_full,
            wr_ack        => wr_ack,
            rd_en         => sRdEn,
            dout          => dataOut,
            empty         => empty,
            underflow     => underflow,
            rd_rst_busy   => open,
            prog_empty    => prog_empty,
            rd_data_count => rd_data_count,
            almost_empty  => almost_empty,
            data_valid    => sValid,
            sleep         => '0',
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open);

   end generate;

   reset <= rst when(RST_POLARITY_G = '1') else not(rst);

   full     <= fifoFull;
   not_full <= not(fifoFull);

   BYPASS_PIPE : if ((FWFT_EN_G = false) or (PIPE_STAGES_G = 0)) generate

      sRdEn <= rd_en;
      valid <= sValid;
      dout  <= dataOut;

   end generate;

   GEN_PIPE : if ((FWFT_EN_G = true) and (PIPE_STAGES_G /= 0)) generate

      U_Pipeline : entity work.FifoOutputPipeline
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => false,
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
