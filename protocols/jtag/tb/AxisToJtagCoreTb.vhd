-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Test bench for AxisToJtagCore
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxisToJtagCoreTb is
end entity AxisToJtagCoreTb;

architecture AxisToJtagCoreTbImpl of AxisToJtagCoreTb is

   constant  W_C         : positive := 2;
   constant  WB_C        : positive := 8*W_C;

   type   WordArray is array (natural range <>) of slv(WB_C - 1 downto 0);

   signal clk            : sl := '0';
   signal rst            : sl := '1';
   signal rsttx          : sl := '1';

   signal run            : boolean := true;

   signal tdi            : sl;
   signal tdo            : sl;
   signal tck            : sl;

   signal mAxisTdi       : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisTdi       : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal mAxisTdo       : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisTdo       : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal stage          : natural := 0;

   signal res            : WordArray(0 to 4);
   signal ridx           : natural := 0;
   signal tidx           : natural := 0;

   signal tvGate         : boolean := true;
   signal rrGate         : boolean := true;

   signal rxDon          : boolean := false;

   signal del            : slv(31 downto 0) := (others => '0');

   signal txData         : WordArray(0 to 6) := (
        x"0021",
        x"0000",
        x"dead",
        x"0000",
        x"3210",
        x"0000",
        x"0002"
   );

begin

   tdo <= tdi;

   mAxisTdi.tData(WB_C - 1 downto 0) <= txData(tidx) when (tidx <= txData'right) else (others => 'X');
   mAxisTdi.tKeep(W_C  - 1 downto 0) <= (others => '1');
   mAxisTdi.tLast                    <= ite( tidx = txData'right, '1', '0' );

   mAxisTdi.tValid                   <= '1' when (tidx <= txData'right and tvGate) else '0';
   sAxisTdo.tReady                   <= '1' when (ridx <= res'right and not rxDon and rrGate) else '0';

   process
   begin
      if ( run ) then
         clk <= not clk;
         wait for 5 ns;
      else
         wait;
      end if;
   end process;

   P_TX : process (clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( (rst or rsttx) /= '0' ) then
            tidx           <= 0;
         else
            if ( (mAxisTdi.tValid and sAxisTdi.tReady) = '1' ) then
               tidx <= tidx + 1;
            end if;
         end if;
         del <= slv(unsigned(del) + 1 );
      end if;
   end process P_TX;

   P_RX  : process (clk)
   variable x : slv(WB_C - 1 downto 0 );
   begin
      if ( rising_edge( clk ) ) then
         if ( (rst or rsttx) /= '0' ) then
            ridx  <= 0;
            rxDon <= false;
         elsif ( (mAxisTdo.tValid and sAxisTdo.tReady) = '1' ) then
               x := mAxisTdo.tData( WB_C - 1 downto 0 );
               assert x = txData(2*ridx + 2) severity failure;
               res(ridx) <= x;
               if ( mAxisTdo.tLast = '0' ) then
                  ridx      <= ridx + 1;
               else
                  rxDon     <= true;
               end if;
         end if;
      end if;
   end process P_RX;

   P_RST : process( clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( stage < 3 ) then
            stage <= stage + 1;
         elsif (stage = 3 ) then
            rst   <= '0';
            rsttx <= '0';
            stage <= stage + 1;
         elsif (stage = 4 ) then
            if ( rxDon ) then
               stage  <= stage + 1;
               rrGate <= false;
               rsttx  <= '1';
               stage <= stage + 1;
            end if;
         elsif (stage = 5 ) then
            rsttx <= '0';
            stage <= stage + 1;
         elsif (stage = 6 ) then
            if ( rxDon ) then
               stage  <= stage + 1;
               rrGate <= true;
               tvGate <= false;
               rsttx  <= '1';
            end if;
            if ( rrGate ) then
              rrGate <= false;
            elsif del(7 downto 0) = "10000010" then
              rrGate <= true;
            end if;
         elsif (stage = 7 ) then
            rsttx <= '0';
            stage <= stage + 1;
         elsif (stage = 8 ) then
            if ( rxDon ) then
               stage <= stage + 1;
            end if;
            if ( tvGate ) then
              tvGate <= false;
            elsif del(7 downto 0) = "10000010" then
              tvGate <= true;
            end if;
         else
            run   <= false;
         end if;
      end if;
   end process P_RST;

   U_DUT : entity surf.AxisToJtagCore
      generic map (
         AXIS_WIDTH_G  => W_C,
         CLK_DIV2_G    => 2
      )
      port map (
         axisClk       => clk,
         axisRst       => rst,
         mAxisTmsTdi   => mAxisTdi,
         sAxisTmsTdi   => sAxisTdi,
         mAxisTdo      => mAxisTdo,
         sAxisTdo      => sAxisTdo,

         tck           => tck,
         tdi           => tdi,
         tdo           => tdo,
         tms           => open
      );

end architecture AxisToJtagCoreTbImpl;

