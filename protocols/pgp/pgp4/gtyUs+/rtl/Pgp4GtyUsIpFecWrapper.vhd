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
      txClk         : in  sl;
      txRstL        : in  sl;
      txFecCw       : in  sl;
      txHeaderIn    : in  slv(1 downto 0);
      txDataIn      : in  slv(63 downto 0);
      txHeaderOut   : out slv(1 downto 0);
      txDataOut     : out slv(63 downto 0);
      txFecInjErr   : in  sl;
      txFecLock     : out sl;
      -- RX Interface
      rxClk         : in  sl;
      rxRstL        : in  sl;
      rxFecCw       : out sl;
      rxHeaderIn    : in  slv(1 downto 0);
      rxDataIn      : in  slv(63 downto 0);
      rxHeaderOut   : out slv(1 downto 0);
      rxDataOut     : out slv(63 downto 0);
      rxFecLock     : out sl;
      rxFecCorInc   : out sl;
      rxFecUnCorInc : out sl;
      rxFecCwInc    : out sl;
      rxFecErrCnt   : out slv(2 downto 0));
end entity Pgp4GtyUsIpFecWrapper;

architecture mapping of Pgp4GtyUsIpFecWrapper is

   component Pgp4GtyUsIpFec
      port (
         tx_clk                           : in  std_logic;
         tx_resetn                        : in  std_logic;
         rx_clk                           : in  std_logic;
         rx_resetn                        : in  std_logic;
         consortium_25g                   : in  std_logic;
         tx_pcs_data                      : in  std_logic_vector(65 downto 0);
         rx_pcs_data                      : out std_logic_vector(65 downto 0);
         rx_serdes_data                   : in  std_logic_vector(65 downto 0);
         tx_serdes_data                   : out std_logic_vector(65 downto 0);
         tx_cwm_flag                      : in  std_logic;
         rx_cwm_flag                      : out std_logic;
         fec_bypass_correction_enable     : in  std_logic;
         fec_bypass_indication_enable     : in  std_logic;
         fec_enable                       : in  std_logic;
         fec_ieee_error_indication_enable : in  std_logic;
         rx_hi_ser                        : out std_logic;
         rx_corrected_cw_inc              : out std_logic;
         rx_uncorrected_cw_inc            : out std_logic;
         rx_cw_inc                        : out std_logic;
         rx_symbol_error_count_inc        : out std_logic_vector(2 downto 0);
         tx_align_status                  : out std_logic;
         rx_align_status                  : out std_logic;
         rx_ts_1588_in                    : in  std_logic_vector(79 downto 0);
         rx_ts_1588_out                   : out std_logic_vector(79 downto 0)
         );
   end component;

   type TxRegType is record
      fecTxCw      : sl;
      fecTxPcsData : slv(65 downto 0);
      txDataOut    : slv(63 downto 0);
      txHeaderOut  : slv(1 downto 0);
   end record TxRegType;

   constant TX_REG_INIT_C : TxRegType := (
      fecTxCw      => '0',
      fecTxPcsData => (others => '0'),
      txDataOut    => (others => '0'),
      txHeaderOut  => (others => '0'));

   signal txR   : TxRegType := TX_REG_INIT_C;
   signal txRin : TxRegType;

   type RxRegType is record
      fecRxSerdesData : slv(65 downto 0);
      rxFecCw         : sl;
      rxFecLock       : sl;
      rxDataOut       : slv(63 downto 0);
      rxHeaderOut     : slv(1 downto 0);
   end record RxRegType;

   constant RX_REG_INIT_C : RxRegType := (
      fecRxSerdesData => (others => '0'),
      rxFecCw         => '0',
      rxFecLock       => '0',
      rxDataOut       => (others => '0'),
      rxHeaderOut     => (others => '0'));

   signal rxR   : RxRegType := RX_REG_INIT_C;
   signal rxRin : RxRegType;

   signal fecTxPcsData : slv(65 downto 0);
   signal fecRxPcsData : slv(65 downto 0);

   signal fecTxSerdesData : slv(65 downto 0);
   signal fecRxSerdesData : slv(65 downto 0);

   signal fecTxCw : sl;
   signal fecRxCw : sl;

   signal rxAligned : sl;

