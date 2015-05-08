library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use work.StdRtlPkg.all;

package Jesd204bPkg is

-- Constant definitions

   -- Number of bytes in MGT word (2 or 4).
   constant GT_WORD_SIZE_C : positive := 4;
   
   -- 8B10B characters (8-bit values)
   constant K_CHAR_C : slv(7 downto 0) := x"BC";
   constant R_CHAR_C : slv(7 downto 0) := x"1C";
   constant A_CHAR_C : slv(7 downto 0) := x"7C";   
   constant F_CHAR_C : slv(7 downto 0) := x"FC";
   
   -- Register or counter widths
   constant SYSRF_DLY_WIDTH_C : positive := 5;
   constant RX_STAT_WIDTH_C   : positive := 8 + 2*GT_WORD_SIZE_C;
   constant TX_STAT_WIDTH_C   : positive := 4;
   
   -- AXI packet size at powerup
   constant  AXI_PACKET_SIZE_DEFAULT_C : slv(23 downto 0):=x"00_01_00";

-- Types 
-------------------------------------------------------------------------- 
   type jesdGtRxLaneType is record
      data    : slv((GT_WORD_SIZE_C*8)-1 downto 0);  -- PHY receive data
      dataK   : slv(GT_WORD_SIZE_C-1 downto 0);      -- PHY receive data is K character
      dispErr : slv(GT_WORD_SIZE_C-1 downto 0);      -- PHY receive data has disparity error
      decErr  : slv(GT_WORD_SIZE_C-1 downto 0);      -- PHY receive data not in table
      rstDone : sl;
   end record jesdGtRxLaneType;

   type jesdGtTxLaneType is record
      data    : slv((GT_WORD_SIZE_C*8)-1 downto 0);  -- PHY receive data
      dataK   : slv(GT_WORD_SIZE_C-1 downto 0);      -- PHY receive data is K character
  end record jesdGtTxLaneType;   
   -- Arrays
   type jesdGtRxLaneTypeArray is array (natural range <>) of jesdGtRxLaneType;
   type jesdGtTxLaneTypeArray is array (natural range <>) of jesdGtTxLaneType;
   type AxiDataTypeArray      is array (natural range <>) of slv((GT_WORD_SIZE_C*8)-1 downto 0);
   type rxStatuRegisterArray  is array (natural range <>) of slv( (RX_STAT_WIDTH_C)-1 downto 0);
   type txStatuRegisterArray  is array (natural range <>) of slv( (TX_STAT_WIDTH_C)-1 downto 0);
   type alignTxArray          is array (natural range <>) of slv( (GT_WORD_SIZE_C)-1 downto 0);
   
   

