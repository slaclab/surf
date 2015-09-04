-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxDecodeBc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-19
-- Last update: 2014-03-26
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This module decodes the BC messages
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AtlasTtcRxPkg.all;

entity AtlasTtcRxDecodeBc is
   generic (
      TPD_G                : time    := 1 ns;
      BYPASS_ERROR_CHECK_G : boolean := false);
   port (
      validIn   : in  sl;
      dataIn    : in  slv(7 downto 0);
      checkIn   : in  slv(4 downto 0);
      bc        : out AtlasTTCRxBcType;
      sBitErrBc : out sl;
      dBitErrBc : out sl;        
      -- Global Signals
      locClk  : in  sl;
      locRst  : in  sl);
end AtlasTtcRxDecodeBc;

architecture rtl of AtlasTtcRxDecodeBc is

   component AtlasTtcRxDecoder5Bits
      port (
         ecc_clk        : in  sl;
         ecc_reset      : in  sl;
         ecc_clken      : in  sl;
         ecc_correct_n  : in  sl;
         ecc_data_in    : in  slv(7 downto 0);
         ecc_data_out   : out slv(7 downto 0);
         ecc_chkbits_in : in  slv(4 downto 0);
         ecc_sbit_err   : out sl;
         ecc_dbit_err   : out sl);
   end component;

   attribute SYN_BLACK_BOX                           : boolean;
   attribute SYN_BLACK_BOX of AtlasTtcRxDecoder5Bits : component is true;

   attribute BLACK_BOX_PAD_PIN                           : string;
   attribute BLACK_BOX_PAD_PIN of AtlasTtcRxDecoder5Bits : component is "ecc_clk,ecc_reset,ecc_clken,ecc_correct_n,ecc_data_in[7:0],ecc_data_out[7:0],ecc_chkbits_in[4:0],ecc_sbit_err,ecc_dbit_err";

   signal validFF0,
      validFF1,
      validDly,
      sBitErr,
      dBitErr : sl;
   signal dataOut,
      dataOutReversed : slv(7 downto 0);

begin

   bc.valid   <= validDly and not(dBitErr);
   bc.cmdData <= dataOut;
   sBitErrBc  <= sBitErr;
   dBitErrBc  <= dBitErr;   

   dataOut <= bitReverse(dataOutReversed);

   AtlasTtcRxDecoder5Bits_Inst : AtlasTtcRxDecoder5Bits
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
   -- Note: bc.valid and locClkEn never '1' at same 
   --       time. (out of phase by 2 locClk cycles) This 
   --       was done on purpose to prevent resetting of 
   --       the counters at the same time as receiving
   --       an level-1 trigger 
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
