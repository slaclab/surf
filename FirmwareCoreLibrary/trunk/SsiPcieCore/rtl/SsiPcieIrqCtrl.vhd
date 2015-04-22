-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieIrqCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Interrupt Controller
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity SsiPcieIrqCtrl is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Interrupt Interface
      irqEnable    : in  sl;
      coreIrqReq   : in  sl;
      userIrqReq   : in  sl;
      irqAck       : in  sl;
      irqActive    : out sl;
      cfgIrqReq    : out sl;
      cfgIrqAssert : out sl;
      -- Clock and Resets
      pciClk       : in  sl;
      pciRst       : in  sl);       
end SsiPcieIrqCtrl;

architecture rtl of SsiPcieIrqCtrl is

   type StateType is (
      IDLE_S,
      SET_S,
      SERV_S,
      CLR_S);    

   type RegType is record
      irqRequest : sl;
      irqActive  : sl;
      irqReq     : sl;
      irqAssert  : sl;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      irqRequest => '0',
      irqActive  => '0',
      irqReq     => '0',
      irqAssert  => '0',
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (coreIrqReq, irqAck, irqEnable, pciRst, r, userIrqReq) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Update the interrupt request
      v.irqRequest := coreIrqReq or userIrqReq;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (r.irqRequest = '1') and (irqEnable = '1') then
               v.irqReq    := '1';
               v.irqAssert := '1';
               v.state     := SET_S;
            end if;
         -----------------------------------------------------------------------
         when SET_S =>
            if irqAck = '1' then
               v.irqReq    := '0';
               v.irqActive := '1';
               v.state     := SERV_S;
            end if;
         -----------------------------------------------------------------------
         when SERV_S =>
            if (r.irqRequest = '0') or (irqEnable = '0') then
               v.irqReq    := '1';
               v.irqAssert := '0';
               v.state     := CLR_S;
            end if;
         ----------------------------------------------------------------------
         when CLR_S =>
            if irqAck = '1' then
               v.irqReq    := '0';
               v.irqActive := '0';
               v.state     := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      irqActive    <= r.irqActive;
      cfgIrqReq    <= r.irqReq;
      cfgIrqAssert <= r.irqAssert;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
