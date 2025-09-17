-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamBatchinFifo module
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBatchingFifoTb is 
    port(
        clk           : in  sl;
        rst           : in  sl;
        s_axis_tdata  : in  slv(31 downto 0);
        s_axis_tvalid : in  sl;
        s_axis_tlast  : in  sl;
        s_axis_tready : out sl;
        
        s_axil_ARADDR  : in  std_logic_vector (10 downto 0);
        s_axil_ARREADY : out std_logic;
        s_axil_ARVALID : in  std_logic;
        s_axil_AWADDR  : in  std_logic_vector (10 downto 0);
        s_axil_AWREADY : out std_logic;
        s_axil_AWVALID : in  std_logic;
        s_axil_BREADY  : in  std_logic;
        s_axil_BRESP   : out std_logic_vector (1 downto 0);
        s_axil_BVALID  : out std_logic;
        s_axil_RDATA   : out std_logic_vector (31 downto 0);
        s_axil_RREADY  : in  std_logic;
        s_axil_RRESP   : out std_logic_vector (1 downto 0);
        s_axil_RVALID  : out std_logic;
        s_axil_WDATA   : in  std_logic_vector (31 downto 0);
        s_axil_WREADY  : out std_logic;
        s_axil_WSTRB   : in  std_logic_vector (3 downto 0);
        s_axil_WVALID  : in  std_logic);
end AxiStreamBatchingFifoTb;

architecture testbed of AxiStreamBatchingFifoTb is
    -- Constants
    constant CLK_PERIOD_C : time := 4 ns;
    constant TPD_C        : time := CLK_PERIOD_C/4;

    constant AXIS_RX_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => (4),
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NORMAL_C);
   constant AXIS_TX_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => true,
      TDATA_BYTES_C => (8),
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NORMAL_C);

    -- Signals
    signal toFifoMaster   : AxiStreamMasterType;
    signal toFifoSlave    : AxiStreamSlaveType;
    signal fromFifoMaster : AxiStreamMasterType;
    signal fromFifoSlave  : AxiStreamSlaveType;

    signal sAxilWriteMaster : AxiLiteWriteMasterType;
    signal sAxilWriteSlave  : AxiLiteWriteSlaveType;
    signal sAxilReadMaster  : AxiLiteReadMasterType;
    signal sAxilReadSlave   : AxiLiteReadSlaveType;
begin

    U_BatchingFifo : entity surf.AxiStreamBatchingFifo 
        generic map (
            TPD_G               => TPD_C,
            FIFO_ADDR_WIDTH_G   => 9,
            SLAVE_AXI_CONFIG_G  => AXIS_RX_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_TX_CONFIG_C)
        port map (
            axilClk => clk,
            axilRst => rst,
            sAxilWriteMaster => sAxilWriteMaster,
            sAxilWriteSlave  => sAxilWriteSlave,
            sAxilReadMaster  => sAxilReadMaster,
            sAxilReadSlave   => sAxilReadSlave,

            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => toFifoMaster,
            sAxisSlave  => toFifoSlave,

            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => fromFifoMaster,
            mAxisSlave  => fromFifoSlave);

    -- Map input AXI Stream
    toFifoMaster.tValid <= s_axis_tvalid;
    toFifoMaster.tLast  <= s_axis_tlast;
    toFifoMaster.tData(8*AXIS_RX_CONFIG_C.TDATA_BYTES_C-1 downto 0)  <= s_axis_tdata;
    s_axis_tready       <= toFifoSlave.tReady;

    -- Continuous read of output AXI Stream
    fromFifoSlave.tReady <= '1';

    -- Map AXI LITE
    sAxilWriteMaster.awaddr(10 downto 0) <= s_axil_AWADDR;
    sAxilWriteMaster.awvalid             <= s_axil_AWVALID;
    sAxilWriteMaster.wdata               <= s_axil_WDATA;
    sAxilWriteMaster.wstrb               <= s_axil_WSTRB;
    sAxilWriteMaster.wvalid              <= s_axil_WVALID;
    sAxilWriteMaster.bready              <= s_axil_BREADY;
    sAxilReadMaster.araddr(10 downto 0)  <= s_axil_ARADDR;
    sAxilReadMaster.arvalid              <= s_axil_ARVALID;
    sAxilReadMaster.rready               <= s_axil_RREADY;
    s_axil_ARREADY                       <= sAxilReadSlave.arready;
    s_axil_RDATA                         <= sAxilReadSlave.rdata;
    s_axil_RRESP                         <= sAxilReadSlave.rresp;
    s_axil_RVALID                        <= sAxilReadSlave.rvalid;
    s_axil_AWREADY                       <= sAxilWriteSlave.awready;
    s_axil_WREADY                        <= sAxilWriteSlave.wready;
    s_axil_BRESP                         <= sAxilWriteSlave.bresp;
    s_axil_BVALID                        <= sAxilWriteSlave.bvalid;
end testbed;