-------------------------------------------------------------------------------
-- Title      : Decodes header values 
-------------------------------------------------------------------------------
-- File       : HeaderReg.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Combines and decodes the header values
--    TODO Remove the commented out EACK stuff if argument accepted                 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.RssiPkg.all;
use ieee.math_real.all;

entity HeaderReg is
   generic (
      TPD_G        : time     := 1 ns;
      
      --MAX_OUT_OF_SEQUENCE_G : natural := 16;

      SYN_HEADER_SIZE_G  : natural := 24;
      ACK_HEADER_SIZE_G  : natural := 8;
      EACK_HEADER_SIZE_G : natural := 8;
      RST_HEADER_SIZE_G  : natural := 8;
      NULL_HEADER_SIZE_G : natural := 8;
      DATA_HEADER_SIZE_G : natural := 8    
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl;
      
      -- Header control inputs (must hold values while reading header)
      synHeadSt_i  : in  sl;
      rstHeadSt_i  : in  sl;
      dataHeadSt_i : in  sl;
      nullHeadSt_i : in  sl;
      ackHeadSt_i  : in  sl;
      --eackHeadSt_i : in  sl;
        
      -- Ack sequence number valid
      ack_i : in sl;
      
      -- Header values 
      txSeqN_i : in slv(7  downto 0); -- Sequence number of the current packet
      rxAckN_i : in slv(7  downto 0); -- Acknowledgment number of the recived packet handelled by receiver 

      -- Negotiated or from GENERICS
      headerValues_i : in  headerValuesType;
      
      -- Out of order sequence numbers from received EACK packet
      --eackSeqnArr_i  : in Slv16Array(0 to integer(ceil(real(MAX_OUT_OF_SEQUENCE_G)/2.0))-1);
      --eackN_i        : in natural;

      addr_i        : in  slv(7  downto 0);
      headerData_o  : out slv( (RSSI_WORD_WIDTH_C * 8)-1 downto 0)
   );
end entity HeaderReg;

architecture rtl of HeaderReg is
  
   signal addrInt : integer;
   
begin
   
   -- Convert address to integer
   addrInt <= conv_integer(addr_i);
   
   -- Note! Only combinatorial logic 
   comb : process (rst_i, headerValues_i, addrInt, txSeqN_i, rxAckN_i, 
                   synHeadSt_i, rstHeadSt_i, dataHeadSt_i, nullHeadSt_i, ackHeadSt_i, ack_i ) is
      
      variable vHeaderData : slv(RSSI_WORD_WIDTH_C*8-1 downto 0);
   begin   

      -- 
      if (synHeadSt_i = '1') then      
         case addrInt is
            when 16#00# =>
              vHeaderData := "1" & ack_i & "000000" & toSlv(SYN_HEADER_SIZE_G, 8) &
                              txSeqN_i & rxAckN_i                                 &
                              x"1" & x"0" & headerValues_i.maxOutsSegments        &       
                              x"00" & x"00";
            when 16#01# =>
              vHeaderData :=  headerValues_i.maxSegSize   &
                              headerValues_i.retransTout  &
                              headerValues_i.cumulAckTout &    
                              headerValues_i.nullSegTout;
            when 16#02# =>
              vHeaderData :=  headerValues_i.maxRetrans & headerValues_i.maxCumAck  &
                              headerValues_i.maxOutofseq & headerValues_i.maxAutoRst&           
                              headerValues_i.connectionId(15 downto 0)              &
                              x"00" & x"00"; -- Place for checksum
            when others =>
              vHeaderData := (others=> '0');                              
         end case;
      elsif (rstHeadSt_i = '1') then 
         case addrInt is
            when 16#00# =>
              vHeaderData := "00010000" & toSlv(RST_HEADER_SIZE_G, 8) &
                             txSeqN_i & rxAckN_i                      &
                             x"00" & x"00"                            &  -- Reserved
                             x"00" & x"00";                              -- Place for checksum
            when others =>
              vHeaderData := (others=> '0');
         end case;
      elsif (dataHeadSt_i = '1' or ackHeadSt_i = '1') then 
         case addrInt is
            when 16#00# =>
              vHeaderData := "01000000" & toSlv(DATA_HEADER_SIZE_G, 8) &
                             txSeqN_i & rxAckN_i                       &
                             x"00" & x"00"                             &  -- Reserved
                             x"00" & x"00";                               -- Place for checksum
            when others =>
              vHeaderData := (others=> '0');    
         end case;
      elsif (nullHeadSt_i = '1') then
         case addrInt is
            when 16#00# =>
              vHeaderData :=  "01001000" & toSlv(NULL_HEADER_SIZE_G, 8) &
                              txSeqN_i & rxAckN_i                       &
                              x"00" & x"00"                             &  -- Reserved
                              x"00" & x"00";                               -- Place for checksum
            when others =>
              vHeaderData := (others=> '0');   
         end case;
     -- elsif (eackHeadSt_i = '1') then
     --    case addrInt is
     --       when 16#00# =>
     --         vHeaderData := "01100000" & toSlv(EACK_HEADER_SIZE_G+r.eackN, 8);
     --       when 16#01# =>
     --         vHeaderData := txSeqN_i & rxAckN_i;
     --       when 16#02# to (2+MAX_OUT_OF_ORDER_G-1) =>
     --         vHeaderData := r.eackSeqnArr(addrInt-2);
     --       when others =>
     --         vHeaderData := (others=> '0');
     --    end case;
      else
         vHeaderData := (others=> '0');
      end if;
      
      headerData_o <= vHeaderData;
      -----------------------------------------------------------
   end process comb;

   ---------------------------------------------------------------------
   -- Output assignment

   ---------------------------------------------------------------------
end architecture rtl;