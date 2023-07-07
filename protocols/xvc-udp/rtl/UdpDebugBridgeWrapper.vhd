-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for UDP 'XVC' Server
-------------------------------------------------------------------------------
-- This file is part of 'xvc-udp-debug-bridge'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'xvc-udp-debug-bridge', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity UdpDebugBridgeWrapper is
   generic (
      TPD_G           : time := 1 ns;
      AXIS_CLK_FREQ_G : real := 156.25e6);
   port (
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl;
      -- UDP XVC Interface
      obServerMaster : in  AxiStreamMasterType;
      obServerSlave  : out AxiStreamSlaveType;
      ibServerMaster : out AxiStreamMasterType;
      ibServerSlave  : in  AxiStreamSlaveType);
end UdpDebugBridgeWrapper;

architecture rtl of UdpDebugBridgeWrapper is

   component UdpDebugBridge is
      generic (
         AXIS_CLK_FREQ_G : real);
      port (
         axisClk            : in  std_logic;
         axisRst            : in  std_logic;
         \mAxisReq[tValid]\ : in  std_logic;
         \mAxisReq[tData]\  : in  std_logic_vector (511 downto 0);
         \mAxisReq[tStrb]\  : in  std_logic_vector (63 downto 0);
         \mAxisReq[tKeep]\  : in  std_logic_vector (63 downto 0);
         \mAxisReq[tLast]\  : in  std_logic;
         \mAxisReq[tDest]\  : in  std_logic_vector (7 downto 0);
         \mAxisReq[tId]\    : in  std_logic_vector (7 downto 0);
         \mAxisReq[tUser]\  : in  std_logic_vector (511 downto 0);
         \sAxisReq[tReady]\ : out std_logic;
         \mAxisTdo[tValid]\ : out std_logic;
         \mAxisTdo[tData]\  : out std_logic_vector (511 downto 0);
         \mAxisTdo[tStrb]\  : out std_logic_vector (63 downto 0);
         \mAxisTdo[tKeep]\  : out std_logic_vector (63 downto 0);
         \mAxisTdo[tLast]\  : out std_logic;
         \mAxisTdo[tDest]\  : out std_logic_vector (7 downto 0);
         \mAxisTdo[tId]\    : out std_logic_vector (7 downto 0);
         \mAxisTdo[tUser]\  : out std_logic_vector (511 downto 0);
         \sAxisTdo[tReady]\ : in  std_logic
         );
   end component UdpDebugBridge;

   type SofRegType is record
      sof : sl;
   end record SofRegType;

   constant SOF_REG_INIT_C : SofRegType := (sof => '1');

   signal rSof   : SofRegType := SOF_REG_INIT_C;
   signal rinSof : SofRegType;

   signal mXvcServerTdo : AxiStreamMasterType;

begin

   ----------------------------
   -- 'XVC' Server @2542 (modified protocol to work over UDP)
   ----------------------------
   P_SOF_COMB : process(ibServerSlave, mXvcServerTdo, rSof) is
      variable v : SofRegType;
   begin
      v := rSof;
      if ((mXvcServerTdo.tValid and ibServerSlave.tReady) = '1') then
         v.sof := mXvcServerTdo.tLast;
      end if;
      rinSof <= v;
   end process P_SOF_COMB;

   P_SOF_SEQ : process(clk) is
   begin
      if (rising_edge(clk)) then
         if (rst = '1') then
            rSof <= SOF_REG_INIT_C after TPD_G;
         else
            rSof <= rinSof after TPD_G;
         end if;
      end if;
   end process P_SOF_SEQ;

   -- splice in the SOF bit
   P_SOF_SPLICE : process(mXvcServerTdo, rSof) is
      variable v : AxiStreamMasterType;
   begin
      v              := mXvcServerTdo;
      ssiSetUserSof(EMAC_AXIS_CONFIG_C, v, rSof.sof);
      ibServerMaster <= v;
   end process P_SOF_SPLICE;

   U_XvcServer : component UdpDebugBridge
      generic map (
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G)
      port map (
         axisClk => clk,
         axisRst => rst,

         \mAxisReq[tValid]\ => obServerMaster.tValid,
         \mAxisReq[tData]\  => obServerMaster.tData,
         \mAxisReq[tStrb]\  => obServerMaster.tStrb,
         \mAxisReq[tKeep]\  => obServerMaster.tKeep,
         \mAxisReq[tLast]\  => obServerMaster.tLast,
         \mAxisReq[tDest]\  => obServerMaster.tDest,
         \mAxisReq[tId]\    => obServerMaster.tId,
         \mAxisReq[tUser]\  => obServerMaster.tUser,
         \sAxisReq[tReady]\ => obServerSlave.tReady,
         \mAxisTdo[tValid]\ => mXvcServerTdo.tValid,
         \mAxisTdo[tData]\  => mXvcServerTdo.tData,
         \mAxisTdo[tStrb]\  => mXvcServerTdo.tStrb,
         \mAxisTdo[tKeep]\  => mXvcServerTdo.tKeep,
         \mAxisTdo[tLast]\  => mXvcServerTdo.tLast,
         \mAxisTdo[tDest]\  => mXvcServerTdo.tDest,
         \mAxisTdo[tId]\    => mXvcServerTdo.tId,
         \mAxisTdo[tUser]\  => mXvcServerTdo.tUser,
         \sAxisTdo[tReady]\ => ibServerSlave.tReady);

end rtl;
