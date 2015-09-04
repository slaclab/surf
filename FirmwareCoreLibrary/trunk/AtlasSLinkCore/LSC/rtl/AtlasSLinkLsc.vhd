-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasSLinkLsc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-10
-- Last update: 2015-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PpiPkg.all;
use work.AtlasSLinkLscPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AtlasSLinkLsc is
   generic (
      -- General Configurations
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      PPI_NOT_SSI_G      : boolean;
      -- FIFO configurations
      CASCADE_SIZE_G     : natural               := 1);   
   port (
      -- AXI-Lite Register Interface (axiClk domain)
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      statusWords    : out Slv64Array(0 to 0);
      statusSend     : out sl;
      -- Streaming RX Data Interface (sAxisClk domain) 
      sAxisClk       : in  sl;
      sAxisRst       : in  sl;
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      -- Reference 100 MHz clock and reset
      sysClk         : in  sl;
      sysRst         : in  sl;
      -- Misc. Status LEDs
      testLed        : out sl;
      ldErrLed       : out sl;
      flowCtrlLed    : out sl;
      activityLed    : out sl;
      -- G-Link's MGT Serial IO
      gtTxP          : out sl;
      gtTxN          : out sl;
      gtRxP          : in  sl;
      gtRxN          : in  sl);
end AtlasSLinkLsc;

architecture rtl of AtlasSLinkLsc is

   constant SLAVE_AXI_CONFIG_C  : AxiStreamConfigType := ite(PPI_NOT_SSI_G, ppiAxiStreamConfig(8), ssiAxiStreamConfig(8));
   constant MASTER_AXI_CONFIG_C : AxiStreamConfigType := ite(PPI_NOT_SSI_G, ppiAxiStreamConfig(4), ssiAxiStreamConfig(4));

   constant MAX_CNT_C : slv(31 downto 0) := toSlv(getTimeRatio(100.0E6, 1.0), 32);  -- 1 second integration
   
   type StateType is (
      START_S,
      DATA_S,
      STOP_S);    

   type RegType is record
      wen        : sl;
      ctrl       : sl;
      blowOff    : sl;
      tReady     : sl;
      xorCheck   : sl;
      xorCalc    : slv(31 downto 0);
      data       : slv(31 downto 0);
      cnt        : slv(31 downto 0);
      pktCnt     : slv(31 downto 0);
      pktCntMax  : slv(31 downto 0);
      pktCntMin  : slv(31 downto 0);
      rateCnt    : slv(31 downto 0);
      blowOffCnt : natural range 0 to 31;
      accum      : slv(31 downto 0);
      fullRate   : slv(31 downto 0);
      state      : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      wen        => '0',
      ctrl       => '0',
      blowOff    => '0',
      tReady     => '0',
      xorCheck   => '0',
      xorCalc    => (others => '0'),
      data       => (others => '0'),
      cnt        => (others => '0'),
      pktCnt     => (others => '0'),
      pktCntMax  => (others => '0'),
      pktCntMin  => (others => '1'),
      rateCnt    => (others => '0'),
      blowOffCnt => 0,
      accum      => (others => '0'),
      fullRate   => (others => '0'),
      state      => START_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sysRstL,
      divClk,
      ICLK2,
      sysReset,
      userTestL,
      userCtrlL,
      writeEnbleL,
      linkFullFlagL,
      lDownL,
      testLedL,
      ldErrLedL,
      lUpLedL,
      flowCtrlLedL,
      activityLedL,
      TLK_TXEN,
      TLK_TXER,
      TLK_RXDV,
      TLK_RXER,
      LSC_RST_N : sl;
   
   signal TLK_TXD,
      TLK_RXD : slv(15 downto 0);
   
   signal config : AtlasSLinkLscConfigType;
   signal status : AtlasSLinkLscStatusType;

   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;

   signal axisSlave : AxiStreamSlaveType;

   -- attribute KEEP_HIERARCHY : string;
   -- attribute KEEP_HIERARCHY of
   -- holalsc_core_1 : label is "TRUE";
   
