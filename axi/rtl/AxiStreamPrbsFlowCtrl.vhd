-------------------------------------------------------------------------------
-- File       : AxiStreamPrbsFlowCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-27
-- Last update: 2017-10-27
-------------------------------------------------------------------------------
-- Description: Generates pseudo-random back pressure
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamPrbsFlowCtrl is
   generic (
      TPD_G         : time                 := 1 ns;
      PIPE_STAGES_G : natural range 0 to 1 := 0;
      SEED_G        : slv(31 downto 0)     := x"AAAA_5555";
      PRBS_TAPS_G   : NaturalArray         := (0 => 31, 1 => 6, 2 => 2, 3 => 1));
   port (
      clk         : in  sl;
      rst         : in  sl;
      threshold   : in  slv(31 downto 0) := x"8000_0000";
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamPrbsFlowCtrl;

architecture rtl of AxiStreamPrbsFlowCtrl is

   type RegType is record
      randomData : slv(31 downto 0);
      rxSlave    : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      randomData => SEED_G,
      rxSlave    => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;
   signal pause    : sl;

begin

   rxMaster   <= sAxisMaster;
   sAxisSlave <= rxSlave;

   U_DspComparator : entity work.DspComparator
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk => clk,
         ain => r.randomData,
         bin => threshold,
         ls  => pause);                 --  (a <  b)   

   comb : process (pause, r, rst, rxMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
      end if;

      -- Generate new random data
      v.randomData := lfsrShift(r.randomData, PRBS_TAPS_G, '0');

      -- Check if ready to move data
      if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') and (pause = '0') then
         -- Accept the data
         v.rxSlave.tReady := '1';
         -- Move the data
         v.txMaster       := rxMaster;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs              
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipe : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
