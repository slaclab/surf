------------------------------------------------------------------------------- 
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: ASYNC FIFO module
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;

entity FifoAsync is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      MEMORY_TYPE_G  : string   := "block";
      BYP_RAM_G      : boolean  := false;
      FWFT_EN_G      : boolean  := false;
      SYNC_STAGES_G  : positive := 3;
      PIPE_STAGES_G  : natural  := 0;
      DATA_WIDTH_G   : positive := 16;
      ADDR_WIDTH_G   : positive := 4;
      INIT_G         : slv      := "0";
      FULL_THRES_G   : positive := 1;
      EMPTY_THRES_G  : positive := 1);
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
end FifoAsync;

architecture mapping of FifoAsync is

   constant SYNC_INIT_C : slv(SYNC_STAGES_G-1 downto 0) := (others => '0');
   constant GRAY_INIT_C : slv(ADDR_WIDTH_G-1 downto 0)  := (others => '0');

   signal wrRst : sl := '0';
   signal rdRst : sl := '0';

   signal rdRdy   : sl                           := '0';
   signal rdIndex : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal wrRdy   : sl                           := '0';
   signal wrIndex : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');

   signal rdRdySync   : sl                           := '0';
   signal rdIndexSync : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal wrRdySync   : sl                           := '0';
   signal wrIndexSync : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');

   signal wea   : sl                           := '0';
   signal addra : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal dina  : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');

   signal addrb  : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal doutb  : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
   signal enb    : sl                           := '0';
   signal regceb : sl                           := '0';

   signal localDout  : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
   signal localValid : sl                           := '0';
   signal localRdEn  : sl                           := '0';

begin

   -----------------------------------------
   --       wr_clk clock domain
   -----------------------------------------   

   U_wrRst : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => RST_POLARITY_G,
         RELEASE_DELAY_G => SYNC_STAGES_G)
      port map (
         clk      => wr_clk,
         asyncRst => rst,
         syncRst  => wrRst);

   U_rdIndex : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         clk     => wr_clk,
         rst     => wrRst,
         dataIn  => rdIndex,
         dataOut => rdIndexSync);

   U_rdRdy : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         INIT_G   => SYNC_INIT_C)
      port map (
         clk     => wr_clk,
         rst     => wrRst,
         dataIn  => rdRdy,
         dataOut => rdRdySync);

   U_WR_FSM : entity surf.FifoWrFsm
      generic map(
         TPD_G        => TPD_G,
         FIFO_ASYNC_G => true,          -- ASYNC FIFO
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G,
         FULL_THRES_G => FULL_THRES_G)
      port map(
         -- Reset
         rst           => wrRst,
         -- RD/WR FSM Interface
         rdRdy         => rdRdySync,
         rdIndex       => rdIndexSync,
         wrRdy         => wrRdy,
         wrIndex       => wrIndex,
         -- RAM Interface
         wea           => wea,
         addra         => addra,
         dina          => dina,
         -- FIFO Write Interface
         wr_clk        => wr_clk,
         wr_en         => wr_en,
         din           => din,
         wr_data_count => wr_data_count,
         wr_ack        => wr_ack,
         overflow      => overflow,
         prog_full     => prog_full,
         almost_full   => almost_full,
         full          => full,
         not_full      => not_full);

   -----------------------------------------
   --       rd_clk clock domain
   -----------------------------------------   

   U_rdRst : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => RST_POLARITY_G,
         RELEASE_DELAY_G => SYNC_STAGES_G)
      port map (
         clk      => rd_clk,
         asyncRst => rst,
         syncRst  => rdRst);

   U_wrIndex : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         clk     => rd_clk,
         rst     => rdRst,
         dataIn  => wrIndex,
         dataOut => wrIndexSync);

   U_wrRdy : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         INIT_G   => SYNC_INIT_C)
      port map (
         clk     => rd_clk,
         rst     => rdRst,
         dataIn  => wrRdy,
         dataOut => wrRdySync);

   U_RD_FSM : entity surf.FifoRdFsm
      generic map(
         TPD_G         => TPD_G,
         FIFO_ASYNC_G  => true,         -- ASYNC FIFO
         MEMORY_TYPE_G => MEMORY_TYPE_G,
         FWFT_EN_G     => FWFT_EN_G,
         DATA_WIDTH_G  => DATA_WIDTH_G,
         ADDR_WIDTH_G  => ADDR_WIDTH_G,
         EMPTY_THRES_G => EMPTY_THRES_G)
      port map(
         -- Reset
         rst           => rdRst,
         -- RD/WR FSM Interface
         rdRdy         => rdRdy,
         rdIndex       => rdIndex,
         wrRdy         => wrRdySync,
         wrIndex       => wrIndexSync,
         -- RAM Interface
         addrb         => addrb,
         doutb         => doutb,
         enb           => enb,
         regceb        => regceb,
         -- FIFO Read Interface
         rd_clk        => rd_clk,
         rd_en         => localRdEn,
         dout          => localDout,
         rd_data_count => rd_data_count,
         valid         => localValid,
         underflow     => underflow,
         prog_empty    => prog_empty,
         almost_empty  => almost_empty,
         empty         => empty);

   -----------------------------------------
   --             RAM Module
   ----------------------------------------- 
   GEN_RAM : if (BYP_RAM_G = false) generate
      U_RAM : entity surf.SimpleDualPortRam
         generic map(
            TPD_G         => TPD_G,
            DOB_REG_G     => ite(MEMORY_TYPE_G/="distributed", FWFT_EN_G, false),
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            DATA_WIDTH_G  => DATA_WIDTH_G,
            ADDR_WIDTH_G  => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka   => wr_clk,
            wea    => wea,
            addra  => addra,
            dina   => dina,
            -- Port B
            clkb   => rd_clk,
            addrb  => addrb,
            doutb  => doutb,
            enb    => enb,
            regceb => regceb);
   end generate;

   GEN_PIPE : if (FWFT_EN_G = true) generate

      U_Pipeline : entity surf.FifoOutputPipeline
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => DATA_WIDTH_G,
            PIPE_STAGES_G => PIPE_STAGES_G)
         port map (
            -- Slave Port
            sData  => localDout,
            sValid => localValid,
            sRdEn  => localRdEn,
            -- Master Port
            mData  => dout,
            mValid => valid,
            mRdEn  => rd_en,
            -- Clock and Reset
            clk    => rd_clk,
            rst    => rdRst);

   end generate;

   BYP_PIPE : if (FWFT_EN_G = false) generate
      dout      <= localDout;
      valid     <= localValid;
      localRdEn <= rd_en;
   end generate;

end mapping;