begin

   -------------------------------     
   -- Configuration/Status Register   
   -------------------------------   
   AtlasSLinkLscReg_Inst : entity work.AtlasSLinkLscReg
      generic map (
         TPD_G              => TPD_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G)
      port map (
         -- AXI-Lite Register Interface (axiClk domain)
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         statusWords    => statusWords,
         statusSend     => statusSend,
         -- Configuration and Status Interface (sysClk domain)
         sysClk         => sysClk,
         sysRst         => sysRst,
         config         => config,
         status         => status);       

   ------------------
   -- Input Data FIFO   
   ------------------
   AxiStreamFifo_Rx : entity work.AxiStreamFifo
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisClk    => sysClk,
         mAxisRst    => sysRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave); 

   sAxisSlave <= axisSlave;

   -----------------------------
   -- Input Data FIFO Monitoring
   -----------------------------
   AtlasSLinkLscDmaMon_Inst : entity work.AtlasSLinkLscDmaMon
      generic map(
         TPD_G => TPD_G)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain) 
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => axisSlave,
         -- Reference 100 MHz clock and reset
         sysClk      => sysClk,
         sysRst      => sysReset,
         -- Status Signals (sysClk domain)
         dmaSize     => status.dmaSize,
         dmaMinSize  => status.dmaMinSize,
         dmaMaxSize  => status.dmaMaxSize);        

   ------------------------
   -- ATLAS S-Link LSC Core  
   ------------------------
   holalsc_core_1 : entity work.holalsc_core
      generic map (
         SIMULATION      => 0,          -- Not in simulation mode
         XCLK_FREQ       => 100,        -- XCLK = 100 MHz
         USE_PLL         => 0,          -- Do not use PLL to generate ICLK_2
         USE_ICLK2       => 1,          -- use external ICLK2 input
         ACTIVITY_LENGTH => 15,  -- ACTLED duration // NOTE: Only gets applied to ACTIVITYLED_N
         FIFODEPTH       => 2**10,  -- LSC FIFO depth, only powers of 2 // NOTE: This generic is unused in this implementation of the holalsc_core
         LOG2DEPTH       => 10,         -- 2log of depth
         FULLMARGIN      => 16)  -- words left when LFF_N set // NOTE: This generic is unused in this implementation of the holalsc_core
      port map (
         POWER_UP_RST_N => LSC_RST_N,
         -- S-LINK signals 
         UD             => r.data,
         URESET_N       => sysRstL,
         UTEST_N        => userTestL,
         UCTRL_N        => userCtrlL,
         UWEN_N         => writeEnbleL,
         UCLK           => sysClk,
         LFF_N          => linkFullFlagL,
         LRL            => open,
         LDOWN_N        => lDownL,
         -- S-LINK LEDs 
         TESTLED_N      => testLedL,
         LDERRLED_N     => ldErrLedL,
         LUPLED_N       => lUpLedL,
         FLOWCTLLED_N   => flowCtrlLedL,
         ACTIVITYLED_N  => activityLedL,
         -- Reference Clock
         XCLK           => sysClk,
         ICLK2_IN       => ICLK2,
         -- TLK2501 transmit ports
         TXD            => TLK_TXD,
         TX_EN          => TLK_TXEN,
         TX_ER          => TLK_TXER,
         -- TLK2501 transmit ports
         RXD            => TLK_RXD,
         RX_CLK         => sysClk,
         RX_ER          => TLK_RXER,
         RX_DV          => TLK_RXDV);   

   ----------------------
   -- Generate div2 clock
   ----------------------         
   U_BUFR : BUFR
      generic map (
         BUFR_DIVIDE => "2",
         SIM_DEVICE  => "7SERIES")
      port map (
         I   => sysClk,
         CE  => '1',
         CLR => '0',
         O   => divClk);

   U_BUFG : BUFG
      port map (
         I => divClk,
         O => ICLK2);  

   -----------------
   -- Signal Mapping
   -----------------
   sysReset  <= sysRst or config.userRst;
   sysRstL   <= not(sysReset);
   LSC_RST_N <= sysRstL and status.gtxReady;

   status.linkUp     <= not(lUpLedL);
   status.linkDown   <= not(lDownL);
   status.linkFull   <= not(linkFullFlagL);
   status.packetSent <= mAxisMaster.tLast;
   status.testMode   <= not(testLedL);
   status.overflow   <= not(ldErrLedL);
   status.flowCtrl   <= not(flowCtrlLedL);
   status.linkActive <= not(activityLedL);

   testLed     <= not(testLedL);
   ldErrLed    <= not(ldErrLedL);
   flowCtrlLed <= not(flowCtrlLedL);
   activityLed <= not(activityLedL);

   writeEnbleL <= not(r.wen);
   userCtrlL   <= not(r.ctrl);
   userTestL   <= '1';                  -- not used

   -----------------------------   
   -- Link Busy Rate measurement  
   -----------------------------   
   comb : process (config, mAxisMaster, r, status, sysReset) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.wen  := '0';
      v.ctrl := '0';

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when START_S =>
            -- Update the tReady
            v.tReady := '0';
            -- Check if FIFO is ready
            if (status.linkFull = '0') and (mAxisMaster.tValid = '1') and (r.tReady = '0') then
               -- Send the "start" control message
               v.wen      := '1';
               v.ctrl     := '1';
               v.data     := config.startCmd;
               -- Ready for data
               v.tReady   := '1';
               -- Reset the flags
               v.xorCheck := '0';
               v.xorCalc  := toSlv(0, 32);
               -- Next State
               v.State    := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Ready for data
            v.tReady := not(status.linkFull);
            -- Check if FIFO is ready
            if (r.tReady = '1') and (mAxisMaster.tValid = '1') then
               -- Increment the counter
               v.cnt  := r.cnt + 1;
               -- Send the data payload
               v.wen  := '1';
               v.data := mAxisMaster.tData(31 downto 0);
               -- Calculate the XOR word
               for i in 0 to 31 loop
                  v.xorCalc(i) := r.xorCalc(i) xor mAxisMaster.tData(i);
               end loop;
               -- Check for last transfer
               if (mAxisMaster.tLast = '1') then
                  -- Stop receiving data
                  v.tReady := '0';
                  -- Next State
                  v.State  := STOP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when STOP_S =>
            -- Check if FIFO is ready
            if (status.linkFull = '0') then
               -- Send the "stop" control message
               v.wen    := '1';
               v.ctrl   := '1';
               v.data   := config.stopCmd;
               -- Update the current value
               v.pktCnt := r.cnt;
               -- Check the max. value
               if (r.cnt > r.pktCntMax) then
                  -- Update max. value
                  v.pktCntMax := r.cnt;
               end if;
               -- Check the min. value
               if (r.cnt < r.pktCntMin) then
                  -- Update min. value
                  v.pktCntMin := r.cnt;
               end if;
               -- Reset the counter
               v.cnt := (others => '0');
               -- Set the flag
               if r.xorCalc /= 0 then
                  v.xorCheck := '1';
               end if;
               -- Next State
               v.State := START_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check if we need to accumulate
      if status.linkFull = '1' then
         v.accum := r.accum + 1;
      end if;

      -- Increment the counter
      v.rateCnt := r.rateCnt + 1;
      -- Check if we are done integrating
      if r.rateCnt = MAX_CNT_C then
         -- Reset the counter
         v.rateCnt  := (others => '0');
         -- Update the full rate value
         v.fullRate := r.accum;
         -- Reset the accumulator
         v.accum    := (others => '0');
      end if;

      -- Increment the counter
      v.blowOffCnt := r.blowOffCnt + 1;
      if r.blowOffCnt = 31 then
         v.blowOffCnt := 0;
      end if;

      if (config.blowOff = '1') then
         -- Set the blow off bit
         v.blowOff := config.blowOffMask(r.blowOffCnt);
         -- Reset the control signals
         v.wen     := '0';
         v.ctrl    := '0';
         v.tReady  := '0';
         -- Next State
         v.State   := START_S;
      else
         v.blowOff := '0';
      end if;

      -- Synchronous Reset
      if (sysReset = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      status.fullRate   <= r.fullRate;
      status.pktCnt     <= r.pktCnt;
      status.pktCntMax  <= r.pktCntMax;
      status.pktCntMin  <= r.pktCntMin;
      status.xorCheck   <= r.xorCheck;
      mAxisSlave.tReady <= r.tReady or r.blowOff;
      
   end process comb;

   seq : process (sysClk) is
   begin
      if rising_edge(sysClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -----------------------------
   -- ATLAS S-Link MGT Front End
   -----------------------------
   AtlasSLinkLscGtx7_Inst : entity work.AtlasSLinkLscGtx7
      generic map (
         TPD_G => TPD_G)
      port map (
         sysClk    => sysClk,
         sysRst    => sysReset,
         gtRstDone => status.gtxReady,
         -- G-Link's MGT Serial IO
         gtTxP     => gtTxP,
         gtTxN     => gtTxN,
         gtRxP     => gtRxP,
         gtRxN     => gtRxN,
         -- TLK2501 transmit ports
         TLK_TXD   => TLK_TXD,
         TLK_TXEN  => TLK_TXEN,
         TLK_TXER  => TLK_TXER,
         -- TLK2501 transmit ports
         TLK_RXD   => TLK_RXD,
         TLK_RXDV  => TLK_RXDV,
         TLK_RXER  => TLK_RXER);  

   -------------------------------     
   -- Debugging Signals   
   ------------------------------- 
   Sync_sAxis : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk        => sysClk,
         dataIn(0)  => axisSlave.tReady,
         dataIn(1)  => sAxisMaster.tValid,
         dataOut(0) => status.debug(0)(0),
         dataOut(1) => status.debug(0)(1));       

   status.debug(0)(4) <= mAxisSlave.tReady;
   status.debug(0)(5) <= mAxisMaster.tValid;

   status.debug(0)(8)  <= '1' when(r.state = START_S) else '0';
   status.debug(0)(9)  <= '1' when(r.state = DATA_S)  else '0';
   status.debug(0)(10) <= '1' when(r.state = STOP_S)  else '0';

   status.debug(0)(12) <= status.linkFull;

   status.debug(0)(16) <= not(testLedL);
   status.debug(0)(17) <= not(ldErrLedL);
   status.debug(0)(18) <= not(flowCtrlLedL);
   status.debug(0)(19) <= not(activityLedL);

end rtl;
