-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: VHDL form of the Bluespec runtime five-port concurrent
-- register primitive CRegUN5.v, derived from CRegN5.vhd by replacing the
-- reset branch with an unconditional load. WIDTH_G mirrors the Verilog
-- "parameter width".
--
-- Structure: identical to CRegN5.vhd. One registered storage cell and four
-- combinational forwarded views of it, built as five concurrent conditional
-- signal assignments rather than five processes, so a read on any port
-- sees every lower-numbered port's write issued this same cycle, and a
-- higher-numbered port's write overrides a lower-numbered port's write on
-- the same cycle. See CRegN5.vhd's header for why this must never be
-- refactored into five processes: VHDL gives no implicit ordering between
-- processes, while the chain is an explicit combinational wire dependency
-- in the Verilog original.
--
-- Two things below look like mistakes to a later reader and are not.
--
-- First, this entity keeps a reset input port (RST) and a reset-value
-- generic (INIT_G) even though the clocked process below reads neither.
-- CRegUN5.v itself declares both (module header line 10, parameter line
-- 39) yet its own always block (lines 77 to 80) never reads them either.
-- The port table this harness drives every device handle from is derived
-- from the Verilog: dropping RST would leave the harness unable to
-- resolve a signal it must still drive, and dropping INIT_G would break
-- interface parity with the original's parameter list. Both are declared,
-- present, and never read, exactly matching the Verilog.
--
-- Second, the registered storage cell (qOut0) is declared with no initial
-- value, so GHDL leaves it undefined until the first enabled write, the
-- same uninitialized-storage decision RegUN.vhd records: the Verilog's own
-- alternating power-on pattern comes from an initial block inside a
-- synthesis-off guard, so it exists in simulation only and is not what the
-- Verilog synthesizes. With no reset branch to define the cell, the
-- harness's per-bit masking on the live GHDL replay side is the mechanism
-- that covers the undefined window before the first enabled write lands,
-- exactly the case that masking exists for; giving qOut0 a forced power-on
-- value would put a value into the bitstream that the Verilog never
-- synthesizes, purely to make a simulation number look tidier.
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

entity CRegUN5 is
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
end CRegUN5;

architecture rtl of CRegUN5 is

   -- The one registered storage cell. No initial value: see the header's
   -- uninitialized-storage note.
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
         qOut0 <= chainStage5;
      end if;
   end process;

   Q_OUT_0 <= qOut0;
   Q_OUT_1 <= chainStage1;
   Q_OUT_2 <= chainStage2;
   Q_OUT_3 <= chainStage3;
   Q_OUT_4 <= chainStage4;

end rtl;
