-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AxiStream data packer tester, tx module
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
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBytePackerTbTx is
   generic (
      TPD_G         : time                := 1 ns;
      BYTE_SIZE_C   : positive            := 1;
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- System clock and reset
      axiClk       : in  sl;
      axiRst       : in  sl;
      -- Outbound frame
      mAxisMaster  : out AxiStreamMasterType);
end AxiStreamBytePackerTbTx;

architecture rtl of AxiStreamBytePackerTbTx is

   type RegType is record
      byteCount  : natural;
      frameCount : natural;
      master     : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteCount  => 0,
      frameCount => 0,
      master     => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, axiRst ) is
      variable v : RegType;
   begin
      v := r;

      v.master := AXI_STREAM_MASTER_INIT_C;
      v.master.tKeep  := (others=>'0');
      v.master.tValid := '1';

      for i in 0 to BYTE_SIZE_C-1 loop
         v.master.tData(i*8+7 downto i*8) := toSlv(v.byteCount,8);
         v.master.tKeep(i) := '1';
         v.byteCount := v.byteCount + 1;
      end loop;

      if v.byteCount = (r.frameCount+1)*BYTE_SIZE_C then
         v.master.tLast := '1';
         v.byteCount    := 0;
         v.frameCount   := v.frameCount + 1;
      end if;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster <= r.master;

   end process;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin;
      end if;
   end process;

end architecture rtl;

