-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Checks the RX RoCEv2 iCRC value
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
use ieee.std_logic_misc.all;

library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxCheckICrc is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean := false);
   port (
      -- Clock and Reset
      ethClk              : in  sl;
      ethRst              : in  sl;
      -- Slave ports
      sAxisMaster         : in  AxiStreamMasterType;
      sAxisSlave          : out AxiStreamSlaveType;
      sAxisCrcCheckMaster : in  AxiStreamMasterType;
      sAxisCrcCheckSlave  : out AxiStreamSlaveType;
      -- Master ports
      mAxisMaster         : out AxiStreamMasterType;
      mAxisSlave          : in  AxiStreamSlaveType);
end entity EthMacRxCheckICrc;

architecture rtl of EthMacRxCheckICrc is

   type RegType is record
      gotCrc     : sl;
      ibSlave    : AxiStreamSlaveType;
      ibCrcSlave : AxiStreamSlaveType;
      obMaster   : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      gotCrc     => '0',
      ibSlave    => AXI_STREAM_SLAVE_INIT_C,
      ibCrcSlave => AXI_STREAM_SLAVE_INIT_C,
      obMaster   => axiStreamMasterInit(EMAC_AXIS_CONFIG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ethRst, mAxisSlave, r, sAxisCrcCheckMaster, sAxisMaster) is
      variable v      : RegType;
      variable ibM    : AxiStreamMasterType;
      variable ibCrcM : AxiStreamMasterType;
   begin
      -- Latch the current value
      v := r;

      -- AXI Stream flow control
      v.ibSlave.tReady    := '0';
      v.ibCrcSlave.tReady := '0';
      if (mAxisSlave.tReady = '1') then
         v.obMaster.tValid := '0';
      end if;

      -- Check if we are ready to move data
      if v.obMaster.tValid = '0' then
         -- Get inbound data
         ibM    := sAxisMaster;
         ibCrcM := sAxisCrcCheckMaster;

         if ibM.tValid = '1' and (ibCrcM.tValid = '1' or r.gotCrc = '1') then
            -- Enable tReady on main
            v.ibSlave.tReady := '1';
            -- Enable tReady on CRC only for a single transaction
            if r.gotCrc = '0' then
               v.ibCrcSlave.tReady := '1';
               v.gotCrc            := '1';
            end if;
            if ibM.tLast = '1' then
               v.gotCrc := '0';
            end if;
            v.obMaster := ibM;
            if or_reduce(ibCrcM.tData(31 downto 0)) = '0' then
               v.obMaster.tUser(2) := '0';
            else
               v.obMaster.tUser(2) := '1';
            end if;
         end if;
      end if;

      -- Outputs
      sAxisSlave         <= v.ibSlave;
      sAxisCrcCheckSlave <= v.ibCrcSlave;
      mAxisMaster        <= r.obMaster;

      -- Reset
      if (RST_ASYNC_G = false and ethRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (ethClk, ethRst) is
   begin
      if (RST_ASYNC_G and ethRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
