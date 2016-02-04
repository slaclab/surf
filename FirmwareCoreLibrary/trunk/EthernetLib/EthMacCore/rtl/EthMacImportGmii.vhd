-------------------------------------------------------------------------------
-- Title         : 1G MAC / Import Interface
-- Project       : RCE 1G-bit MAC
-------------------------------------------------------------------------------
-- File       : EthMacImportGmii.vhd
-- Author     : Jeff Olsen  <jjo@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-04
-- Last update: 2016-02-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PIC Import block for 1G MAC core for the RCE.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/04/2016: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacImportGmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      ethClk      : in  sl;
      ethClkRst   : in  sl;
      -- AXIS Interface   
      macIbMaster : out AxiStreamMasterType;
      -- PHY Interface
      gmiiRxDv    : in  sl;
      gmiiRxEr    : in  sl;
      gmiiRxd     : in  slv(7 downto 0);
      -- Status
      rxCountEn   : out sl;
      rxCrcError  : out sl);
end EthMacImportGmii;

architecture rtl of EthMacImportGmii is

   type RegType is record
      rxCountEn   : sl;
      rxCrcError  : sl;
      macIbMaster : AxiStreamMasterType;
   end record;

   constant REG_INIT_C : RegType := (
      rxCountEn   => '0',
      rxCrcError  => '0',
      macIbMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";   

begin

   comb : process (ethClkRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.macIbMaster := AXI_STREAM_MASTER_INIT_C;

      ----------------------------------
      ----------------------------------
      ----------------------------------
      --- Place holder for code here ---
      ----------------------------------
      ----------------------------------
      ----------------------------------

      -- Reset
      if (ethClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      macIbMaster <= r.macIbMaster;
      rxCountEn   <= r.rxCountEn;
      rxCrcError  <= r.rxCrcError;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
