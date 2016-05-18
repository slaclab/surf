-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : MicroblazeBasicCoreWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-16
-- Last update: 2016-05-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

entity MicroblazeBasicCoreWrapper is
   generic (
      TPD_G           : time    := 1 ns;
      FWD_MEM_ERR_C   : boolean := false;
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
      irqAck           : out slv (0 to 1);
      irqAddr          : in  slv (0 to 31)       := (others => '0');
      irqReq           : in  sl                  := '0';
      -- Clock and Reset
      clk              : in  sl;
      locked           : in  sl                  := '1';
      rst              : in  sl);
end MicroblazeBasicCoreWrapper;

architecture mapping of MicroblazeBasicCoreWrapper is

   component MicroblazeBasicCore is
      port (
         M_AXI_DP_araddr     : out std_logic_vector (31 downto 0);
         M_AXI_DP_arprot     : out std_logic_vector (2 downto 0);
         M_AXI_DP_arready    : in  std_logic;
         M_AXI_DP_arvalid    : out std_logic;
         M_AXI_DP_awaddr     : out std_logic_vector (31 downto 0);
         M_AXI_DP_awprot     : out std_logic_vector (2 downto 0);
         M_AXI_DP_awready    : in  std_logic;
         M_AXI_DP_awvalid    : out std_logic;
         M_AXI_DP_bready     : out std_logic;
         M_AXI_DP_bresp      : in  std_logic_vector (1 downto 0);
         M_AXI_DP_bvalid     : in  std_logic;
         M_AXI_DP_rdata      : in  std_logic_vector (31 downto 0);
         M_AXI_DP_rready     : out std_logic;
         M_AXI_DP_rresp      : in  std_logic_vector (1 downto 0);
         M_AXI_DP_rvalid     : in  std_logic;
         M_AXI_DP_wdata      : out std_logic_vector (31 downto 0);
         M_AXI_DP_wready     : in  std_logic;
         M_AXI_DP_wstrb      : out std_logic_vector (3 downto 0);
         M_AXI_DP_wvalid     : out std_logic;
         INTERRUPT_ack       : out std_logic_vector (0 to 1);
         INTERRUPT_address   : in  std_logic_vector (0 to 31);
         INTERRUPT_interrupt : in  std_logic;
         M0_AXIS_tdata       : out std_logic_vector (31 downto 0);
         M0_AXIS_tlast       : out std_logic;
         M0_AXIS_tready      : in  std_logic;
         M0_AXIS_tvalid      : out std_logic;
         S0_AXIS_tdata       : in  std_logic_vector (31 downto 0);
         S0_AXIS_tlast       : in  std_logic;
         S0_AXIS_tready      : out std_logic;
         S0_AXIS_tvalid      : in  std_logic;
         clk                 : in  std_logic;
         reset               : in  std_logic;
         dcm_locked          : in  std_logic);
   end component MicroblazeBasicCore;

   signal awaddr : slv(31 downto 0);
   signal araddr : slv(31 downto 0);

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

   U_Microblaze : component MicroblazeBasicCore
      port map (
         -- Master AXI-Lite Interface
         M_AXI_DP_awaddr     => awaddr,
         M_AXI_DP_awprot     => mAxilWriteMaster.awprot,
         M_AXI_DP_awvalid    => mAxilWriteMaster.awvalid,
         M_AXI_DP_wdata      => mAxilWriteMaster.wdata,
         M_AXI_DP_wstrb      => mAxilWriteMaster.wstrb,
         M_AXI_DP_wvalid     => mAxilWriteMaster.wvalid,
         M_AXI_DP_bready     => mAxilWriteMaster.bready,
         M_AXI_DP_awready    => mAxilWriteSlave.awready,
         M_AXI_DP_wready     => mAxilWriteSlave.wready,
         M_AXI_DP_bresp      => mAxilWriteSlave.bresp,
         M_AXI_DP_bvalid     => mAxilWriteSlave.bvalid,
         M_AXI_DP_araddr     => araddr,
         M_AXI_DP_arprot     => mAxilReadMaster.arprot,
         M_AXI_DP_arvalid    => mAxilReadMaster.arvalid,
         M_AXI_DP_rready     => mAxilReadMaster.rready,
         M_AXI_DP_arready    => mAxilReadSlave.arready,
         M_AXI_DP_rdata      => mAxilReadSlave.rdata,
         M_AXI_DP_rresp      => mAxilReadSlave.rresp,
         M_AXI_DP_rvalid     => mAxilReadSlave.rvalid,
         -- Master AXIS Interface
         M0_AXIS_tdata       => mAxisMaster.tdata(31 downto 0),
         M0_AXIS_tlast       => mAxisMaster.tlast,
         M0_AXIS_tvalid      => mAxisMaster.tvalid,
         M0_AXIS_tready      => mAxisSlave.tready,
         -- Slave AXIS Interface
         S0_AXIS_tdata       => sAxisMaster.tdata(31 downto 0),
         S0_AXIS_tlast       => sAxisMaster.tlast,
         S0_AXIS_tvalid      => sAxisMaster.tvalid,
         S0_AXIS_tready      => sAxisSlave.tready,
         -- Interrupt Interface
         INTERRUPT_ack       => irqAck,
         INTERRUPT_address   => irqAddr,
         INTERRUPT_interrupt => irqReq,
         -- Clock and Reset
         clk                 => clk,
         dcm_locked          => locked,
         reset               => rst);

end mapping;
