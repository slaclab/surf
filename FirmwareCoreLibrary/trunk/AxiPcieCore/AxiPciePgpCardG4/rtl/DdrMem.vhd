-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DdrMem.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-08
-- Last update: 2016-02-24
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
use work.AxiLitePkg.all;
use work.AxiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DdrMem is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
      MEM_TEST_G       : boolean         := false;
      SIM_SPEEDUP_G    : boolean         := false);
   port (
      -- AXI-Lite Interface
      axilClk         : in    sl                     := '0';
      axilRst         : in    sl                     := '0';
      axilReadMaster  : in    AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      memReady        : out   sl;
      memError        : out   sl;
      -- AXI4 Interface
      axiClk          : out   sl;
      axiRst          : out   sl;
      axiWriteMaster  : in    AxiWriteMasterType     := AXI_WRITE_MASTER_INIT_C;
      axiWriteSlave   : out   AxiWriteSlaveType;
      axiReadMaster   : in    AxiReadMasterType      := AXI_READ_MASTER_INIT_C;
      axiReadSlave    : out   AxiReadSlaveType;
      ----------------
      -- Core Ports --
      ----------------   
      -- DDR3L SO-DIMM Ports
      ddrClkP         : in    sl;
      ddrClkN         : in    sl;
      ddrDm           : out   slv(7 downto 0);
      ddrDqsP         : inout slv(7 downto 0);
      ddrDqsN         : inout slv(7 downto 0);
      ddrDq           : inout slv(63 downto 0);
      ddrA            : out   slv(15 downto 0);
      ddrBa           : out   slv(2 downto 0);
      ddrCsL          : out   slv(1 downto 0);
      ddrOdt          : out   slv(1 downto 0);
      ddrCke          : out   slv(1 downto 0);
      ddrCkP          : out   slv(1 downto 0);
      ddrCkN          : out   slv(1 downto 0);
      ddrWeL          : out   sl;
      ddrRasL         : out   sl;
      ddrCasL         : out   sl;
      ddrRstL         : out   sl;
      ddrAlertL       : in    sl                     := '1';
      ddrPg           : in    sl                     := '1';
      ddrPwrEnL       : out   sl);      
end DdrMem;

