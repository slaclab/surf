library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.SsiPkg.all;
use work.AxiStreamPkg.all;

package RssiPkg is

-- Common constant definitions
--------------------------------------------------------------------------
constant SEGMENT_ADDR_SIZE_C      : positive := 7;     -- 2^SEGMENT_ADDR_SIZE_C = Number of 64 bit wide data words
constant RSSI_WORD_WIDTH_C        : positive := 8;     -- 64 bit word (FIXED)
constant RSSI_AXI_CONFIG_C        : AxiStreamConfigType := ssiAxiStreamConfig(RSSI_WORD_WIDTH_C);  

-- Sub-types 
-------------------------------------------------------------------------- 
   type RssiParamType is record
      version               :  slv(3  downto 0);
      
      maxOutsSeg            :  slv(7  downto 0); -- Receiver parameter       
      maxSegSize            :  slv(15 downto 0); -- Receiver parameter

      retransTout           :  slv(15 downto 0);
      cumulAckTout          :  slv(15 downto 0);
      nullSegTout           :  slv(15 downto 0);      
      transStateTout        :  slv(15 downto 0);

      maxRetrans            :  slv(7 downto 0);
      maxCumAck             :  slv(7 downto 0);
      
      maxOutofseq           :  slv(7 downto 0);
      maxAutoRst            :  slv(7 downto 0);

      connectionId          :  slv(15 downto 0);
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
   

   type TxWindowType is record
      seqN                  :  slv(7  downto 0);
      segType               :  slv(2  downto 0);
      
      -- SSI
      --eacked                :  sl;
      eofe                  : sl;
      strb                  : slv(15 downto 0);
      keep                  : slv(15 downto 0);
      dest                  : slv(SSI_TDEST_BITS_C-1 downto 0);
      
      segSize               :  slv(SEGMENT_ADDR_SIZE_C-1 downto 0);
      occupied              : sl;
   end record TxWindowType;
   
   constant TX_WINDOW_INIT_C : TxWindowType := (
      seqN                  => (others => '0'),
      segType               => (others => '0'),
 
      eofe                  => '0',
      strb                  => (others => '1'), 
      keep                  => (others => '1'), 
      dest                  => (others => '0'), 
      segSize               => (others => '0'),
      occupied              => '0'
   );
   
   type RxWindowType is record
      seqN                  :  slv(7  downto 0);
      segType               :  slv(2  downto 0);
      
      -- SSI
      --eacked                :  sl;
      eofe                  : sl;
      strb                  : slv(15 downto 0);
      keep                  : slv(15 downto 0);
      dest                  : slv(SSI_TDEST_BITS_C-1 downto 0);
      
      segSize               : slv(SEGMENT_ADDR_SIZE_C-1 downto 0);
      occupied              : sl;
   end record RxWindowType;
   
   constant RX_WINDOW_INIT_C : RxWindowType := (
      seqN                  => (others => '0'),
      segType               => (others => '0'),
 
      eofe                  => '0',
      strb                  => (others => '1'), 
      keep                  => (others => '1'), 
      dest                  => (others => '0'), 
      segSize               => (others => '0'),
      occupied              => '0'
   ); 

   type TxWindowTypeArray is array (natural range<>) of TxWindowType;
   type RxWindowTypeArray is array (natural range<>) of RxWindowType;      
   -- Arrays
   
-- Function declarations
--------------------------------------------------------------------------  

 
end RssiPkg;

package body RssiPkg is

-- Function bodies
--------------------------------------------------------------------------  

--------------------------------------------------------------------------------------------
end package body RssiPkg;
