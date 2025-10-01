-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTY Ultrascale+ IP core Wrapper
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

entity Pgp4GtyUsIpFecWrapper is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      -- TX Interface
      txClk            : in  sl;
      txRst            : in  sl;
      txHeaderIn       : in  slv(1 downto 0);
      txDataIn         : in  slv(63 downto 0);
      txHeaderOut      : out slv(1 downto 0);
      txDataOut        : out slv(63 downto 0);
      -- TX Control
      txBypassFec      : in  sl;
      -- RX Interface
      rxClk            : in  sl;
      rxRst            : in  sl;
      rxHeaderIn       : in  slv(1 downto 0);
      rxDataIn         : in  slv(63 downto 0);
      rxDataValidIn    : in  sl;
      rxHeaderValidIn  : in  sl;
      rxGearboxSlipIn  : in  sl;
      rxHeaderOut      : out slv(1 downto 0);
      rxDataOut        : out slv(63 downto 0);
      rxDataValidOut   : out sl;
      rxHeaderValidOut : out sl;
      rxGearboxSlipOut : out sl;
      -- RX Control/Status
      rxBypassFec      : in  sl;
      rxFecInjErr      : in  sl;
      rxFecLock        : out sl;
      rxFecCorInc      : out sl;
      rxFecUnCorInc    : out sl);
end entity Pgp4GtyUsIpFecWrapper;

architecture mapping of Pgp4GtyUsIpFecWrapper is

   component Pgp4GtyUsIpFec
      port (
         tx_clk                 : in  std_logic;
         tx_reset               : in  std_logic;
         rx_clk                 : in  std_logic;
         rx_reset               : in  std_logic;
         tx_din                 : in  std_logic_vector(65 downto 0);
         tx_din_start           : in  std_logic;
         tx_dout                : out std_logic_vector(65 downto 0);
         tx_dout_start          : out std_logic;
         rx_din                 : in  std_logic_vector(65 downto 0);
         rx_din_slip            : out std_logic;
         rx_dout                : out std_logic_vector(65 downto 0);
         rx_dout_start          : out std_logic;
         ctrl_rx_header_mark    : in  std_logic_vector(31 downto 0);
         ctrl_rx_indication_en  : in  std_logic;
         stat_rx_aligned        : out std_logic;
         stat_rx_cw_uncorrected : out std_logic;
         stat_rx_cw_corrected   : out std_logic;
         stat_rx_cw_inc         : out std_logic
         );
   end component;

   type TxRegType is record
      fecTxPcsData : slv(65 downto 0);
      txDataOut    : slv(63 downto 0);
      txHeaderOut  : slv(1 downto 0);
   end record TxRegType;

   constant TX_REG_INIT_C : TxRegType := (
      fecTxPcsData => (others => '0'),
      txDataOut    => (others => '0'),
      txHeaderOut  => (others => '0'));

   signal txR   : TxRegType := TX_REG_INIT_C;
   signal txRin : TxRegType;

   type RxRegType is record
      fecRxSerdesData  : slv(65 downto 0);
      rxFecLock        : sl;
      rxDataValidOut   : sl;
      rxHeaderValidOut : sl;
      rxGearboxSlipOut : sl;
      rxDataOut        : slv(63 downto 0);
      rxHeaderOut      : slv(1 downto 0);
   end record RxRegType;

   constant RX_REG_INIT_C : RxRegType := (
      fecRxSerdesData  => (others => '0'),
      rxFecLock        => '0',
      rxDataValidOut   => '0',
      rxHeaderValidOut => '0',
      rxGearboxSlipOut => '0',
      rxDataOut        => (others => '0'),
      rxHeaderOut      => (others => '0'));

   signal rxR   : RxRegType := RX_REG_INIT_C;
   signal rxRin : RxRegType;

   signal fecTxPcsData : slv(65 downto 0);
   signal fecRxPcsData : slv(65 downto 0);

   signal fecTxSerdesData : slv(65 downto 0);
   signal fecRxSerdesData : slv(65 downto 0);

   signal rxAligned : sl;
   signal rxFecSlip : sl;

