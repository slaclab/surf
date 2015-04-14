-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TcpHls.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-10
-- Last update: 2015-04-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity TcpHls is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl;
      -- Slave Port
      sXMacMaster : in  AxiStreamMasterType;
      sXMacSlave  : out AxiStreamSlaveType;
      -- Master Port
      mXMacMaster : out AxiStreamMasterType;
      mXMacSlave  : in  AxiStreamSlaveType);         
end TcpHls;

architecture rtl of TcpHls is

   constant MY_MAC_ADDR_C : slv(47 downto 0) := x"010300564400";
   constant MY_IP_ADDR_C  : slv(31 downto 0) := x"C0A8010A";

   component TcpHlsCore
      port (
         sXMac_TDATA          : in  std_logic_vector(63 downto 0);
         sXMac_TKEEP          : in  std_logic_vector(7 downto 0);
         sXMac_TUSER          : in  std_logic_vector(127 downto 0);
         sXMac_TLAST          : in  std_logic_vector(0 downto 0);
         queryIP_V_V_dout     : in  std_logic_vector(31 downto 0);
         queryIP_V_V_empty_n  : in  std_logic;
         queryIP_V_V_read     : out std_logic;
         mXMac_TDATA          : out std_logic_vector(63 downto 0);
         mXMac_TKEEP          : out std_logic_vector(7 downto 0);
         mXMac_TUSER          : out std_logic_vector(127 downto 0);
         mXMac_TLAST          : out std_logic_vector(0 downto 0);
         returnMAC_V_V_din    : out std_logic_vector(47 downto 0);
         returnMAC_V_V_full_n : in  std_logic;
         returnMAC_V_V_write  : out std_logic;
         myMacAddr_V          : in  std_logic_vector(47 downto 0);
         myIpAddr             : in  std_logic_vector(31 downto 0);
         ap_clk               : in  std_logic;
         ap_rst_n             : in  std_logic;
         sXMac_TVALID         : in  std_logic;
         sXMac_TREADY         : out std_logic;
         ap_done              : out std_logic;
         mXMac_TVALID         : out std_logic;
         mXMac_TREADY         : in  std_logic;
         ap_start             : in  std_logic;
         ap_idle              : out std_logic;
         ap_ready             : out std_logic
         );
   end component;

   signal rstL       : sl;
   signal xMacMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   
begin

   rstL                          <= not(rst);
   mXMacMaster                   <= xMacMaster;
   xMacMaster.tKeep(15 downto 8) <= (others => '0');

   TcpHlsCore_Inst : TcpHlsCore
      port map (
         -- Remapping IP Address to byte swap
         myIpAddr(31 downto 24)    => MY_IP_ADDR_C(7 downto 0),
         myIpAddr(23 downto 16)    => MY_IP_ADDR_C(15 downto 8),
         myIpAddr(15 downto 8)     => MY_IP_ADDR_C(23 downto 16),
         myIpAddr(7 downto 0)      => MY_IP_ADDR_C(31 downto 24),
         -- Remapping MAC Address to byte swap
         myMacAddr_V(47 downto 40) => MY_MAC_ADDR_C(7 downto 0),
         myMacAddr_V(39 downto 32) => MY_MAC_ADDR_C(15 downto 8),
         myMacAddr_V(31 downto 24) => MY_MAC_ADDR_C(23 downto 16),
         myMacAddr_V(23 downto 16) => MY_MAC_ADDR_C(31 downto 24),
         myMacAddr_V(15 downto 8)  => MY_MAC_ADDR_C(39 downto 32),
         myMacAddr_V(7 downto 0)   => MY_MAC_ADDR_C(47 downto 40),
         -- MAC Inbound Streaming Interface
         sXMac_TDATA               => sXMacMaster.tData(63 downto 0),
         sXMac_TKEEP               => sXMacMaster.tKeep(7 downto 0),
         sXMac_TUSER               => sXMacMaster.tUser,
         sXMac_TLAST(0)            => sXMacMaster.tLast,
         sXMac_TVALID              => sXMacMaster.tValid,
         sXMac_TREADY              => sXMacSlave.tReady,
         -- MAC Inbound Streaming Interface
         mXMac_TDATA               => xMacMaster.tData(63 downto 0),
         mXMac_TKEEP               => xMacMaster.tKeep(7 downto 0),
         mXMac_TUSER               => xMacMaster.tUser,
         mXMac_TLAST(0)            => xMacMaster.tLast,
         mXMac_TVALID              => xMacMaster.tValid,
         mXMac_TREADY              => mXMacSlave.tReady,
         -- Misc. Interfaces
         queryIP_V_V_dout          => (others => '0'),
         queryIP_V_V_empty_n       => '0',
         queryIP_V_V_read          => open,
         returnMAC_V_V_din         => open,
         returnMAC_V_V_full_n      => '1',
         returnMAC_V_V_write       => open,
         -- System Signals
         ap_clk                    => clk,
         ap_rst_n                  => rstL,
         ap_start                  => '1',
         ap_done                   => open,
         ap_idle                   => open,
         ap_ready                  => open);

end rtl;
