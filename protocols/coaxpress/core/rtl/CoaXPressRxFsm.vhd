-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX FSM
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
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;
use surf.Code8b10bPkg.all;

entity CoaXPressRxFsm is
   generic (
      TPD_G       : time     := 1 ns;
      NUM_LANES_G : positive := 1);
   port (
      -- Clock and Reset
      rxClk      : in  sl;
      rxRst      : in  sl;
      -- Config Interface
      cfgMaster  : out AxiStreamMasterType;
      -- Data Interface
      dataMaster : out AxiStreamMasterType;
      -- RX PHY Interface
      rxValid    : in  slv(NUM_LANES_G-1 downto 0);
      rxReady    : out slv(NUM_LANES_G-1 downto 0);
      rxData     : in  slv32Array(NUM_LANES_G-1 downto 0);
      rxDataK    : in  Slv4Array(NUM_LANES_G-1 downto 0);
      rxLinkUp   : in  slv(NUM_LANES_G-1 downto 0));
end entity CoaXPressRxFsm;

architecture rtl of CoaXPressRxFsm is

   constant AXIS_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4*NUM_LANES_G);

   type RegType is record
      rxReady    : slv(NUM_LANES_G-1 downto 0);
      cfgMaster  : AxiStreamMasterType;
      dataMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rxReady    => (others => '0'),
      cfgMaster  => AXI_STREAM_MASTER_INIT_C,
      dataMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rxRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cfgMaster  := AXI_STREAM_MASTER_INIT_C;
      v.dataMaster := AXI_STREAM_MASTER_INIT_C;
      v.rxReady    := (others => '1');  --TODO

      -- Outputs
      rxReady    <= v.rxReady;
      cfgMaster  <= r.cfgMaster;
      dataMaster <= r.dataMaster;

      -- Reset
      if (rxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