begin

   U_FEC : Pgp4GtyUsIpFec
      port map (
         -- Clocks and resets
         tx_clk                 => txClk,
         tx_reset               => txRst,
         rx_clk                 => rxClk,
         rx_reset               => rxRst,
         -- PCS Interface Data
         tx_din                 => fecTxPcsData,
         tx_din_start           => '0',  -- The use of the tx_din_start port is optional. If this port is not used (tied Low)
         rx_dout                => fecRxPcsData,
         rx_dout_start          => open,
         -- PMA Interface Data
         tx_dout                => fecTxSerdesData,
         tx_dout_start          => open,
         rx_din                 => fecRxSerdesData,
         rx_din_slip            => rxFecSlip,
         -- Control Interface - The ctrl_rx_indication_en and ctrl_rx_header_mark[31:0] signals can be tied to all-zero if not required.
         ctrl_rx_header_mark    => x"0000_0000",
         ctrl_rx_indication_en  => '0',
         -- Status Interface
         stat_rx_aligned        => rxAligned,
         stat_rx_cw_corrected   => rxFecCorInc,
         stat_rx_cw_uncorrected => rxFecUnCorInc,
         stat_rx_cw_inc         => open);

   txComb : process (fecTxSerdesData, txBypassFec, txDataIn, txHeaderIn, txR,
                     txRst) is
      variable v : TxRegType;

   begin
      -- Latch the current value
      v := txR;

      -- Register and remap PCS stream
      v.fecTxPcsData(65 downto 2) := txDataIn;
      v.fecTxPcsData(1 downto 0)  := txHeaderIn;

      -- Register and remap SERDES stream
      if (txBypassFec = '0') then
         v.txDataOut   := fecTxSerdesData(65 downto 2);
         v.txHeaderOut := fecTxSerdesData(1 downto 0);
      else
         -- Bypass FEC mode
         v.txDataOut   := txDataIn;
         v.txHeaderOut := txHeaderIn;
      end if;

      -- Outputs
      fecTxPcsData <= txR.fecTxPcsData;
      txDataOut    <= txR.txDataOut;
      txHeaderOut  <= txR.txHeaderOut;

      -- Reset
      if (RST_ASYNC_G = false and txRst = '1') then
         v := TX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      txRin <= v;

   end process txComb;

   txSeq : process (txClk, txRst) is
   begin
      if (RST_ASYNC_G) and (txRst = '1') then
         txR <= TX_REG_INIT_C after TPD_G;
      elsif rising_edge(txClk) then
         txR <= txRin after TPD_G;
      end if;
   end process txSeq;

   rxComb : process (fecRxPcsData, rxAligned, rxBypassFec, rxDataIn,
                     rxDataValidIn, rxFecInjErr, rxFecSlip, rxGearboxSlipIn,
                     rxHeaderIn, rxHeaderValidIn, rxR, rxRst) is
      variable v : RxRegType;

   begin
      -- Latch the current value
      v := rxR;

      -- Register and remap SERDES stream
      v.fecRxSerdesData(65 downto 2) := rxDataIn;
      v.fecRxSerdesData(1 downto 0)  := rxHeaderIn;

      -- Check if need are injecting a bit error
      if (rxFecInjErr = '1') then
         v.fecRxSerdesData(0) := not(v.fecRxSerdesData(0));
      end if;

      -- Register and remap PCS stream
      v.rxFecLock := rxAligned;
      if (rxBypassFec = '0') then
         v.rxDataOut        := fecRxPcsData(65 downto 2);
         v.rxHeaderOut      := fecRxPcsData(1 downto 0);
         v.rxGearboxSlipOut := rxFecSlip;
         v.rxDataValidOut   := rxAligned;
         v.rxHeaderValidOut := rxAligned;
      else
         -- Bypass FEC mode
         v.rxDataOut        := rxDataIn;
         v.rxHeaderOut      := rxHeaderIn;
         v.rxGearboxSlipOut := rxGearboxSlipIn;
         v.rxDataValidOut   := rxDataValidIn;
         v.rxHeaderValidOut := rxHeaderValidIn;
      end if;

      -- Outputs
      fecRxSerdesData  <= rxR.fecRxSerdesData;
      rxFecLock        <= rxR.rxFecLock;
      rxDataOut        <= rxR.rxDataOut;
      rxHeaderOut      <= rxR.rxHeaderOut;
      rxGearboxSlipOut <= rxR.rxGearboxSlipOut;
      rxDataValidOut   <= rxR.rxDataValidOut;
      rxHeaderValidOut <= rxR.rxHeaderValidOut;

      -- Reset
      if (RST_ASYNC_G = false and rxRst = '1') then
         v := RX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rxRin <= v;

   end process rxComb;

   rxSeq : process (rxClk, rxRst) is
   begin
      if (RST_ASYNC_G) and (rxRst = '1') then
         rxR <= RX_REG_INIT_C after TPD_G;
      elsif rising_edge(rxClk) then
         rxR <= rxRin after TPD_G;
      end if;
   end process rxSeq;

end architecture mapping;
