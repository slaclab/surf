library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.SsiPkg.all;

package RssiPkg is

-- Constant definitions
--------------------------------------------------------------------------


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
      tDest                 :  slv(SSI_TDEST_BITS_C-1 downto 0);  
      --eacked                :  sl;
      eofe                  :  sl;
      sent                  :  sl;
   end record WindowType;
   
   constant WINDOW_INIT_C : WindowType := (
      seqN                  => (others => '0'),
      segType               => (others => '0'),
      acked                 => '0',  
      eacked                => '0',
      sent                  => '0');
   
   
   type WindowTypeArray is array (0 to 255) of WindowType;
      
   -- Arrays
   
-- Function declarations
--------------------------------------------------------------------------  

 
end RssiPkg;

package body RssiPkg is

-- Function bodies
--------------------------------------------------------------------------  

--------------------------------------------------------------------------------------------
end package body RssiPkg;
