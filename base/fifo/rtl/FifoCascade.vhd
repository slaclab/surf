-------------------------------------------------------------------------------
-- File       : FifoCascade.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-10
-- Last update: 2014-09-23
-------------------------------------------------------------------------------
-- Description: Wrapper for cascading FWFT FIFOs together
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

entity FifoCascade is
   generic (
      TPD_G              : time                       := 1 ns;
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;  -- Number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      LAST_STAGE_ASYNC_G : boolean                    := true;  -- If set to true, the last stage will be the ASYNC FIFO
      RST_POLARITY_G     : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G        : boolean                    := false;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      BRAM_EN_G          : boolean                    := true;
      FWFT_EN_G          : boolean                    := false;
      USE_DSP48_G        : string                     := "no";
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      USE_BUILT_IN_G     : boolean                    := false;  -- If set to true, this module is only Xilinx compatible only!!!
      XIL_DEVICE_G       : string                     := "7SERIES";  -- Xilinx only generic parameter    
      SYNC_STAGES_G      : integer range 3 to (2**24) := 3;
      PIPE_STAGES_G      : natural range 0 to 16      := 0;
      DATA_WIDTH_G       : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G       : integer range 4 to 48      := 4;
      INIT_G             : slv                        := "0";
      FULL_THRES_G       : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G      : integer range 1 to (2**24) := 1);
   port (
      -- Resets
      rst           : in  sl := '0';
      --Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl := '0';
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl;
      progFullVec   : out slv(CASCADE_SIZE_G-1 downto 0); -- Output stage = 0
      --Read Ports (rd_clk domain)
      rd_clk        : in  sl;           --unused if GEN_SYNC_FIFO_G = true
      rd_en         : in  sl := '0';
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
end FifoCascade;

architecture mapping of FifoCascade is

   constant GEN_SYNC_FIFO_FIRST_C : boolean := ite(LAST_STAGE_ASYNC_G, true, GEN_SYNC_FIFO_G);
   constant GEN_SYNC_FIFO_LAST_C  : boolean := ite(LAST_STAGE_ASYNC_G, GEN_SYNC_FIFO_G, true);
   constant CASCADE_SIZE_C        : integer := ite((CASCADE_SIZE_G = 1), 0, (CASCADE_SIZE_G-2));

   type FifoDataType is array (CASCADE_SIZE_C downto 0) of slv((DATA_WIDTH_G-1) downto 0);

   signal progFull,
      cascadeClk : sl;
   signal readJump,
      validJump,
      AFullJump : slv(CASCADE_SIZE_C downto 0);
   signal dataJump : FifoDataType;

begin

   cascadeClk <= wr_clk when(LAST_STAGE_ASYNC_G = true) else rd_clk;

   -----------------------------------------------------------------
   -----------------------------------------------------------------
   -----------------------------------------------------------------

   ONE_STAGE : if (CASCADE_SIZE_G = 1) generate
      
      prog_full      <= progFull;
      progFullVec(0) <= progFull;

      Fifo_1xStage : entity work.Fifo
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
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => DATA_WIDTH_G,
            ADDR_WIDTH_G    => ADDR_WIDTH_G,
            INIT_G          => INIT_G,
            FULL_THRES_G    => FULL_THRES_G,
            EMPTY_THRES_G   => EMPTY_THRES_G)
         port map (
            -- Resets
            rst           => rst,
            --Write Ports (wr_clk domain)
            wr_clk        => wr_clk,
            wr_en         => wr_en,
            din           => din,
            wr_data_count => wr_data_count,
            wr_ack        => wr_ack,
            overflow      => overflow,
            prog_full     => progFull,
            almost_full   => almost_full,
            full          => full,
            not_full      => not_full,
            --Read Ports (rd_clk domain)
            rd_clk        => rd_clk,
            rd_en         => rd_en,
            dout          => dout,
            rd_data_count => rd_data_count,
            valid         => valid,
            underflow     => underflow,
            prog_empty    => prog_empty,
            almost_empty  => almost_empty,
            empty         => empty);   

   end generate;

   -----------------------------------------------------------------
   -----------------------------------------------------------------
   -----------------------------------------------------------------   

   TWO_STAGE : if (CASCADE_SIZE_G >= 2) generate
      
      prog_full                     <= progFull;
      progFullVec(CASCADE_SIZE_G-1) <= progFull;

      Fifo_First_Stage : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_FIRST_C,
            BRAM_EN_G       => BRAM_EN_G,
            FWFT_EN_G       => true,
            USE_DSP48_G     => USE_DSP48_G,
            ALTERA_SYN_G    => ALTERA_SYN_G,
            ALTERA_RAM_G    => ALTERA_RAM_G,
            USE_BUILT_IN_G  => USE_BUILT_IN_G,
            XIL_DEVICE_G    => XIL_DEVICE_G,
            SYNC_STAGES_G   => SYNC_STAGES_G,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => DATA_WIDTH_G,
            ADDR_WIDTH_G    => ADDR_WIDTH_G,
            INIT_G          => INIT_G,
            FULL_THRES_G    => FULL_THRES_G,
            EMPTY_THRES_G   => EMPTY_THRES_G)
         port map (
            -- Resets
            rst           => rst,
            --Write Ports (wr_clk domain)
            wr_clk        => wr_clk,
            wr_en         => wr_en,
            din           => din,
            wr_data_count => wr_data_count,
            wr_ack        => wr_ack,
            overflow      => overflow,
            prog_full     => progFull,
            almost_full   => almost_full,
            full          => full,
            not_full      => not_full,
            --Read Ports (rd_clk domain)
            rd_clk        => cascadeClk,
            rd_en         => readJump(CASCADE_SIZE_G-2),
            dout          => dataJump(CASCADE_SIZE_G-2),
            valid         => validJump(CASCADE_SIZE_G-2));
      readJump(CASCADE_SIZE_G-2) <= validJump(CASCADE_SIZE_G-2) and not AFullJump(CASCADE_SIZE_G-2);

      MULTI_STAGE : if (CASCADE_SIZE_G > 2) generate

         GEN_MULTI_STAGE :
         for i in (CASCADE_SIZE_G-2) downto 1 generate
            
            Fifo_Middle_Stage : entity work.Fifo
               generic map (
                  TPD_G           => TPD_G,
                  RST_POLARITY_G  => RST_POLARITY_G,
                  RST_ASYNC_G     => RST_ASYNC_G,
                  GEN_SYNC_FIFO_G => true,
                  BRAM_EN_G       => BRAM_EN_G,
                  FWFT_EN_G       => true,
                  USE_DSP48_G     => USE_DSP48_G,
                  ALTERA_SYN_G    => ALTERA_SYN_G,
                  ALTERA_RAM_G    => ALTERA_RAM_G,
                  USE_BUILT_IN_G  => USE_BUILT_IN_G,
                  XIL_DEVICE_G    => XIL_DEVICE_G,
                  SYNC_STAGES_G   => SYNC_STAGES_G,
                  PIPE_STAGES_G   => PIPE_STAGES_G,
                  DATA_WIDTH_G    => DATA_WIDTH_G,
                  ADDR_WIDTH_G    => ADDR_WIDTH_G,
                  INIT_G          => INIT_G,
                  FULL_THRES_G    => FULL_THRES_G,
                  EMPTY_THRES_G   => EMPTY_THRES_G)
               port map (
                  -- Resets
                  rst         => rst,
                  --Write Ports (wr_clk domain)
                  wr_clk      => cascadeClk,
                  wr_en       => readJump(i),
                  din         => dataJump(i),
                  almost_full => AFullJump(i),
                  prog_full   => progFullVec(i),
                  --Read Ports (rd_clk domain)
                  rd_clk      => cascadeClk,
                  rd_en       => readJump(i-1),
                  dout        => dataJump(i-1),
                  valid       => validJump(i-1)); 
            readJump(i-1) <= validJump(i-1) and not AFullJump(i-1);
            
         end generate GEN_MULTI_STAGE;
      end generate;

      Fifo_Last_Stage : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_POLARITY_G  => RST_POLARITY_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_LAST_C,
            BRAM_EN_G       => BRAM_EN_G,
            FWFT_EN_G       => FWFT_EN_G,
            USE_DSP48_G     => USE_DSP48_G,
            ALTERA_SYN_G    => ALTERA_SYN_G,
            ALTERA_RAM_G    => ALTERA_RAM_G,
            USE_BUILT_IN_G  => USE_BUILT_IN_G,
            XIL_DEVICE_G    => XIL_DEVICE_G,
            SYNC_STAGES_G   => SYNC_STAGES_G,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => DATA_WIDTH_G,
            ADDR_WIDTH_G    => ADDR_WIDTH_G,
            INIT_G          => INIT_G,
            FULL_THRES_G    => FULL_THRES_G,
            EMPTY_THRES_G   => EMPTY_THRES_G)
         port map (
            -- Resets
            rst           => rst,
            --Write Ports (wr_clk domain)
            wr_clk        => cascadeClk,
            wr_en         => readJump(0),
            din           => dataJump(0),
            almost_full   => AFullJump(0),
            prog_full     => progFullVec(0),
            --Read Ports (rd_clk domain)
            rd_clk        => rd_clk,
            rd_en         => rd_en,
            dout          => dout,
            rd_data_count => rd_data_count,
            valid         => valid,
            underflow     => underflow,
            prog_empty    => prog_empty,
            almost_empty  => almost_empty,
            empty         => empty);                

   end generate;
   
end architecture mapping;
