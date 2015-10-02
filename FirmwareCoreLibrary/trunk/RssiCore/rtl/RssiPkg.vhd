library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

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

   type BufferInfoType is record
      seqN                  :  slv(7  downto 0);        
      acked                 :  slv(15 downto 0);  

      retransTout           :  slv(15 downto 0);
      cumulAckTout          :  slv(15 downto 0);
      nullSegTout           :  slv(15 downto 0);      
      transStateTout        :  slv(15 downto 0);

      maxRetrans            :  slv(7 downto 0);
      maxCumAck             :  slv(7 downto 0);
      
      maxOutofseq           :  slv(7 downto 0);
      maxAutoRst            :  slv(7 downto 0);

      connectionId          :  slv(31 downto 0);
   end record BufferInfoType;
      
   -- Arrays
   
-- Function declarations
--------------------------------------------------------------------------  

 
end RssiPkg;

package body RssiPkg is

-- Function bodies
--------------------------------------------------------------------------  

--------------------------------------------------------------------------------------------
end package body RssiPkg;
