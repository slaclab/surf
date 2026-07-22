-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Prepares the AXI stream for the ICRC insertion
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

library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacPrepareForICrc is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean := false;
      PIPE_STAGES_G  : natural := 0);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Slave ports
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master ports
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity EthMacPrepareForICrc;

architecture rtl of EthMacPrepareForICrc is

   type RegType is record
      cnt      : natural range 0 to 3;
      obMaster : AxiStreamMasterType;
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt      => 0,
      obMaster => AXI_STREAM_MASTER_INIT_C,
      ibSlave  => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ethRst, mAxisSlave, r, sAxisMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- AXI Stream flow control
      v.ibSlave.tReady := '0';
      if mAxisSlave.tReady = '1' then
         v.obMaster.tValid := '0';
      end if;

      -- Check for moving data condition
      if (sAxisMaster.tValid = '1') and (v.obMaster.tValid = '0') then

         -- Accept the transaction
         v.ibSlave.tReady := '1';

         -- Move the data
         v.obMaster := sAxisMaster;

         -- Case on the counter
         case r.cnt is
            when 0 =>
               -- reset output data
               v.obMaster.tData(v.obMaster.tData'length-1 downto 80) := (others => '0');
               -- ignore MAC header
               v.obMaster.tData(63 downto 0)                         := (others => '1');
               -- Get Version and Header length
               v.obMaster.tData(71 downto 64)                        := sAxisMaster.tData(119 downto 112);
               -- ignore Type of Service
               v.obMaster.tData(79 downto 72)                        := (others => '1');
               -- adjust tKeep
               v.obMaster.tKeep(v.obMaster.tKeep'length-1 downto 10) := (others => '0');
               v.obMaster.tKeep(9 downto 0)                          := (others => '1');
            when 1 =>
               -- ignore TTL
               v.obMaster.tData(55 downto 48) := (others => '1');
               -- ignore ip checksum
               v.obMaster.tData(79 downto 64) := (others => '1');
            when 2 =>
               -- ignore prot checksum
               v.obMaster.tData(79 downto 64)   := (others => '1');
               -- ignore BTH fecn, becn and resv6
               v.obMaster.tData(119 downto 112) := (others => '1');
            when others =>
               null;
         end case;

         -- Increment the counter
         if sAxisMaster.tLast = '1' then
            v.cnt := 0;
         elsif (r.cnt /= 3) then
            v.cnt := v.cnt + 1;
         end if;

      end if;

      -- Outputs
      sAxisSlave  <= v.ibSlave;
      mAxisMaster <= r.obMaster;

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
