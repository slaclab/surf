-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime five-port concurrent
-- register primitive CRegN5.v. WIDTH_G mirrors the Verilog "parameter width"
-- and INIT_G mirrors "parameter init". Reset is synchronous and active low,
-- the same convention as RegN.vhd.
--
-- Structure: this entity holds exactly one registered storage cell and
-- exposes four combinational forwarded views of it, not five independent
-- registers. A read on any port therefore sees every lower-numbered port's
-- write issued this same cycle: port 3's read already reflects ports 0, 1,
-- and 2's writes, and a higher-numbered port's write overrides a
-- lower-numbered port's write on the same cycle. This reproduces the
-- Verilog's own explicit wire chain (Q_OUT_1 through Q_OUT_5), where each
-- successive wire is a conditional select fed by the previous one.
--
-- The five forwarding stages below are five concurrent conditional signal
-- assignments, not five processes. VHDL gives no implicit ordering between
-- processes, while the Verilog original's chain is an explicit
-- combinational wire dependency; a process-based version that appeared to
-- work would in fact be depending on the order the simulator happened to
-- schedule two processes in, which is not something VHDL guarantees. Do not
-- refactor this chain into a process. Exactly one process exists in this
-- entity, and it registers exactly one signal: the last chain stage feeds
-- the one storage cell on every clock edge that is not a reset.
--
-- There is no TPD_G here on purpose: this primitive is compared cycle by
-- cycle against its Verilog original, and any nonzero output delay would
-- shift the sampled value by a cycle and break bit-exactness by
-- construction.
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

library surf;
use surf.StdRtlPkg.all;

entity CRegN5 is
   generic (
      WIDTH_G : positive := 1;
      INIT_G  : natural  := 0);
   port (
      CLK     : in  sl;
      RST     : in  sl;
      Q_OUT_0 : out slv(WIDTH_G-1 downto 0);
      EN_0    : in  sl;
      D_IN_0  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT_1 : out slv(WIDTH_G-1 downto 0);
      EN_1    : in  sl;
      D_IN_1  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT_2 : out slv(WIDTH_G-1 downto 0);
      EN_2    : in  sl;
      D_IN_2  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT_3 : out slv(WIDTH_G-1 downto 0);
      EN_3    : in  sl;
      D_IN_3  : in  slv(WIDTH_G-1 downto 0);
      Q_OUT_4 : out slv(WIDTH_G-1 downto 0);
      EN_4    : in  sl;
      D_IN_4  : in  slv(WIDTH_G-1 downto 0));
end CRegN5;

architecture rtl of CRegN5 is

   -- The one registered storage cell.
   signal qOut0 : slv(WIDTH_G-1 downto 0);

   -- The five forwarding chain stages. Stage 5 is internal only: the
   -- Verilog declares no port for its own Q_OUT_5 wire, since it feeds only
   -- the register and nothing external.
   signal chainStage1 : slv(WIDTH_G-1 downto 0);
   signal chainStage2 : slv(WIDTH_G-1 downto 0);
   signal chainStage3 : slv(WIDTH_G-1 downto 0);
   signal chainStage4 : slv(WIDTH_G-1 downto 0);
   signal chainStage5 : slv(WIDTH_G-1 downto 0);

begin

   chainStage1 <= D_IN_0 when (EN_0 = '1') else qOut0;
   chainStage2 <= D_IN_1 when (EN_1 = '1') else chainStage1;
   chainStage3 <= D_IN_2 when (EN_2 = '1') else chainStage2;
   chainStage4 <= D_IN_3 when (EN_3 = '1') else chainStage3;
   chainStage5 <= D_IN_4 when (EN_4 = '1') else chainStage4;

   process (CLK) is
   begin
      if rising_edge(CLK) then
         if (RST = '0') then
            qOut0 <= toSlv(INIT_G, WIDTH_G);
         else
            qOut0 <= chainStage5;
         end if;
      end if;
   end process;

   Q_OUT_0 <= qOut0;
   Q_OUT_1 <= chainStage1;
   Q_OUT_2 <= chainStage2;
   Q_OUT_3 <= chainStage3;
   Q_OUT_4 <= chainStage4;

end rtl;
