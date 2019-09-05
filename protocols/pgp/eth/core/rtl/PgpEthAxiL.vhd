-------------------------------------------------------------------------------
-- File       : Pgp2bAxi.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP_ETH interface.
--
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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.PgpEthPkg.all;

entity PgpEthAxiL is
   generic (
      TPD_G            : time                  := 1 ns;
      MODE_G           : sl                    := '0';  -- AXI-Lite Register's default: '1': point-to-point, '0': Network
      WRITE_EN_G       : boolean               := false;  -- Set to false when on remote end of a link
      AXIL_CLK_FREQ_G  : real                  := 156.25E+6;
      RX_POLARITY_G    : slv(3 downto 0)       := (others => '0');
      TX_POLARITY_G    : slv(3 downto 0)       := (others => '0');
      TX_DIFF_CTRL_G   : Slv5Array(3 downto 0) := (others => "11000");
      TX_PRE_CURSOR_G  : Slv5Array(3 downto 0) := (others => "00000");
      TX_POST_CURSOR_G : Slv5Array(3 downto 0) := (others => "00000"));
   port (
      -- Clock and Reset
      pgpClk          : in  sl;
      pgpTxRst        : in  sl;
      pgpRxRst        : in  sl;
      -- Tx User interface (pgpClk domain)
      pgpTxIn         : out PgpEthTxInType;
      pgpTxOut        : in  PgpEthTxOutType;
      locTxIn         : in  PgpEthTxInType := PGP_ETH_TX_IN_INIT_C;
      -- RX PGP Interface (pgpClk domain)
      pgpRxIn         : out PgpEthRxInType;
      pgpRxOut        : in  PgpEthRxOutType;
      locRxIn         : in  PgpEthRxInType := PGP_ETH_RX_IN_INIT_C;
      -- Ethernet Configuration
      remoteMac       : in  slv(47 downto 0);
      localMac        : in  slv(47 downto 0);
      broadcastMac    : out slv(47 downto 0);
      etherType       : out slv(15 downto 0);
      commMode        : out sl;         -- '1': point-to-point, '0': Network
      -- Misc Debug Interfaces
      loopback        : out slv(2 downto 0);
      rxPolarity      : out slv(3 downto 0);
      txPolarity      : out slv(3 downto 0);
      txDiffCtrl      : out Slv5Array(3 downto 0);
      txPreCursor     : out Slv5Array(3 downto 0);
      txPostCursor    : out Slv5Array(3 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end PgpEthAxiL;

architecture rtl of PgpEthAxiL is

   constant STATUS_CNT_WIDTH_C : positive := 16;
   constant ERROR_CNT_WIDTH_C  : positive := 8;

   type RegType is record
      cntRst         : sl;
      commMode       : sl;
      broadcastMac   : slv(47 downto 0);
      etherType      : slv(15 downto 0);
      loopback       : slv(2 downto 0);
      rxPolarity     : slv(3 downto 0);
      txPolarity     : slv(3 downto 0);
      txDiffCtrl     : Slv5Array(3 downto 0);
      txPreCursor    : Slv5Array(3 downto 0);
      txPostCursor   : Slv5Array(3 downto 0);
      pgpTxIn        : PgpEthTxInType;
      pgpRxIn        : PgpEthRxInType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cntRst         => '0',
      commMode       => MODE_G,
      broadcastMac   => x"FF_FF_FF_FF_FF_FF",
      etherType      => x"11_01",       -- EtherType = 0x0111 ("Experimental")
      loopBack       => (others => '0'),
      rxPolarity     => RX_POLARITY_G,
      txPolarity     => TX_POLARITY_G,
      txDiffCtrl     => TX_DIFF_CTRL_G,
      txPreCursor    => TX_PRE_CURSOR_G,
      txPostCursor   => TX_POST_CURSOR_G,
      pgpTxIn        => PGP_ETH_TX_IN_INIT_C,
      pgpRxIn        => PGP_ETH_RX_IN_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal syncTxIn : PgpEthTxInType;

begin

   process (axilReadMaster, axilRst, axilWriteMaster, localMac, r, remoteMac) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      if (WRITE_EN_G) then

         axiSlaveRegister(axilEp, x"80", 0, v.etherType);
         axiSlaveRegister(axilEp, x"80", 16, v.loopback);
         axiSlaveRegister(axilEp, x"80", 20, v.rxPolarity);
         axiSlaveRegister(axilEp, x"80", 24, v.txPolarity);

         axiSlaveRegister(axilEp, x"84", 0, v.txDiffCtrl(0));
         axiSlaveRegister(axilEp, x"84", 8, v.txDiffCtrl(1));
         axiSlaveRegister(axilEp, x"84", 16, v.txDiffCtrl(2));
         axiSlaveRegister(axilEp, x"84", 24, v.txDiffCtrl(3));

         axiSlaveRegister(axilEp, x"88", 0, v.txPreCursor(0));
         axiSlaveRegister(axilEp, x"88", 8, v.txPreCursor(1));
         axiSlaveRegister(axilEp, x"88", 16, v.txPreCursor(2));
         axiSlaveRegister(axilEp, x"88", 24, v.txPreCursor(3));

         axiSlaveRegister(axilEp, x"8C", 0, v.txPostCursor(0));
         axiSlaveRegister(axilEp, x"8C", 8, v.txPostCursor(1));
         axiSlaveRegister(axilEp, x"8C", 16, v.txPostCursor(2));
         axiSlaveRegister(axilEp, x"8C", 24, v.txPostCursor(3));

      else
         axiSlaveRegisterR(axilEp, x"80", 0, r.etherType);
         axiSlaveRegisterR(axilEp, x"80", 16, r.loopback);
         axiSlaveRegisterR(axilEp, x"80", 20, r.rxPolarity);
         axiSlaveRegisterR(axilEp, x"80", 24, r.txPolarity);

         axiSlaveRegisterR(axilEp, x"84", 0, r.txDiffCtrl(0));
         axiSlaveRegisterR(axilEp, x"84", 8, r.txDiffCtrl(1));
         axiSlaveRegisterR(axilEp, x"84", 16, r.txDiffCtrl(2));
         axiSlaveRegisterR(axilEp, x"84", 24, r.txDiffCtrl(3));

         axiSlaveRegisterR(axilEp, x"88", 0, r.txPreCursor(0));
         axiSlaveRegisterR(axilEp, x"88", 8, r.txPreCursor(1));
         axiSlaveRegisterR(axilEp, x"88", 16, r.txPreCursor(2));
         axiSlaveRegisterR(axilEp, x"88", 24, r.txPreCursor(3));

         axiSlaveRegisterR(axilEp, x"8C", 0, r.txPostCursor(0));
         axiSlaveRegisterR(axilEp, x"8C", 8, r.txPostCursor(1));
         axiSlaveRegisterR(axilEp, x"8C", 16, r.txPostCursor(2));
         axiSlaveRegisterR(axilEp, x"8C", 24, r.txPostCursor(3));

      end if;

      axiSlaveRegisterR(axilEp, x"90", 0, localMac);
      axiSlaveRegisterR(axilEp, x"98", 0, remoteMac);

      axiSlaveRegister(axilEp, x"A0", 0, v.broadcastMac);


      axiSlaveRegister(axilEp, x"F8", 0, v.commMode);
      axiSlaveRegister(axilEp, x"FC", 0, v.cntRst);

      -- Close out the AXI-Lite transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      loopback       <= r.loopback;
      rxPolarity     <= r.rxPolarity;
      txPolarity     <= r.txPolarity;
      txDiffCtrl     <= r.txDiffCtrl;
      txPreCursor    <= r.txPreCursor;
      txPostCursor   <= r.txPostCursor;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_etherType : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         clk     => pgpClk,
         dataIn  => r.etherType,
         dataOut => etherType);

   U_broadcastMac : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => pgpClk,
         dataIn  => r.broadcastMac,
         dataOut => broadcastMac);

   U_nullInterval : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => pgpClk,
         dataIn  => r.pgpTxIn.nullInterval,
         dataOut => syncTxIn.nullInterval);

   U_SyncBits : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 3)
      port map (
         clk        => pgpClk,
         -- Inputs
         dataIn(0)  => r.pgpTxIn.disable,
         dataIn(1)  => r.pgpTxIn.flowCntlDis,
         dataIn(2)  => r.commMode,
         -- Outputs
         dataOut(0) => syncTxIn.disable,
         dataOut(1) => syncTxIn.flowCntlDis,
         dataOut(2) => commMode);

   pgpTxIn.disable      <= locTxIn.disable or syncTxIn.disable;
   pgpTxIn.flowCntlDis  <= locTxIn.flowCntlDis or syncTxIn.flowCntlDis;
   pgpTxIn.nullInterval <= syncTxIn.nullInterval;
   pgpTxIn.opCodeEn     <= locTxIn.opCodeEn;
   pgpTxIn.opCode       <= locTxIn.opCode;
   pgpTxIn.locData      <= locTxIn.locData;
   pgpRxIn.resetRx      <= locRxIn.resetRx;

end rtl;
