library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.SsiPkg.all;

package RssiPkg is

-- Constant definitions
--------------------------------------------------------------------------
constant MAX_SEGMENT_SIZE_C      : positive := 10;     -- 2^MAX_SEGMENT_SIZE_G = Number of 16bit wide data words

-- Sub-types 
-------------------------------------------------------------------------- 
   type HeaderValuesType is record
      maxOutsSegments       :  slv(7  downto 0); -- Receiver parameter       
      maxOutsSegSize        :  slv(15 downto 0); -- Receiver parameter 

      retransTout           :  slv(15 downto 0);
      cumulAckTout          :  slv(15 downto 0);
      nullSegTout           :  slv(15 downto 0);      
      transStateTout        :  slv(15 downto 0);

      maxRetrans            :  slv(7 downto 0);
      maxCumAck             :  slv(7 downto 0);
      
      maxOutofseq           :  slv(7 downto 0);
      maxAutoRst            :  slv(7 downto 0);

      connectionId          :  slv(31 downto 0);
   end record HeaderValuesType;

   type WindowType is record
      seqN                  :  slv(7  downto 0);
      segType               :  slv(2  downto 0);
      
      -- SSI
      --eacked                :  sl;
      eofe                  : sl;
      strb                  : slv(15 downto 0);
      keep                  : slv(15 downto 0);
      dest                  : slv(SSI_TDEST_BITS_C-1 downto 0);
      packed                : sl;
      
      segSize               :  slv(MAX_SEGMENT_SIZE_C-1 downto 0);
   end record WindowType;
   
   constant WINDOW_INIT_C : WindowType := (
      seqN                  => (others => '0'),
      segType               => (others => '0'),
 
      eofe                  => '0',
      strb                  => (others => '1'), 
      keep                  => (others => '1'), 
      dest                  => (others => '0'), 
      packed                => '0', 
      segSize               => (others => '0')
   ); 
   
   
   type WindowTypeArray is array (natural range<>) of WindowType;
      
   -- Arrays
   
-- Function declarations
--------------------------------------------------------------------------  

 
end RssiPkg;

package body RssiPkg is

-- Function bodies
--------------------------------------------------------------------------  

--------------------------------------------------------------------------------------------
end package body RssiPkg;
