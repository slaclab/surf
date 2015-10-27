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

      SYN_HEADER_SIZE_G  : natural := 28;
      ACK_HEADER_SIZE_G  : natural := 6;
      EACK_HEADER_SIZE_G : natural := 6;      
      RST_HEADER_SIZE_G  : natural := 6;      
      NULL_HEADER_SIZE_G : natural := 6;
      DATA_HEADER_SIZE_G : natural := 6
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

      -- Register input header values on strobe
      -- (DFF if unconnected)
      strobe_i : in sl :='1';
         
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
      headerData_o  : out slv(15 downto 0)
   );
end entity HeaderReg;

architecture rtl of HeaderReg is
  
   type RegType is record
      txSeqN      : slv(7  downto 0);
      rxAckN      : slv(7  downto 0);
      --eackSeqnArr : Slv16Array(eackSeqnArr_i'range);
      ack         : sl;
     -- eackN       : natural;
   end record RegType;

   constant REG_INIT_C : RegType := (
      txSeqN      => (others =>'0'),
      rxAckN      => (others =>'0'),
      --eackSeqnArr => (others => x"0000"),
      ack         => '0'
     -- eackN       => 0
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal addrInt : integer;
   
begin
   
   -- Convert address to integer
   addrInt <= conv_integer(addr_i);
   
   -- 
   comb : process (r, rst_i, headerValues_i, strobe_i, addrInt, txSeqN_i, rxAckN_i, 
                   synHeadSt_i, rstHeadSt_i, dataHeadSt_i, nullHeadSt_i, ackHeadSt_i, ack_i ) is
      
      variable v : RegType;
      variable vHeaderData : slv(15 downto 0);
   begin
      v := r;
      
      if strobe_i = '1' then
         -- Register inputs         
         v.txSeqN      := txSeqN_i;
         v.rxAckN      := rxAckN_i;
         --v.eackSeqnArr := eackSeqnArr_i;
        -- v.eackN       := eackN_i;
         v.ack         := ack_i;
      else
         -- Hold values constant
         v.txSeqN      := r.txSeqN;
         v.rxAckN      := r.rxAckN;
         --v.eackSeqnArr := r.eackSeqnArr;
       --  v.eackN       := r.eackN;
         v.ack         := r.ack;
      end if;         

      -- 
      if (synHeadSt_i = '1') then      
         case addrInt is
            when 16#00# =>
              vHeaderData := "1" & r.ack & "000000" & toSlv(SYN_HEADER_SIZE_G, 8);
            when 16#01# =>
              vHeaderData := r.txSeqN & r.rxAckN;
            when 16#02# => 
              vHeaderData := x"1" & x"0" & headerValues_i.maxOutsSegments;             
            when 16#03# =>
              vHeaderData := x"00" & x"00";
            when 16#04# =>
              vHeaderData := headerValues_i.maxSegSize;
            when 16#05# =>
              vHeaderData := headerValues_i.retransTout; 
            when 16#06# => 
              vHeaderData := headerValues_i.cumulAckTout;             
            when 16#07# =>
              vHeaderData := headerValues_i.nullSegTout;
            when 16#08# =>
              vHeaderData := headerValues_i.transStateTout;
            when 16#09# =>
              vHeaderData := headerValues_i.maxRetrans & headerValues_i.maxCumAck;
            when 16#0A# => 
              vHeaderData := headerValues_i.maxOutofseq & headerValues_i.maxAutoRst;             
            when 16#0B# =>
              vHeaderData := headerValues_i.connectionId(31 downto 16);
            when 16#0C# =>
              vHeaderData := headerValues_i.connectionId(15 downto 0);
            when others =>
              vHeaderData := (others=> '0');           
         end case;
      elsif (rstHeadSt_i = '1') then 
         case addrInt is
            when 16#00# =>
              vHeaderData := "00010000" & toSlv(RST_HEADER_SIZE_G, 8);
            when 16#01# =>
              vHeaderData := r.txSeqN & r.rxAckN;
            when others =>
              vHeaderData := (others=> '0');       
         end case;
      elsif (dataHeadSt_i = '1' or ackHeadSt_i = '1') then 
         case addrInt is
            when 16#00# =>
              vHeaderData := "01000000" & toSlv(DATA_HEADER_SIZE_G, 8);
            when 16#01# =>
              vHeaderData := r.txSeqN & r.rxAckN;
            when others =>
              vHeaderData := (others=> '0');    
         end case;
      elsif (nullHeadSt_i = '1') then
         case addrInt is
            when 16#00# =>
              vHeaderData := "01001000" & toSlv(NULL_HEADER_SIZE_G, 8);
            when 16#01# =>
              vHeaderData := r.txSeqN & r.rxAckN;
            when others =>
              vHeaderData := (others=> '0');       
         end case;
     -- elsif (eackHeadSt_i = '1') then
     --    case addrInt is
     --       when 16#00# =>
     --         vHeaderData := "01100000" & toSlv(EACK_HEADER_SIZE_G+r.eackN, 8);
     --       when 16#01# =>
     --         vHeaderData := r.txSeqN & r.rxAckN;
     --       when 16#02# to (2+MAX_OUT_OF_ORDER_G-1) =>
     --         vHeaderData := r.eackSeqnArr(addrInt-2);
     --       when others =>
     --         vHeaderData := (others=> '0');
     --    end case;
      else
         vHeaderData := (others=> '0'); 
      end if;
           
      if (rst_i = '1') then
         v := REG_INIT_C;
      end if;
      
      headerData_o <= vHeaderData;
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
   -- Output assignment

   ---------------------------------------------------------------------
end architecture rtl;