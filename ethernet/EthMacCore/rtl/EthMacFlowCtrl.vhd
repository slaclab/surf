-------------------------------------------------------------------------------
-- File       : EthMacFlowCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-21
-- Last update: 2016-10-20
-------------------------------------------------------------------------------
-- Description: ETH MAC Flow Control Module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity EthMacFlowCtrl is
   generic (
      TPD_G       : time                  := 1 ns;
      BYP_EN_G    : boolean               := false;
      VLAN_EN_G   : boolean               := false;
      VLAN_SIZE_G : positive range 1 to 8 := 1);
   port (
      -- Clock and Reset
      ethClk   : in  sl;
      ethRst   : in  sl;
      -- Inputs
      primCtrl : in  AxiStreamCtrlType;
      bypCtrl  : in  AxiStreamCtrlType;
      vlanCtrl : in  AxiStreamCtrlArray(VLAN_SIZE_G-1 downto 0);
      -- Output
      flowCtrl : out AxiStreamCtrlType);
end EthMacFlowCtrl;

architecture rtl of EthMacFlowCtrl is

   type RegType is record
      flowCtrl : AxiStreamCtrlType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      flowCtrl => AXI_STREAM_CTRL_INIT_C);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

--   attribute dont_touch      : string;
--   attribute dont_touch of r : signal is "TRUE";   

begin

   comb : process (bypCtrl, ethRst, primCtrl, r, vlanCtrl) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Sample the primary interface flow control
      v.flowCtrl.pause    := primCtrl.pause;
      v.flowCtrl.overflow := primCtrl.overflow;
      v.flowCtrl.idle     := '0';       -- Unused 

      -- Check if bypass interface is enabled
      if (BYP_EN_G) then
         -- Sample the bypass pause
         if (bypCtrl.pause = '1') then
            v.flowCtrl.pause := '1';
         end if;
         -- Sample the bypass overflow
         if (bypCtrl.overflow = '1') then
            v.flowCtrl.overflow := '1';
         end if;
      end if;

      -- Check if VLAN interface is enabled
      if (VLAN_EN_G) then
         -- Loop through the channels
         for i in (VLAN_SIZE_G-1) downto 0 loop
            -- Sample the VLAN pause
            if (vlanCtrl(i).pause = '1') then
               v.flowCtrl.pause := '1';
            end if;
            -- Sample the VLAN overflow
            if (vlanCtrl(i).overflow = '1') then
               v.flowCtrl.overflow := '1';
            end if;
         end loop;
      end if;

      -- Reset
      if (ethRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      flowCtrl <= r.flowCtrl;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
