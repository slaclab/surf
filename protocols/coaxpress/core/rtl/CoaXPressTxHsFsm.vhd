-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress TX High Speed FSM
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.CoaXPressPkg.all;
use surf.Code8b10bPkg.all;

entity CoaXPressTxHsFsm is
   generic (
      TPD_G        : time                   := 1 ns;
      TRIG_WIDTH_G : positive range 1 to 16 := 1);
   port (
      -- Clock and Reset
      txClk      : in  sl;
      txRst      : in  sl;
      -- Config Interface
      cfgMaster  : in  AxiStreamMasterType;
      cfgSlave   : out AxiStreamSlaveType;
      -- Trigger Interface
      txTrig     : in  slv(TRIG_WIDTH_G-1 downto 0);
      txTrigDrop : out slv(TRIG_WIDTH_G-1 downto 0);
      -- TX PHY Interface
      txData     : out slv(31 downto 0);
      txDataK    : out slv(3 downto 0));
end entity CoaXPressTxHsFsm;

architecture rtl of CoaXPressTxHsFsm is

   constant CXP_TRIG_INIT_C : Slv32Array(2 downto 0) := (0 => CXP_TRIG_C, 1 => (others => '0'), 2 => (others => '0'));
   constant CXP_TRIG_K_C    : Slv4Array(2 downto 0)  := (0 => x"F", 1 => (others => '0'), 2 => (others => '0'));

   type RegType is record
      forceIdle   : sl;
      -- Trigger
      txTrigDrop  : slv(TRIG_WIDTH_G-1 downto 0);
      txTrigCnt   : natural range 0 to 3;
      txTrigData  : Slv32Array(2 downto 0);
      txTrigDataK : Slv4Array(2 downto 0);
      -- TX PHY
      txData      : slv(31 downto 0);
      txDataK     : slv(3 downto 0);
      -- Config
      cfgSlave    : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      forceIdle   => '1',
      -- Trigger
      txTrigDrop  => (others => '0'),
      txTrigCnt   => 3,
      txTrigData  => CXP_TRIG_INIT_C,
      txTrigDataK => CXP_TRIG_K_C,
      -- TX PHY
      txData      => CXP_IDLE_C,
      txDataK     => CXP_IDLE_K_C,
      -- Config
      cfgSlave    => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (cfgMaster, r, txRst, txTrig) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.txTrigDrop := (others => '0');
      v.cfgSlave   := AXI_STREAM_SLAVE_INIT_C;

      -- Check for trigger
      if (txTrig /= 0) then

         -- Check if not moving trigger message
         if (r.txTrigCnt = 3) then

            -- Reset the counter
            v.txTrigCnt := 0;

            -- Set the LinkTriggerN value
            for i in TRIG_WIDTH_G-1 to 0 loop
               if (txTrig(i) = '1') then
                  v.txTrigData(2) := toSlv(i, 8) & toSlv(i, 8) & toSlv(i, 8) & toSlv(i, 8);
               end if;
            end loop;

            -- Set the flag
            v.forceIdle := '1';

         else
            -- Set the flag
            v.txTrigDrop := txTrig;
         end if;

      end if;

      -- Check if moving trigger message
      if (r.txTrigCnt /= 3) then

         -- Increment the counter
         v.txTrigCnt := r.txTrigCnt + 1;

         -- Update the TX data
         v.txData  := r.txTrigData(r.txTrigCnt);
         v.txDataK := r.txTrigDataK(r.txTrigCnt);

      -- Check if moving config message
      elsif (cfgMaster.tValid = '1') and (r.forceIdle = '0') then

         -- Accept the data
         v.cfgSlave.tReady := '1';

         -- Send the configuration message
         v.txData  := cfgMaster.tData(31 downto 0);
         v.txDataK := (others => cfgMaster.tUser(0));

      -- Insert the IDLE
      else

         -- Update the TX data
         v.txData  := CXP_IDLE_C;
         v.txDataK := CXP_IDLE_K_C;

         -- Reset the flag
         v.forceIdle := '0';

      end if;

      -- Outputs
      cfgSlave   <= v.cfgSlave;
      txData     <= r.txData;
      txDataK    <= r.txDataK;
      txTrigDrop <= r.txTrigDrop;

      -- Reset
      if (txRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (txClk) is
   begin
      if (rising_edge(txClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
