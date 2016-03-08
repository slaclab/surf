library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

package RssiPkg is

-- Common constant definitions
--------------------------------------------------------------------------
constant RSSI_WORD_WIDTH_C        : positive := 8;     -- 64 bit word (FIXED)
constant RSSI_AXI_CONFIG_C        : AxiStreamConfigType := ssiAxiStreamConfig(RSSI_WORD_WIDTH_C);

-- Header sizes
constant SYN_HEADER_SIZE_C  : natural := 24;
constant ACK_HEADER_SIZE_C  : natural := 8;
constant EACK_HEADER_SIZE_C : natural := 8;
constant RST_HEADER_SIZE_C  : natural := 8;
constant NULL_HEADER_SIZE_C : natural := 8;
constant DATA_HEADER_SIZE_C : natural := 8;
  
-- Sub-types 
-------------------------------------------------------------------------- 
   type RssiParamType is record
      version               :  slv(3  downto 0);
      chksumEn              :  slv(0 downto 0);
      timeoutUnit           :  slv(7 downto 0);
      
      maxOutsSeg            :  slv(7  downto 0); -- Receiver parameter       
      maxSegSize            :  slv(15 downto 0); -- Receiver parameter

      retransTout           :  slv(15 downto 0);
      cumulAckTout          :  slv(15 downto 0);
      nullSegTout           :  slv(15 downto 0);      

      maxRetrans            :  slv(7 downto 0);
      maxCumAck             :  slv(7 downto 0);
      
      maxOutofseq           :  slv(7 downto 0);

      connectionId          :  slv(31 downto 0);
   end record RssiParamType;
   
   type flagsType is record
      syn  : sl;
      ack  : sl;
      eack : sl;
      rst  : sl;
      nul  : sl;
      data : sl;
      busy : sl;
      eofe : sl;
   end record flagsType;

   type WindowType is record
      seqN                  :  slv(7  downto 0);
      segType               :  slv(2  downto 0);
--     eofe                  : sl;
--     strb                  : slv(15 downto 0);
      keep                  : slv(15 downto 0);
--     dest                  : slv(SSI_TDEST_BITS_C-1 downto 0);
      segSize               :  natural;
      occupied              : sl;
   end record WindowType;
   
   constant WINDOW_INIT_C : WindowType := (
      seqN                  => (others => '0'),
      segType               => (others => '0'),
--      eofe                  => '0',
--      strb                  => (others => '1'), 
      keep                  => (others => '1'), 
--      dest                  => (others => '0'), 
      segSize               => 0,
      occupied              => '0'
   );
   
   -- Arrays   
   type WindowTypeArray is array (natural range<>) of WindowType;     

   
-- Function declarations
--------------------------------------------------------------------------  
   -- Swap little and big endians
   -- 64-bit header word
   function endianSwap64(data_slv : slv(63 downto 0)) return std_logic_vector;

 
end RssiPkg;

package body RssiPkg is

-- Function bodies
--------------------------------------------------------------------------  
   -- Swap little or big endians 64-bit header
   function endianSwap64(data_slv : slv(63 downto 0)) return std_logic_vector is
         variable  vSlv: slv(63 downto 0);   
   begin
      vSlv := (others=>'0');
      
      for i in 7 downto 0 loop
          vSlv((8*(7-i))+7  downto  8*(7-i)) := data_slv((8*i)+7  downto  8*i);
      end loop;

      return vSlv;
      
   end endianSwap64;
--------------------------------------------------------------------------------------------
end package body RssiPkg;