-- Functions
--------------------------------------------------------------------------  
   -- Detect K character
   function detKcharFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic;

   -- Output variable index from SLV (use in variable length shift register) 
   function varIndexOutFunc(shft_slv : slv; index_slv : slv) return std_logic;

   -- Detect position of first non K character
   function detectPosFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector;

   -- Byte swap slv (bytes int 2 or 4)
   function byteSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector;
   
   -- Align the data within the data buffer according to the position of the byte alignment word
   function JesdDataAlign(data_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector; 

   -- Align the character within the buffer according to the position of the byte alignment word
   function JesdCharAlign(char_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector; 

   -- Convert standard logic vector to integer
   function slvToInt(data_slv : slv) return integer;

   -- Convert integer to standard logic vector
   function intToSlv(data_int : positive; bytes_int : positive) return std_logic_vector;
   
   -- Replace alignment characters with data
   function JesdCharReplace(data_slv : slv; char_slv : slv; F_int : positive; bytes_int : positive ; enable_sl : sl) return std_logic_vector;
   
end Jesd204bPkg;

package body Jesd204bPkg is

-- Functions
--------------------------------------------------------------------------  
   -- Detect K character
   function detKcharFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic is
   begin
      if(bytes_int = 2) then
         if(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               charisk_slv = (charisk_slv'range => '1')
               ) then
            return '1';
         else
            return '0';
         end if;
      elsif(bytes_int = 4) then
         if(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) = K_CHAR_C and
               charisk_slv = (charisk_slv'range => '1')
               ) then
            return '1';
         else
            return '0';
         end if;
      else
         return '0';
      end if;
   end detKcharFunc;

   -- Output variable index from SLV (use in variable length shift register) 
   function varIndexOutFunc(shft_slv : slv; index_slv : slv) return std_logic is
      variable i : integer;
   begin
        -- Return the index
        i := to_integer(unsigned(index_slv));
        return shft_slv(i);
        
   end varIndexOutFunc;

   -- Detect position of first non K character
   function detectPosFunc(data_slv : slv; charisk_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      -- GT word is 2 bytes
      if(bytes_int = 2) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C
               ) then
            return "01";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               charisk_slv(0) = '1'
               ) then
            return "10";
         else
            return "11";
         end if;
      -- GT word is 4 bytes wide
      elsif(bytes_int = 4) then
         if(data_slv (7 downto 0) /= K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C
               ) then
            return "0001";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) /= K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(0) = '1'
               ) then
            return "0010";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) /= K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(1 downto 0) = "11"
               ) then
            return "0100";
         elsif(data_slv (7 downto 0) = K_CHAR_C and
               data_slv (15 downto 8) = K_CHAR_C and
               data_slv (23 downto 16) = K_CHAR_C and
               data_slv (31 downto 24) /= K_CHAR_C and
               charisk_slv(2 downto 0) = "111"
               ) then
            return "1000";
         else
            return "1111";
         end if;
      else
         return (bytes_int-1 downto 0 => '1');
      end if;
   end detectPosFunc;

   -- Byte swap slv (bytes int 2 or 4)
   function byteSwapSlv(data_slv : slv; bytes_int : positive) return std_logic_vector is
   begin

      if(bytes_int = 2) then
         return data_slv(7 downto 0) & data_slv(15 downto 8);
      elsif(bytes_int = 4) then
         return data_slv(7 downto 0) & data_slv(15 downto 8) & data_slv(23 downto 16) & data_slv(31 downto 24); 
      else
          return data_slv;
      end if;
   end byteSwapSlv;

   -- Align the data within the data buffer according to the position of the byte alignment word
   function JesdDataAlign(data_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      if(bytes_int = 2) then
         case position_slv(1 downto 0) is
            when "01"   => return data_slv (31 downto 16);
            when "10"   => return data_slv (31-8 downto 16-8);
            when others => return data_slv (31 downto 16);
         end case;
      elsif(bytes_int = 4) then
         case position_slv(3 downto 0) is
            when "0001" => return data_slv(63 downto 32);
            when "0010" => return data_slv(63-1*8 downto 32-1*8);
            when "0100" => return data_slv(63-2*8 downto 32-2*8);
            when "1000" => return data_slv(63-3*8 downto 32-3*8);
            when others => return data_slv(63 downto 32);
         end case; 
      else
          return data_slv;
      end if;
   end JesdDataAlign;

   -- Align the char within the buffer according to the position of the byte alignment word
   function JesdCharAlign(char_slv : slv; position_slv : slv; bytes_int : positive) return std_logic_vector is
   begin
      if(bytes_int = 2) then
         case position_slv(1 downto 0) is
            when "01"   => return char_slv (3   downto 2);
            when "10"   => return char_slv (3-1 downto 2-1);
            when others => return char_slv (3   downto 2);
         end case;
      elsif(bytes_int = 4) then
         case position_slv(3 downto 0) is
            when "0001" => return char_slv(7   downto 4);
            when "0010" => return char_slv(7-1 downto 4-1);
            when "0100" => return char_slv(7-2 downto 4-2);
            when "1000" => return char_slv(7-3 downto 4-3);
            when others => return char_slv(7   downto 4);
         end case; 
      else
          return char_slv;
      end if;
   end JesdCharAlign;  

   -- Convert standard logic vector to integer
   function slvToInt(data_slv : slv) return integer is
   begin
      return to_integer(unsigned(data_slv));
   end slvToInt;

   -- Convert integer to standard logic vector
   function intToSlv(data_int : positive; bytes_int : positive) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned(data_int, bytes_int));
   end IntToSlv;
   
   -- Replace alignment characters with data      
   function JesdCharReplace(data_slv : slv; char_slv : slv; F_int : positive; bytes_int : positive; enable_sl : sl) return std_logic_vector is
         variable  vSlv: slv((bytes_int*8)-1 downto 0);
   begin
         if(enable_sl = '0') then
            vSlv := data_slv((bytes_int*8)-1 downto 0);
         else
            vSlv := data_slv((bytes_int*8)-1 downto 0);
            -- Replace the character in the data with the data value from previous frame
            for I in (bytes_int-1) downto 0 loop
               if ( char_slv(I) = '1' and
                    (data_slv( (I*8+7) downto I*8) = A_CHAR_C or 
                     data_slv( (I*8+7) downto I*8) = F_CHAR_C)
                  ) then
                  vSlv((I*8+7) downto I*8) := data_slv( (I*8+8*F_int)+7 downto (I*8 + 8*F_int));    
               end if;
            end loop;
         end if;
         
         return vSlv((bytes_int*8)-1 downto 0);        

   end  JesdCharReplace;
--------------------------------------------------------------------------------------------
end package body Jesd204bPkg;
