-------------------------------------------------------------------------------
-- Title      : PgpCardG3 Wrapper for SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : PgpCardG3PcieFrontEnd.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-24
-- Last update: 2015-04-24
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpCardG3PcieFrontEnd is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- PCIe Interface      
      cfgFromPci  : out PcieCfgOutType;
      cfgToPci    : in  PcieCfgInType;
      pciIbMaster : in  AxiStreamMasterType;
      pciIbSlave  : out AxiStreamSlaveType;
      pciObMaster : out AxiStreamMasterType;
      pciObSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset Signals
      pciClk      : out sl;
      pciRst      : out sl;
      pciLinkUp   : out sl;
      -- PCIe Ports 
      pciRstL     : in  sl;
      pciRefClkP  : in  sl;
      pciRefClkN  : in  sl;
      pciRxP      : in  slv(3 downto 0);
      pciRxN      : in  slv(3 downto 0);
      pciTxP      : out slv(3 downto 0);
      pciTxN      : out slv(3 downto 0));     
end PgpCardG3PcieFrontEnd;

architecture mapping of PgpCardG3PcieFrontEnd is

   signal pciRefClk : sl;
   signal sysRstL   : sl;
   signal locClk    : sl;
   signal userRst   : sl;
   signal locRst    : sl;
   signal userLink  : sl;

   signal pciTxInUser  : slv(3 downto 0);
   signal rxBarHit     : slv(7 downto 0);
   signal pciRxOutUser : slv(21 downto 0);
   