architecture mapping of DdrMem is

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 33,
      DATA_BYTES_C => 64,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');

   component MigCore
      port (
         c0_init_calib_complete  : out   std_logic;
         c0_sys_clk_i            : in    std_logic;
         c0_ddr3_addr            : out   std_logic_vector(15 downto 0);
         c0_ddr3_ba              : out   std_logic_vector(2 downto 0);
         c0_ddr3_cas_n           : out   std_logic;
         c0_ddr3_cke             : out   std_logic_vector(1 downto 0);
         c0_ddr3_ck_n            : out   std_logic_vector(1 downto 0);
         c0_ddr3_ck_p            : out   std_logic_vector(1 downto 0);
         c0_ddr3_cs_n            : out   std_logic_vector(1 downto 0);
         c0_ddr3_dm              : out   std_logic_vector(7 downto 0);
         c0_ddr3_dq              : inout std_logic_vector(63 downto 0);
         c0_ddr3_dqs_n           : inout std_logic_vector(7 downto 0);
         c0_ddr3_dqs_p           : inout std_logic_vector(7 downto 0);
         c0_ddr3_odt             : out   std_logic_vector(1 downto 0);
         c0_ddr3_ras_n           : out   std_logic;
         c0_ddr3_reset_n         : out   std_logic;
         c0_ddr3_we_n            : out   std_logic;
         c0_ddr3_ui_clk          : out   std_logic;
         c0_ddr3_ui_clk_sync_rst : out   std_logic;
         c0_ddr3_aresetn         : in    std_logic;
         c0_ddr3_s_axi_awid      : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_awaddr    : in    std_logic_vector(32 downto 0);
         c0_ddr3_s_axi_awlen     : in    std_logic_vector(7 downto 0);
         c0_ddr3_s_axi_awsize    : in    std_logic_vector(2 downto 0);
         c0_ddr3_s_axi_awburst   : in    std_logic_vector(1 downto 0);
         c0_ddr3_s_axi_awlock    : in    std_logic_vector(0 downto 0);
         c0_ddr3_s_axi_awcache   : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_awprot    : in    std_logic_vector(2 downto 0);
         c0_ddr3_s_axi_awqos     : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_awvalid   : in    std_logic;
         c0_ddr3_s_axi_awready   : out   std_logic;
         c0_ddr3_s_axi_wdata     : in    std_logic_vector(511 downto 0);
         c0_ddr3_s_axi_wstrb     : in    std_logic_vector(63 downto 0);
         c0_ddr3_s_axi_wlast     : in    std_logic;
         c0_ddr3_s_axi_wvalid    : in    std_logic;
         c0_ddr3_s_axi_wready    : out   std_logic;
         c0_ddr3_s_axi_bready    : in    std_logic;
         c0_ddr3_s_axi_bid       : out   std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_bresp     : out   std_logic_vector(1 downto 0);
         c0_ddr3_s_axi_bvalid    : out   std_logic;
         c0_ddr3_s_axi_arid      : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_araddr    : in    std_logic_vector(32 downto 0);
         c0_ddr3_s_axi_arlen     : in    std_logic_vector(7 downto 0);
         c0_ddr3_s_axi_arsize    : in    std_logic_vector(2 downto 0);
         c0_ddr3_s_axi_arburst   : in    std_logic_vector(1 downto 0);
         c0_ddr3_s_axi_arlock    : in    std_logic_vector(0 downto 0);
         c0_ddr3_s_axi_arcache   : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_arprot    : in    std_logic_vector(2 downto 0);
         c0_ddr3_s_axi_arqos     : in    std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_arvalid   : in    std_logic;
         c0_ddr3_s_axi_arready   : out   std_logic;
         c0_ddr3_s_axi_rready    : in    std_logic;
         c0_ddr3_s_axi_rlast     : out   std_logic;
         c0_ddr3_s_axi_rvalid    : out   std_logic;
         c0_ddr3_s_axi_rresp     : out   std_logic_vector(1 downto 0);
         c0_ddr3_s_axi_rid       : out   std_logic_vector(3 downto 0);
         c0_ddr3_s_axi_rdata     : out   std_logic_vector(511 downto 0);
         sys_rst                 : in    std_logic);
   end component;

   signal ddrWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal ddrWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal ddrReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal ddrReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

   signal ddrClk     : sl;
   signal ddrRst     : sl;
   signal reset      : sl;
   signal sysRst     : sl;
   signal axiRstL    : sl;
   signal ddrCalDone : sl;
   signal done       : sl;
   signal refClock   : sl;
   signal refClkBufg : sl;
   signal coreRst    : sl;
   signal coreRstDly : sl;

   attribute KEEP_HIERARCHY                : string;
   attribute KEEP_HIERARCHY of IBUFDS_Inst : label is "TRUE";
   attribute KEEP_HIERARCHY of BUFG_Inst   : label is "TRUE";

   attribute dont_touch               : string;
   attribute dont_touch of refClock   : signal is "TRUE";
   attribute dont_touch of refClkBufg : signal is "TRUE";

   type RegType is record
      ddrPwrEn       : sl;
      ddrReset       : sl;
      memReady       : sl;
      memError       : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      ddrPwrEn       => '1',
      ddrReset       => '0',
      memReady       => '0',
      memError       => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   axiClk    <= ddrClk;
   axiRst    <= ddrRst;
   ddrPwrEnL <= not(r.ddrPwrEn);

   IBUFDS_Inst : IBUFDS
      port map (
         I  => ddrClkP,
         IB => ddrClkN,
         O  => refClock);                 

   BUFG_Inst : BUFG
      port map (
         I => refClock,
         O => refClkBufg);     

   reset   <= axilRst or r.ddrReset;
   axiRstL <= not(sysRst);

   U_RstSync : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => refClkBufg,
         asyncRst => reset,
         syncRst  => sysRst);   

   MigCore_Inst : MigCore
      port map (
         c0_init_calib_complete  => ddrCalDone,
         c0_sys_clk_i            => refClkBufg,
         c0_ddr3_addr            => ddrA,
         c0_ddr3_ba              => ddrBa,
         c0_ddr3_cas_n           => ddrCasL,
         c0_ddr3_cke             => ddrCke,
         c0_ddr3_ck_n            => ddrCkN,
         c0_ddr3_ck_p            => ddrCkP,
         c0_ddr3_cs_n            => ddrCsL,
         c0_ddr3_dm              => ddrDm,
         c0_ddr3_dq              => ddrDq,
         c0_ddr3_dqs_n           => ddrDqsN,
         c0_ddr3_dqs_p           => ddrDqsP,
         c0_ddr3_odt             => ddrOdt,
         c0_ddr3_ras_n           => ddrRasL,
         c0_ddr3_reset_n         => ddrRstL,
         c0_ddr3_we_n            => ddrWeL,
         c0_ddr3_ui_clk          => ddrClk,
         c0_ddr3_ui_clk_sync_rst => coreRst,
         c0_ddr3_aresetn         => axiRstL,
         c0_ddr3_s_axi_awid      => ddrWriteMaster.awid(3 downto 0),
         c0_ddr3_s_axi_awaddr    => ddrWriteMaster.awaddr(32 downto 0),
         c0_ddr3_s_axi_awlen     => ddrWriteMaster.awlen(7 downto 0),
         c0_ddr3_s_axi_awsize    => ddrWriteMaster.awsize(2 downto 0),
         c0_ddr3_s_axi_awburst   => ddrWriteMaster.awburst(1 downto 0),
         c0_ddr3_s_axi_awlock    => ddrWriteMaster.awlock(0 downto 0),
         c0_ddr3_s_axi_awcache   => ddrWriteMaster.awcache(3 downto 0),
         c0_ddr3_s_axi_awprot    => ddrWriteMaster.awprot(2 downto 0),
         c0_ddr3_s_axi_awqos     => ddrWriteMaster.awqos(3 downto 0),
         c0_ddr3_s_axi_awvalid   => ddrWriteMaster.awvalid,
         c0_ddr3_s_axi_awready   => ddrWriteSlave.awready,
         c0_ddr3_s_axi_wdata     => ddrWriteMaster.wdata(511 downto 0),
         c0_ddr3_s_axi_wstrb     => ddrWriteMaster.wstrb(63 downto 0),
         c0_ddr3_s_axi_wlast     => ddrWriteMaster.wlast,
         c0_ddr3_s_axi_wvalid    => ddrWriteMaster.wvalid,
         c0_ddr3_s_axi_wready    => ddrWriteSlave.wready,
         c0_ddr3_s_axi_bready    => ddrWriteMaster.bready,
         c0_ddr3_s_axi_bid       => ddrWriteSlave.bid(3 downto 0),
         c0_ddr3_s_axi_bresp     => ddrWriteSlave.bresp(1 downto 0),
         c0_ddr3_s_axi_bvalid    => ddrWriteSlave.bvalid,
         c0_ddr3_s_axi_arid      => ddrReadMaster.arid(3 downto 0),
         c0_ddr3_s_axi_araddr    => ddrReadMaster.araddr(32 downto 0),
         c0_ddr3_s_axi_arlen     => ddrReadMaster.arlen(7 downto 0),
         c0_ddr3_s_axi_arsize    => ddrReadMaster.arsize(2 downto 0),
         c0_ddr3_s_axi_arburst   => ddrReadMaster.arburst(1 downto 0),
         c0_ddr3_s_axi_arlock    => ddrReadMaster.arlock(0 downto 0),
         c0_ddr3_s_axi_arcache   => ddrReadMaster.arcache(3 downto 0),
         c0_ddr3_s_axi_arprot    => ddrReadMaster.arprot(2 downto 0),
         c0_ddr3_s_axi_arqos     => ddrReadMaster.arqos(3 downto 0),
         c0_ddr3_s_axi_arvalid   => ddrReadMaster.arvalid,
         c0_ddr3_s_axi_arready   => ddrReadSlave.arready,
         c0_ddr3_s_axi_rready    => ddrReadMaster.rready,
         c0_ddr3_s_axi_rlast     => ddrReadSlave.rlast,
         c0_ddr3_s_axi_rvalid    => ddrReadSlave.rvalid,
         c0_ddr3_s_axi_rresp     => ddrReadSlave.rresp(1 downto 0),
         c0_ddr3_s_axi_rid       => ddrReadSlave.rid(3 downto 0),
         c0_ddr3_s_axi_rdata     => ddrReadSlave.rdata(511 downto 0),
         sys_rst                 => sysRst); 

   process(ddrClk)
   begin
      if rising_edge(ddrClk) then
         coreRstDly <= coreRst    after TPD_G;  -- Register to help with timing
         ddrRst     <= coreRstDly after TPD_G;  -- Register to help with timing
      end if;
   end process;

   MEM_TEST_GEN : if (MEM_TEST_G = true) generate
      
      U_AxiMemTester : entity work.AxiMemTester
         generic map (
            TPD_G        => TPD_G,
            START_ADDR_G => START_ADDR_C,
            STOP_ADDR_G  => ite(SIM_SPEEDUP_G, toSlv(32*4096, AXI_CONFIG_C.ADDR_WIDTH_C), STOP_ADDR_C),
            AXI_CONFIG_G => AXI_CONFIG_C)
         port map (
            -- AXI-Lite Interface
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave,
            memReady        => memReady,
            memError        => memError,
            -- DDR Memory Interface
            axiClk          => ddrClk,
            axiRst          => ddrRst,
            start           => ddrCalDone,
            axiWriteMaster  => ddrWriteMaster,
            axiWriteSlave   => ddrWriteSlave,
            axiReadMaster   => ddrReadMaster,
            axiReadSlave    => ddrReadSlave);

      -- Terminate the buses
      axiWriteSlave <= AXI_WRITE_SLAVE_INIT_C;
      axiReadSlave  <= AXI_READ_SLAVE_INIT_C;
      
   end generate;

   NORMAL_GEN : if (MEM_TEST_G = false) generate

      -- Map the AXI4 buses
      ddrWriteMaster <= axiWriteMaster;
      axiWriteSlave  <= ddrWriteSlave;
      ddrReadMaster  <= axiReadMaster;
      axiReadSlave   <= ddrReadSlave;

      U_Sync : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => axilClk,
            dataIn  => ddrCalDone,
            dataOut => done);      

      comb : process (axilReadMaster, axilRst, axilWriteMaster, ddrAlertL, ddrPg, done, r) is
         variable v         : RegType;
         variable axiStatus : AxiLiteStatusType;

         -- Wrapper procedures to make calls cleaner.
         procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv; cA : in boolean := false; cV : in slv := "0") is
         begin
            axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, addr, offset, reg, cA, cV);
         end procedure;

         procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
         begin
            axiSlaveRegister(axilReadMaster, v.axilReadSlave, axiStatus, addr, offset, reg);
         end procedure;

         procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
         begin
            axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, addr, offset, reg);
         end procedure;

         procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
         begin
            axiSlaveRegister(axilReadMaster, v.axilReadSlave, axiStatus, addr, offset, reg);
         end procedure;

         procedure axiSlaveDefault (
            axiResp : in slv(1 downto 0)) is
         begin
            axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus, axiResp);
         end procedure;

      begin
         -- Latch the current value
         v := r;

         -- Reset strobe signals
         v.ddrReset := '0';

         -- Determine the transaction type
         axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axiStatus);

         -- Map the read registers
         axiSlaveRegisterR(x"100", 0, r.memReady);
         axiSlaveRegisterR(x"104", 0, r.memError);
         axiSlaveRegisterR(x"108", 0, x"00000000");  -- AxiMemTester's wTimer
         axiSlaveRegisterR(x"10C", 0, x"00000000");  -- AxiMemTester's rTimer
         axiSlaveRegisterR(x"110", 0, x"00000000");  -- AxiMemTester's START_C Upper word
         axiSlaveRegisterR(x"114", 0, x"00000000");  -- AxiMemTester's START_C Lower word
         axiSlaveRegisterR(x"118", 0, x"00000000");  -- AxiMemTester's STOP_C Upper word
         axiSlaveRegisterR(x"11C", 0, x"00000000");  -- AxiMemTester's STOP_C Lower word
         axiSlaveRegisterR(x"120", 0, toSlv(AXI_CONFIG_C.ADDR_WIDTH_C, 32));
         axiSlaveRegisterR(x"124", 0, toSlv(AXI_CONFIG_C.DATA_BYTES_C, 32));
         axiSlaveRegisterR(x"128", 0, toSlv(AXI_CONFIG_C.ID_BITS_C, 32));
         axiSlaveRegisterR(x"130", 0, ddrAlertL);
         axiSlaveRegisterR(x"134", 0, ddrPg);

         -- Map the write registers
         axiSlaveRegisterW(x"3F8", 0, v.ddrPwrEn);
         axiSlaveRegisterW(x"3FC", 0, v.ddrReset);

         -- Set the Slave's response
         axiSlaveDefault(AXI_ERROR_RESP_G);

         -- Latch the values from Synchronizers
         v.memReady := done;

         -- Synchronous Reset
         if (axilRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         axilWriteSlave <= r.axilWriteSlave;
         axilReadSlave  <= r.axilReadSlave;
         memReady       <= r.memReady;
         memError       <= r.memError;
         
      end process comb;

      seq : process (axilClk) is
      begin
         if (rising_edge(axilClk)) then
            r <= rin after TPD_G;
         end if;
      end process seq;

   end generate;
   
end mapping;
