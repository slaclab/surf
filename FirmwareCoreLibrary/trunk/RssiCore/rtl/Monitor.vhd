-------------------------------------------------------------------------------
-- Title      : Handels RSSI counters and timeouts.
-------------------------------------------------------------------------------
-- File       : ToutErrHandler.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Calculates and checks the RUDP packet checksum.
--              Checksum for IP/UDP/TCP/RUDP.       
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;

entity ToutErrHandler is
   generic (
      TPD_G          : time     := 1 ns
      -- 
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Connection FSM indicating active connection      
      connActive_i : in  sl;
      
      -- Timeout and counter values
      rssiParam_i  : in  RssiParamType;
      
      -- Flags from Rx module
      rxFlags_i    : in FlagsType;
      
      -- Valid received packet
      rxValid_i      : in sl;
      
      rstHeadSt_i    : in sl;
      dataHeadSt_i   : in sl;
      nullHeadSt_i   : in sl;      

      -- Packet transmission requests
      sndResend_o     : out  sl;
      sndNull_o       : out  sl    
   );
end entity ToutErrHandler;

architecture rtl of ToutErrHandler is

     
   type RegType is record
      retransToutCnt : slv(rssiParam_i.retransTout'range);
      sndResend      : sl;
      
      
   end record RegType;

   constant REG_INIT_C : RegType := (
      retransToutCnt    => (others=>'0'),
      sndResend         => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
     

   
begin

   comb : process (r, rst_i, rxFlags_i, rssiParam_i, rxValid_i, dataHeadSt_i, rstHeadSt_i, nullHeadSt_i, connActive_i) is
      variable v : RegType;
   begin
      v := r;
      
   -- /////////////////////////////////////////////////////////
   ------------------------------------------------------------
   -- Resend timeout
   ------------------------------------------------------------   
   -- /////////////////////////////////////////////////////////
   
      -- Timeout counter
      if (connActive_i = '0' or
          r.sndResend  = '1' or
          (rxValid_i = '1' and rxFlags_i.busy = '1') or
          dataHeadSt_i = '1' or
          rstHeadSt_i  = '1' or
          nullHeadSt_i = '1'
      ) then
         v.retransToutCnt := (others=>'0');
      else
         v.retransToutCnt := r.retransToutCnt+1;         
      end if; 
      
      
      -- Resend request SRFF 
      if (r.retransToutCnt >= rssiParam_i.retransTout) then
         v.sndResend := '1';
      elsif (dataHeadSt_i = '1' or 
             rstHeadSt_i  = '1' or 
             nullHeadSt_i = '1'
      ) then
         v.sndResend := '0';  
      end if;     
      
      
      
      if (rst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      -----------------------------------------------------------
   end process comb;

   seq : process (clk_i) is
   begin
      if (rising_edge(clk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   ---------------------------------------------------------------------
   sndResend_o <= r.sndResend;
   ---------------------------------------------------------------------
end architecture rtl;