begin

   pciClk <= locClk;
   pciRst <= locRst;

   Synchronizer_userRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userRst,
         dataOut => locRst);     

   Synchronizer_userLink : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userLink,
         dataOut => pciLinkUp); 

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map(
         I     => pciRefClkP,
         IB    => pciRefClkN,
         CEB   => '0',
         O     => pciRefClk,
         ODIV2 => open);        

   IBUF_Inst : IBUF
      port map(
         I => pciRstL,
         O => sysRstL);          

   PcieCore_Inst : entity work.PgpCardG3SsiPcieIpCore
      port map(
         -------------------------------------
         -- PCI Express (pci_exp) Interface --
         -------------------------------------
         -- TX
         pci_exp_txp      => pciTxP,
         pci_exp_txn      => pciTxN,
         -- RX
         pci_exp_rxp      => pciRxP,
         pci_exp_rxn      => pciRxN,
         ---------------------
         -- AXI-S Interface --
         ---------------------
         -- Common
         user_clk_out     => locClk,
         user_reset_out   => userRst,
         user_lnk_up      => userLink,
         user_app_rdy     => open,
         -- TX
         s_axis_tx_tready => pciIbSlave.tReady,
         s_axis_tx_tdata  => pciIbMaster.tData,
         s_axis_tx_tkeep  => pciIbMaster.tKeep,
         s_axis_tx_tlast  => pciIbMaster.tLast,
         s_axis_tx_tvalid => pciIbMaster.tValid,
         s_axis_tx_tuser  => pciTxInUser,
         -- RX
         m_axis_rx_tdata  => pciObMaster.tData,
         m_axis_rx_tkeep  => open,      -- pciObMaster.tKeep port not valid in 128 bit mode
         m_axis_rx_tlast  => open,      -- rx.tLast gets sent via pciRxOutUser when in 128 bit mode
         m_axis_rx_tvalid => pciObMaster.tValid,
         m_axis_rx_tready => pciObSlave.tReady,
         m_axis_rx_tuser  => pciRxOutUser,

         tx_cfg_gnt             => '1',  -- Always allow transmission of Config traffic within block
         rx_np_ok               => '1',  -- Allow Reception of Non-posted Traffic
         rx_np_req              => '1',  -- Always request Non-posted Traffic if available
         cfg_trn_pending        => cfgToPci.trnPending,
         cfg_pm_halt_aspm_l0s   => '0',  -- Allow entry into L0s
         cfg_pm_halt_aspm_l1    => '0',  -- Allow entry into L1
         cfg_pm_force_state_en  => '0',  -- Do not qualify cfg_pm_force_state
         cfg_pm_force_state     => "00",  -- Do not move force core into specific PM state
         cfg_dsn                => cfgToPci.serialNumber,
         cfg_turnoff_ok         => cfgToPci.turnoffOk,
         cfg_pm_wake            => '0',  -- Never direct the core to send a PM_PME Message
         cfg_pm_send_pme_to     => '0',
         cfg_ds_bus_number      => x"00",
         cfg_ds_device_number   => "00000",
         cfg_ds_function_number => "000",

         cfg_device_number         => cfgFromPci.deviceNumber,
         cfg_dcommand2             => open,
         cfg_pmcsr_pme_status      => open,
         cfg_status                => cfgFromPci.status,
         cfg_to_turnoff            => cfgFromPci.toTurnOff,
         cfg_received_func_lvl_rst => open,
         cfg_dcommand              => cfgFromPci.dCommand,
         cfg_bus_number            => cfgFromPci.busNumber,
         cfg_function_number       => cfgFromPci.functionNumber,
         cfg_command               => cfgFromPci.command,
         cfg_dstatus               => cfgFromPci.dStatus,
         cfg_lstatus               => cfgFromPci.lStatus,
         cfg_pcie_link_state       => cfgFromPci.linkState,
         cfg_lcommand              => cfgFromPci.lCommand,
         cfg_pmcsr_pme_en          => open,
         cfg_pmcsr_powerstate      => open,
         tx_buf_av                 => open,
         tx_err_drop               => open,
         tx_cfg_req                => open,

         cfg_bridge_serr_en                         => open,
         cfg_slot_control_electromech_il_ctl_pulse  => open,
         cfg_root_control_syserr_corr_err_en        => open,
         cfg_root_control_syserr_non_fatal_err_en   => open,
         cfg_root_control_syserr_fatal_err_en       => open,
         cfg_root_control_pme_int_en                => open,
         cfg_aer_rooterr_corr_err_reporting_en      => open,
         cfg_aer_rooterr_non_fatal_err_reporting_en => open,
         cfg_aer_rooterr_fatal_err_reporting_en     => open,
         cfg_aer_rooterr_corr_err_received          => open,
         cfg_aer_rooterr_non_fatal_err_received     => open,
         cfg_aer_rooterr_fatal_err_received         => open,
         cfg_vc_tcvc_map                            => open,
         -- EP Only
         cfg_interrupt                              => cfgToPci.irqReq,
         cfg_interrupt_rdy                          => cfgFromPci.irqAck,
         cfg_interrupt_assert                       => cfgToPci.irqAssert,
         cfg_interrupt_di                           => (others => '0'),  -- Do not set interrupt fields
         cfg_interrupt_do                           => open,
         cfg_interrupt_mmenable                     => open,
         cfg_interrupt_msienable                    => open,
         cfg_interrupt_msixenable                   => open,
         cfg_interrupt_msixfm                       => open,
         cfg_interrupt_stat                         => '0',  -- Never set the Interrupt Status bit
         cfg_pciecap_interrupt_msgnum               => "00000",  -- Zero out Interrupt Message Number             
         ---------------------------
         -- System(SYS) Interface --
         ---------------------------
         sys_clk                                    => pciRefClk,
         sys_rst_n                                  => sysRstL);       

   -- Receive ECRC Error: Indicates the current packet has an 
   -- ECRC error. Asserted at the packet EOF.
   pciTxInUser(0) <= '0';

   -- Receive Error Forward: When asserted, marks the packet in 
   -- progress as error-poisoned. Asserted by the core for the 
   -- entire length of the packet.
   pciTxInUser(1) <= '0';

   -- Transmit Streamed: Indicates a packet is presented on consecutive
   -- clock cycles and transmission on the link can begin before the entire 
   -- packet has been written to the core. Commonly referred as transmit cut-through mode
   pciTxInUser(2) <= '0';

   -- Transmit SourceDiscontinue: Can be asserted any time starting 
   -- on the first cycle after SOF. Assert s_axis_tx_tlast simultaneously 
   -- with (tx_src_dsc)s_axis_tx_tuser[3].
   pciTxInUser(3) <= '0';

   -- pciRxOut_user[21:17] (rx_is_eof[4:0]) only used in 128 bit interface
   -- Bit 4: Asserted when a packet is ending
   -- Bit 0-3: Indicates byte location of end of the packet, binary encoded  
   pciObMaster.tLast <= pciRxOutUser(21);
   process(pciRxOutUser)
   begin
      if pciRxOutUser(21) = '0' then
         pciObMaster.tKeep <= x"FFFF";
      elsif pciRxOutUser(20 downto 17) = x"B" then
         pciObMaster.tKeep <= x"0FFF";
      elsif pciRxOutUser(20 downto 17) = x"7" then
         pciObMaster.tKeep <= x"00FF";
      elsif pciRxOutUser(20 downto 17) = x"3" then
         pciObMaster.tKeep <= x"000F";
      else
         pciObMaster.tKeep <= x"FFFF";
      end if;
   end process;

   -- pciRxOut_user[16:15] -- IP Core Reserved

   -- pciRxOut_user[14:10] (rx_is_sof[4:0]) only used in 128 bit interface
   -- Bit 4: Asserted when a new packet is present
   -- Bit 0-3: Indicates byte location of start of new packet, binary encoded
   pciObMaster.tUser(0)          <= '0';
   pciObMaster.tUser(1)          <= pciRxOutUser(14);
   pciObMaster.tUser(3 downto 2) <= (others => '0');

   -- Pass the EOF and SOF buses to the receiver
   pciObMaster.tUser(7 downto 4)  <= pciRxOutUser(13 downto 10);  -- SOF[3:0]
   pciObMaster.tUser(11 downto 8) <= pciRxOutUser(20 downto 17);  -- EOF[3:0]

   -- Unused tUser bits
   pciObMaster.tUser(127 downto 12) <= (others => '0');

   -- Receive BAR Hit: Indicates BAR(s) targeted by the current 
   -- receive transaction. Asserted from the beginning of the 
   -- packet to m_axis_rx_tlast.
   rxBarHit(7 downto 0) <= pciRxOutUser(9 downto 2);
   process(rxBarHit)
   begin
      -- Encode bar hit value
      if rxBarHit(0) = '1' then
         pciObMaster.tDest <= x"00";
      elsif rxBarHit(1) = '1' then
         pciObMaster.tDest <= x"01";
      elsif rxBarHit(2) = '1' then
         pciObMaster.tDest <= x"02";
      elsif rxBarHit(3) = '1' then
         pciObMaster.tDest <= x"03";
      elsif rxBarHit(4) = '1' then
         pciObMaster.tDest <= x"04";
      elsif rxBarHit(5) = '1' then
         pciObMaster.tDest <= x"05";
      elsif rxBarHit(6) = '1' then
         pciObMaster.tDest <= x"06";
      else
         pciObMaster.tDest <= x"07";
      end if;
   end process;

   -- Receive Error Forward: When asserted, marks the packet in progress as
   -- error-poisoned. Asserted by the core for the entire length of the packet.
   -- pciRxOutUser(1);-- Unused

   -- Receive ECRC Error: Indicates the current packet has an ECRC error. 
   -- Asserted at the packet EOF
   -- pciRxOutUser(0);-- Unused

   -- Terminate unused pciObMaster signals
   pciObMaster.tStrb <= (others => '0');
   pciObMaster.tId   <= (others => '0');

end mapping;
