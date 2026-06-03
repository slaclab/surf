-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the EthMac module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity TokenBucket is
   generic (
      TPD_G         : time    := 1 ns;
      CLK_FREQ_G    : real    := 156.25E+6;
      FRAC_BITS_G   : natural := 16;
      AXIS_CONFIG_G : AxiStreamConfigType
   );
   port (
      axisClk     : in  sl;
      axisRst     : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      Rc          : in  slv(31 downto 0);
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
      );
end entity TokenBucket;

architecture rtl of TokenBucket is

   constant CLK_PERIOD_C : real := 1.0/CLK_FREQ_G;  -- seconds

   signal s_sAxisSlave   : AxiStreamSlaveType;
   signal frameUpdate    : sl;
   signal frameCnt       : slv(63 downto 0);
   signal frameSize      : slv(31 downto 0);
   signal frameSizeSync  : slv(31 downto 0);
   signal frameRate      : slv(31 downto 0);
   signal bandwidth      : slv(63 downto 0);
   signal rd_en          : sl;
   signal axisMasterFifo : AxiStreamMasterType;
   signal axisSlaveFifo  : AxiStreamSlaveType;
   signal byte_per_clk   : slv(31 downto 0);  -- Should be parametrized

begin  -- architecture rtl

   sAxisSlave <= s_sAxisSlave;

   AxiStreamMon_1 : entity surf.AxiStreamMonDcqcn
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => true,
         AXIS_CLK_FREQ_G => CLK_FREQ_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         axisMaster  => saxisMaster,
         axisSlave   => s_sAxisSlave,
         statusClk   => axisClk,
         statusRst   => axisRst,
         frameUpdate => frameUpdate,
         frameCnt    => frameCnt,
         frameSize   => frameSize,
         frameRate   => frameRate,
         bandwidth   => bandwidth
         );

   -----------------------------------------------------------------------------
   -- Data FIFO
   -----------------------------------------------------------------------------
   AxiStreamFifoV2_1 : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 8,
         VALID_THOLD_G       => 0,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 12,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 1,
         INT_DATA_WIDTH_G    => 16,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         sAxisClk    => axisClk,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => s_sAxisSlave,
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => axisMasterFifo,
         mAxisSlave  => axisSlaveFifo
         );

   -----------------------------------------------------------------------------
   -- Data Size FIFO
   -----------------------------------------------------------------------------
   FifoSync_1 : entity surf.FifoSync
      generic map (
         TPD_G         => TPD_G,
         FWFT_EN_G     => true,
         PIPE_STAGES_G => 0,
         DATA_WIDTH_G  => 32,
         ADDR_WIDTH_G  => 6)
      port map (
         rst          => axisRst,
         clk          => axisClk,
         wr_en        => frameUpdate,
         rd_en        => rd_en,
         din          => frameSize,
         dout         => frameSizeSync,
         data_count   => open,
         wr_ack       => open,
         valid        => open,
         overflow     => open,
         underflow    => open,
         prog_full    => open,
         prog_empty   => open,
         almost_full  => open,
         almost_empty => open,
         full         => open,
         not_full     => open,
         empty        => open
         );

   -----------------------------------------------------------------------------
   -- Token Bucket
   -----------------------------------------------------------------------------
   AxisBucket_1 : entity surf.AxisBucket
      generic map (
         TPD_G         => TPD_G,
         FRAC_BITS_G   => FRAC_BITS_G,  -- frac bits for byte per clk
         BUCKET_SIZE_G => x"00100000",  -- in byte
         AXIS_CONFIG_G => AXIS_CONFIG_G)
      port map (
         axisClk      => axisClk,
         axisRst      => axisRst,
         byte_per_clk => byte_per_clk,  -- Q16.16
         packet_size  => frameSizeSync,
         rd_en        => rd_en,
         sAxisMaster  => axisMasterFifo,
         sAxisSlave   => axisSlaveFifo,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

   -----------------------------------------------------------------------------
   -- Token Calculator
   -----------------------------------------------------------------------------
   tokenCalc_1 : entity surf.tokenCalc
      generic map (
         TPD_G       => TPD_G,
         CLK_FREQ_G  => CLK_FREQ_G,
         FRAC_BITS_G => FRAC_BITS_G)
      port map (
         clk          => axisClk,
         rst          => axisRst,
         Rc           => Rc,
         byte_per_clk => byte_per_clk);

end architecture rtl;
