-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEncoder7BitsWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-05
-- Last update: 2014-06-05
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity AtlasTtcTxEncoder7BitsWrapper is
   generic (
      TPD_G : time := 1 ns);      
   port (
      dataIn   : in  slv(31 downto 0);
      dataOut  : out slv(31 downto 0);
      checkOut : out slv(6 downto 0));
end AtlasTtcTxEncoder7BitsWrapper;

architecture rtl of AtlasTtcTxEncoder7BitsWrapper is

   component AtlasTtcTxEncoder7Bits
      port (
         ecc_data_in     : in  slv(31 downto 0);
         ecc_data_out    : out slv(31 downto 0);
         ecc_chkbits_out : out slv(6 downto 0));
   end component;

   attribute SYN_BLACK_BOX                               : boolean;
   attribute SYN_BLACK_BOX of AtlasTtcTxEncoder7Bits     : component is true;
   
   attribute BLACK_BOX_PAD_PIN                           : string;
   ATTRIBUTE BLACK_BOX_PAD_PIN OF AtlasTtcTxEncoder7Bits : COMPONENT IS "ecc_data_in[31:0],ecc_data_out[31:0],ecc_chkbits_out[6:0]";

   signal dataOutReversed    : slv(31 downto 0);
   signal checkOutReversed : slv(6 downto 0);
   
begin
   
   dataOut  <= bitReverse(dataOutReversed);
   checkOut <= bitReverse(checkOutReversed);

   AtlasTtcTxEncoder7Bits_Inst : AtlasTtcTxEncoder7Bits
      port map (
         ecc_data_in     => bitReverse(dataIn),
         ecc_data_out    => dataOutReversed,
         ecc_chkbits_out => checkOutReversed);

end rtl;
