-------------------------------------------------------------------------------
-- File       : MicroblazeBasicCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-16
-- Last update: 2016-07-14
-------------------------------------------------------------------------------
-- Description: Wrapper for Microblaze Basic Core for "90% case"
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;

entity MicroblazeBasicCoreWrapper is
   generic (
      TPD_G           : time    := 1 ns;
      AXIL_RESP_C     : boolean := false;
      AXIL_ADDR_MSB_C : boolean := false);  -- false = [0x00000000:0x7FFFFFFF], true = [0x80000000:0xFFFFFFFF]
   port (
      -- Master AXI-Lite Interface
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      -- Master AXIS Interface
      sAxisMaster      : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave       : out AxiStreamSlaveType;
      -- Slave AXIS Interface
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      -- Interrupt Interface
      interrupt        : in  slv(7 downto 0)     := (others => '0');
      -- Clock and Reset
      clk              : in  sl;
      pllLock          : in  sl                  := '1';
      rst              : in  sl);
end MicroblazeBasicCoreWrapper;

architecture mapping of MicroblazeBasicCoreWrapper is

   component MicroblazeBasicCore is
      port (
         INTERRUPT        : in  std_logic_vector (7 downto 0);
         M0_AXIS_tdata    : out std_logic_vector (31 downto 0);
         M0_AXIS_tlast    : out std_logic;
         M0_AXIS_tready   : in  std_logic;
         M0_AXIS_tvalid   : out std_logic;
         M_AXI_DP_araddr  : out std_logic_vector (31 downto 0);
         M_AXI_DP_arprot  : out std_logic_vector (2 downto 0);
         M_AXI_DP_arready : in  std_logic_vector (0 to 0);
         M_AXI_DP_arvalid : out std_logic_vector (0 to 0);
         M_AXI_DP_awaddr  : out std_logic_vector (31 downto 0);
         M_AXI_DP_awprot  : out std_logic_vector (2 downto 0);
         M_AXI_DP_awready : in  std_logic_vector (0 to 0);
         M_AXI_DP_awvalid : out std_logic_vector (0 to 0);
         M_AXI_DP_bready  : out std_logic_vector (0 to 0);
         M_AXI_DP_bresp   : in  std_logic_vector (1 downto 0);
         M_AXI_DP_bvalid  : in  std_logic_vector (0 to 0);
         M_AXI_DP_rdata   : in  std_logic_vector (31 downto 0);
         M_AXI_DP_rready  : out std_logic_vector (0 to 0);
         M_AXI_DP_rresp   : in  std_logic_vector (1 downto 0);
         M_AXI_DP_rvalid  : in  std_logic_vector (0 to 0);
         M_AXI_DP_wdata   : out std_logic_vector (31 downto 0);
         M_AXI_DP_wready  : in  std_logic_vector (0 to 0);
         M_AXI_DP_wstrb   : out std_logic_vector (3 downto 0);
         M_AXI_DP_wvalid  : out std_logic_vector (0 to 0);
         S0_AXIS_tdata    : in  std_logic_vector (31 downto 0);
         S0_AXIS_tlast    : in  std_logic;
         S0_AXIS_tready   : out std_logic;
         S0_AXIS_tvalid   : in  std_logic;
         clk              : in  std_logic;
         dcm_locked       : in  std_logic;
         reset            : in  std_logic);
   end component MicroblazeBasicCore;

   signal awaddr : slv(31 downto 0);
   signal araddr : slv(31 downto 0);
   signal bresp  : slv(1 downto 0);
   signal rresp  : slv(1 downto 0);

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType;

begin

   -- Address space = [0x00000000:0x7FFFFFFF]
   LOWER_2GB : if (AXIL_ADDR_MSB_C = false) generate
      mAxilWriteMaster.awaddr <= '0' & awaddr(30 downto 0);
      mAxilReadMaster.araddr  <= '0' & araddr(30 downto 0);
   end generate;

   -- Address space = [0x80000000:0xFFFFFFFF]
   HIGH_2GB : if (AXIL_ADDR_MSB_C = true) generate
      mAxilWriteMaster.awaddr <= '1' & awaddr(30 downto 0);
      mAxilReadMaster.araddr  <= '1' & araddr(30 downto 0);
   end generate;

   BYPASS_RESP : if (AXIL_RESP_C = false) generate
      bresp <= AXI_RESP_OK_C;
      rresp <= AXI_RESP_OK_C;
   end generate;

   USE_RESP : if (AXIL_RESP_C = true) generate
      bresp <= mAxilWriteSlave.bresp;
      rresp <= mAxilReadSlave.rresp;
   end generate;

   U_Microblaze : component MicroblazeBasicCore
      port map (
         -- Interrupt Interface
         INTERRUPT           => interrupt,
         -- Master AXI-Lite Interface
         M_AXI_DP_awaddr     => awaddr,
         M_AXI_DP_awprot     => mAxilWriteMaster.awprot,
         M_AXI_DP_awvalid(0) => mAxilWriteMaster.awvalid,
         M_AXI_DP_wdata      => mAxilWriteMaster.wdata,
         M_AXI_DP_wstrb      => mAxilWriteMaster.wstrb,
         M_AXI_DP_wvalid(0)  => mAxilWriteMaster.wvalid,
         M_AXI_DP_bready(0)  => mAxilWriteMaster.bready,
         M_AXI_DP_awready(0) => mAxilWriteSlave.awready,
         M_AXI_DP_wready(0)  => mAxilWriteSlave.wready,
         M_AXI_DP_bresp      => bresp,
         M_AXI_DP_bvalid(0)  => mAxilWriteSlave.bvalid,
         M_AXI_DP_araddr     => araddr,
         M_AXI_DP_arprot     => mAxilReadMaster.arprot,
         M_AXI_DP_arvalid(0) => mAxilReadMaster.arvalid,
         M_AXI_DP_rready(0)  => mAxilReadMaster.rready,
         M_AXI_DP_arready(0) => mAxilReadSlave.arready,
         M_AXI_DP_rdata      => mAxilReadSlave.rdata,
         M_AXI_DP_rresp      => rresp,
         M_AXI_DP_rvalid(0)  => mAxilReadSlave.rvalid,
         -- Master AXIS Interface
         M0_AXIS_tdata       => txMaster.tdata(31 downto 0),
         M0_AXIS_tlast       => txMaster.tlast,
         M0_AXIS_tvalid      => txMaster.tvalid,
         M0_AXIS_tready      => txSlave.tready,
         -- Slave AXIS Interface
         S0_AXIS_tdata       => sAxisMaster.tdata(31 downto 0),
         S0_AXIS_tlast       => sAxisMaster.tlast,
         S0_AXIS_tvalid      => sAxisMaster.tvalid,
         S0_AXIS_tready      => sAxisSlave.tready,
         -- Clock and Reset
         clk                 => clk,
         dcm_locked          => pllLock,
         reset               => rst);

   U_InsertSOF : entity work.SsiInsertSof
      generic map (
         TPD_G               => TPD_G,
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(4))
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);         

end mapping;
