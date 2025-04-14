-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Test bench for AxisStreamSelector
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
use surf.AxiStreamPkg.all;

entity AxiStreamSelectorTb is
end entity AxiStreamSelectorTb;

architecture AxiStreamSelectorTbImpl of AxiStreamSelectorTb is

   constant DW_C : positive := 8;

   constant TPD_G : time := 0 ns;

   signal clk : sl          := '0';
   signal rst : sl          := '0';
   signal run : boolean     := true;

   -- r, sel, v1 v0, d1, d0
   type TestMType is record
      v  : sl;
      d  : slv(DW_C - 1 downto 0);
   end record TestMType;

   type TestSType is record
      r  : sl;
   end record TestSType;

   type TestMArray is array (natural range <>) of TestMType;

   signal testVec1 : TestMArray(0 to 9 ) := (
      0 => ( '0', X"A0" ),
      1 => ( '1', X"A1" ),
      2 => ( '1', X"A2" ),
      3 => ( '0', X"A3" ),
      4 => ( '1', X"A4" ),
      5 => ( '1', X"A5" ),
      6 => ( '1', X"A6" ),
      7 => ( '0', X"A7" ),
      8 => ( '0', X"A8" ),
      9 => ( '0', X"A9" )
   );

   signal testVec2 : TestMArray(0 to 6 ) := (
      0 => ( '0', X"B0" ),
      1 => ( '0', X"B1" ),
      2 => ( '1', X"B2" ),
      3 => ( '0', X"B3" ),
      4 => ( '1', X"B4" ),
      5 => ( '1', X"B5" ),
      6 => ( '1', X"B6" )
   );


   signal mTx : AxiStreamMasterArray(1 downto 0) := (
      others => AXI_STREAM_MASTER_INIT_C
   );

   signal sTx : AxiStreamSlaveArray (1 downto 0);

   signal sRx : AxiStreamSlaveType               := AXI_STREAM_SLAVE_INIT_C;
   signal mRx : AxiStreamMasterType;

   signal sel : sl := '0';

   signal stage : natural := 0;

   signal t1d : slv(DW_C - 1 downto 0);
   signal t0d : slv(DW_C - 1 downto 0);
   signal  rd : slv(DW_C - 1 downto 0);

   signal t1v : sl  := '0';
   signal t0v : sl  := '0';
   signal  rr : sl  := '0';

begin

   mTx(0).tValid <= t0v;
   mTx(1).tValid <= t1v;

   mTx(0).tData(DW_C - 1 downto 0) <= t0d;
   mTx(1).tData(DW_C - 1 downto 0) <= t1d;

   rd                       <= mRx.tData(DW_C - 1 downto 0);
   sRx.tReady               <= rr;

   P_CLK : process
   begin
      if ( run ) then
         clk <= not clk;
         wait for 50 ns;
      else
         wait;
      end if;
   end process P_CLK;

   P_TST : process( clk )
      variable nstage : natural;

      impure function xferTx(idx : natural range 0 to 1) return boolean is
      begin
         return mTx(idx).tValid = '1' and sTx(idx).tReady = '1';
      end function xferTx;

      impure function xferRx return boolean is
      begin
         return mRx.tValid = '1' and sRx.tReady = '1';
      end function xferRx;

      procedure assertNoXfer is
      begin
         assert not xferTx(0) severity failure;
         assert not xferTx(1) severity failure;
         assert not xferRx    severity failure;
      end procedure assertNoXfer;

   begin
      if ( rising_edge( clk ) ) then
         nstage := stage + 1;
         if ( stage < 3 ) then
         elsif ( stage = 3 ) then
            rst <= '0';
         elsif ( stage = 4 ) then
            -- drive not-selected valid first
            t1v <= '1';
            t1d <= X"B0";
            t0d <= X"A0";
            assertNoXfer;
         elsif ( stage = 5 ) then
            rr  <= '1';
            assertNoXfer;
         elsif ( stage = 6 ) then
            assertNoXfer;
         elsif ( stage = 7 ) then
            sel <= '1';
            assertNoXfer;
         elsif ( stage = 8 ) then
            assert not xferTx(0) severity failure;
            assert     xferTx(1) severity failure;
            assert not xferRx    severity failure;
            t1d <= X"B1";
         elsif ( stage = 9 ) then
            assert not xferTx(0) severity failure;
            assert     xferTx(1) severity failure;
            assert     xferRx    severity failure;
            assert rd = X"B0"    severity failure;
            sel <= '0';
         elsif ( stage = 10) then
            assert not xferTx(0) severity failure;
            assert not xferTx(1) severity failure;
            assert     xferRx    severity failure;
            assert rd = X"B1"    severity failure;
            rr  <= '0';
            t1v <= '1';
            t0v <= '1';
            t1d <= x"B2";
            t0d <= x"A2";
         elsif ( stage = 11 ) then
            assert     xferTx(0) severity failure;
            assert not xferTx(1) severity failure;
            assert not xferRx    severity failure;
            rr  <= '1';
            sel <= '1';
         elsif ( stage = 12 ) then
            assert not xferTx(0) severity failure;
            assert     xferTx(1) severity failure;
            assert     xferRx    severity failure;
            assert rd = x"A2";
            t1d <= x"B3";
            rr  <= '0';
         elsif ( stage = 13 ) then
            assert not xferTx(0) severity failure;
            assert not xferTx(1) severity failure;
            assert not xferRx    severity failure;
            rr  <= '1';
         elsif ( stage = 14 ) then
            assert not xferTx(0) severity failure;
            assert     xferTx(1) severity failure;
            assert     xferRx    severity failure;
            assert rd = x"B2";
            t1v <= '0';
         elsif ( stage = 14 ) then
            assert not xferTx(0) severity failure;
            assert not xferTx(1) severity failure;
            assert     xferRx    severity failure;
            assert rd = x"B3";
         elsif ( stage = 14 ) then
            assertNoXfer;
         else
            run <= false;
            report "Test PASSED";
         end if;
         stage <= nstage after TPD_G;
      end if;
   end process P_TST;

   U_DUT : entity surf.AxiStreamSelector
      generic map (
         TPD_G => TPD_G
      )
      port map (
         clk => clk,
         rst => rst,
         sel => sel,
         mIb => mTx,
         sIb => sTx,
         mOb => mRx,
         sOb => sRx
      );

end architecture AxiStreamSelectorTbImpl;

