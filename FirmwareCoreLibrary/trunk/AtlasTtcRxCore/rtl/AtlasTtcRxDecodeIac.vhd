-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxDecodeIac.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-19
-- Last update: 2014-03-26
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module decodes the IAC messages
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

entity AtlasTtcRxDecodeIac is
   generic (
      TPD_G                : time    := 1 ns;
      BYPASS_ERROR_CHECK_G : boolean := false);
   port (
      validIn    : in  sl;
      dataIn     : in  slv(31 downto 0);
      checkIn    : in  slv(6 downto 0);
      iac        : out AtlasTTCRxIacType;
      sBitErrIac : out sl;
      dBitErrIac : out sl;      
      -- Global Signals
      locClk  : in  sl;
      locRst  : in  sl);
end AtlasTtcRxDecodeIac;

architecture rtl of AtlasTtcRxDecodeIac is

   component AtlasTtcRxDecoder7Bits
      port (
         ecc_clk        : in  sl;
         ecc_reset      : in  sl;
         ecc_clken      : in  sl;
         ecc_correct_n  : in  sl;
         ecc_data_in    : in  slv(31 downto 0);
         ecc_data_out   : out slv(31 downto 0);
         ecc_chkbits_in : in  slv(6 downto 0);
         ecc_sbit_err   : out sl;
         ecc_dbit_err   : out sl);
   end component;

   attribute SYN_BLACK_BOX                           : boolean;
   attribute SYN_BLACK_BOX of AtlasTtcRxDecoder7Bits : component is true;

   attribute BLACK_BOX_PAD_PIN                           : string;
   attribute BLACK_BOX_PAD_PIN of AtlasTtcRxDecoder7Bits : component is "ecc_clk,ecc_reset,ecc_clken,ecc_correct_n,ecc_data_in[31:0],ecc_data_out[31:0],ecc_chkbits_in[6:0],ecc_sbit_err,ecc_dbit_err";

   signal validFF0,
      validFF1,
      validDly,
      sBitErr,
      dBitErr : sl := '0';
   signal dataOut,
      dataOutReversed : slv(31 downto 0);

begin

   iac.valid    <= validDly and not(dBitErr);
   iac.addr     <= dataOut(31 downto 18);
   iac.bitE     <= dataOut(17);
   iac.reserved <= dataOut(16);
   iac.subAddr  <= dataOut(15 downto 8);
   iac.data     <= dataOut(7 downto 0);
   sBitErrIac   <= sBitErr;
   dBitErrIac   <= dBitErr;

   dataOut <= bitReverse(dataOutReversed);

   AtlasTtcRxDecoder7Bits_Inst : AtlasTtcRxDecoder7Bits
      port map (
         ecc_correct_n  => ite(BYPASS_ERROR_CHECK_G, '1', '0'),
         ecc_clken      => '1',
         ecc_data_in    => bitReverse(dataIn),
         ecc_chkbits_in => bitReverse(checkIn),
         ecc_data_out   => dataOutReversed,
         ecc_sbit_err   => sBitErr,
         ecc_dbit_err   => dBitErr,
         -- Global Signals
         ecc_clk        => locClk,
         ecc_reset      => locRst);
         
   -----------------------------------------------------
   -- Note: iac.valid and locClkEn never '1' at same 
   --       time. (out of phase by 2 locClk cycles)
   -----------------------------------------------------          
   process(locClk)
   begin
      if rising_edge(locClk) then
         if locRst = '1' then
            validFF0 <= '0' after TPD_G;
            validFF1 <= '0' after TPD_G;
            validDly <= '0' after TPD_G;
         else
            validFF0 <= validIn  after TPD_G;
            validFF1 <= validFF0 after TPD_G;
            validDly <= validFF1 after TPD_G;
         end if;
      end if;
   end process; 
   
end rtl;