begin

   U_FEC : Pgp4GtyUsIpFec
      port map (
         -- Clocks and resets
         tx_clk                           => txClk,
         tx_resetn                        => txRstL,
         rx_clk                           => rxClk,
         rx_resetn                        => rxRstL,
         -- PCS Interface Data
         tx_pcs_data                      => fecTxPcsData,
         rx_pcs_data                      => fecRxPcsData,
         -- PMA Interface Data
         tx_serdes_data                   => fecTxSerdesData,
         rx_serdes_data                   => fecRxSerdesData,
         -- Broadside control and status bus
         fec_bypass_correction_enable     => '1',
         fec_bypass_indication_enable     => '0',
         fec_enable                       => '1',
         fec_ieee_error_indication_enable => '0',
         consortium_25g                   => '0',
         -- hi_ser
         rx_hi_ser                        => open,
         -- alignment status
         tx_align_status                  => txFecLock,
         rx_align_status                  => rxAligned,
         -- correction flags
         rx_corrected_cw_inc              => rxFecCorInc,
         rx_uncorrected_cw_inc            => rxFecUnCorInc,
         rx_cw_inc                        => rxFecCwInc,
         rx_symbol_error_count_inc        => rxFecErrCnt,  -- TODO: Add this to status monitoring
         -- alginment flags to and from the XXVMAC
         tx_cwm_flag                      => fecTxCw,
         rx_cwm_flag                      => fecRxCw,
         rx_ts_1588_in                    => x"00000000000000000000",
         rx_ts_1588_out                   => open);

   txComb : process (fecTxSerdesData, txDataIn, txFecCw, txFecInjErr,
                     txHeaderIn, txR, txRstL) is
      variable v : TxRegType;

   begin
      -- Latch the current value
      v := txR;

      -- Register and remap PCS stream
      v.fecTxCw                   := txFecCw;
      v.fecTxPcsData(65 downto 2) := txDataIn;
      v.fecTxPcsData(1 downto 0)  := bitReverse(txHeaderIn);

      -- Register and remap SERDES stream
      v.txDataOut   := bitReverse(fecTxSerdesData(65 downto 2));
      v.txHeaderOut := bitReverse(fecTxSerdesData(1 downto 0));

      -- Check if need are injecting a bit error
      if (txFecInjErr = '1') then
         v.txHeaderOut(0) := not(v.txHeaderOut(0));
      end if;

      -- Outputs
      fecTxCw      <= txR.fecTxCw;
      fecTxPcsData <= txR.fecTxPcsData;
      txDataOut    <= txR.txDataOut;
      txHeaderOut  <= txR.txHeaderOut;

      -- Reset
      if (RST_ASYNC_G = false and txRstL = '0') then
         v := TX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      txRin <= v;

   end process txComb;

   txSeq : process (txClk, txRstL) is
   begin
      if (RST_ASYNC_G) and (txRstL = '0') then
         txR <= TX_REG_INIT_C after TPD_G;
      elsif rising_edge(txClk) then
         txR <= txRin after TPD_G;
      end if;
   end process txSeq;

   rxComb : process (fecRxCw, fecRxPcsData, rxAligned, rxDataIn, rxHeaderIn,
                     rxR, rxRstL) is
      variable v : RxRegType;

   begin
      -- Latch the current value
      v := rxR;

      -- Register and remap SERDES stream
      v.fecRxSerdesData(65 downto 2) := bitReverse(rxDataIn);
      v.fecRxSerdesData(1 downto 0)  := bitReverse(rxHeaderIn);

      -- Register and remap PCS stream
      v.rxFecCw   := fecRxCw;
      v.rxFecLock := rxAligned;
      v.rxDataOut := fecRxPcsData(65 downto 2);
      if (rxAligned = '1') then
         v.rxHeaderOut := bitReverse(fecRxPcsData(1 downto 0));
      else
         -- Force PgpRxGearboxAligner to send slips when FEC is not locked
         v.rxHeaderOut := "00";
      end if;

      -- Outputs
      fecRxSerdesData <= rxR.fecRxSerdesData;
      rxFecCw         <= rxR.rxFecCw;
      rxFecLock       <= rxR.rxFecLock;
      rxDataOut       <= rxR.rxDataOut;
      rxHeaderOut     <= rxR.rxHeaderOut;

      -- Reset
      if (RST_ASYNC_G = false and rxRstL = '0') then
         v := RX_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rxRin <= v;

   end process rxComb;

   rxSeq : process (rxClk, rxRstL) is
   begin
      if (RST_ASYNC_G) and (rxRstL = '0') then
         rxR <= RX_REG_INIT_C after TPD_G;
      elsif rising_edge(rxClk) then
         rxR <= rxRin after TPD_G;
      end if;
   end process rxSeq;

end architecture mapping;
