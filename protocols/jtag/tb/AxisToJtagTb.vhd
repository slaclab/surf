-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Test bench for AxisToJtag
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
use surf.TextUtilPkg.all;


-- use this module if a reliable stream is available (reliable network to host)

entity AxisToJtagTb is
end entity AxisToJtagTb;

architecture AxisToJtagTbImpl of AxisToJtagTb is

   constant TPD_C : time := 5 ns;

   subtype Word is slv(31 downto 0);
   type    WordArray is array( natural range <> ) of Word;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal mAxisTdi : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisTdi : AxiStreamSlaveType;

   signal mAxisTdo : AxiStreamMasterType;
   signal sAxisTdo : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal loopback : sl;

   signal run      : boolean := true;

   signal txstage  : natural := 0;
   signal rxstage  : natural := 0;

   signal td       : Word;
   signal tv       : sl := '0';
   signal tl       : sl;
   signal tr       : sl;

   signal rd       : Word;
   signal rv       : sl := '0';
   signal rl       : sl;
   signal rr       : sl;



begin

   tr <= sAxisTdi.tReady;

   mAxisTdi.tValid             <= tv;
   mAxisTdi.tLast              <= tl;
   mAxisTdi.tData(31 downto 0) <= td;

   rd <= mAxisTdo.tData(31 downto 0);
   rv <= mAxisTdo.tValid;
   rl <= mAxisTdo.tLast;

   sAxisTdo.tReady             <= rr;

   P_TX : process( clk )
   variable v   : natural;
   variable cnt : natural;
   variable txid: slv(7 downto 0) := x"00";

   procedure send(xin : in Word; del : in natural := 0) is
      variable v_td : Word;
      variable v_tv : sl;
      variable v_tl : sl;
   begin
      v_td := td;
      v    := txstage;
      v_tv := tv;
      v_tl := tl;
      if ( tv = '0' ) then
        cnt  := 0;
        v_td := xin;
        v_td(27 downto 20) := txid;
        txid := slv(unsigned(txid) + 1);
        v_tv := '1';
        if del = 0 then
           v_tl := '1';
        else
           v_tl := '0';
        end if;
      elsif ( tr = '1' ) then
        if ( tl = '1' ) then
           v_tv := '0';
           v    := txstage + 1;
        else
           cnt := cnt + 1;
           if ( cnt = del ) then
              v_tl := '1';
           end if;
        end if;
      end if;
      td <= v_td after TPD_C;
      tv <= v_tv after TPD_C;
      tl <= v_tl after TPD_C;
   end procedure send;

   procedure sendVec(xin : in WordArray) is
      variable v_td : Word;
      variable v_tv : sl;
      variable v_tl : sl;
   begin
      v    := txstage;
      v_td := td;
      v_tv := tv;
      v_tl := tl;
      if ( tv = '0' ) then
        cnt  := 0;
        v_td := xin(cnt);
        v_td(27 downto 20) := txid;
        txid := slv(unsigned(txid) + 1);
        cnt  := cnt + 1;
        if ( cnt = xin'length ) then
           v_tl := '1';
        else
           v_tl := '0';
        end if;
        v_tv := '1';
      elsif ( tr = '1' ) then
        if ( tl = '1' ) then
           v_tv := '0';
           v    := txstage + 1;
        else
           v_td := xin(cnt);
           cnt  := cnt + 1;
           if ( cnt = xin'length ) then
              v_tl := '1';
           end if;
        end if;
      end if;
      td <= v_td after TPD_C;
      tv <= v_tv after TPD_C;
      tl <= v_tl after TPD_C;
   end procedure sendVec;
   begin
      if ( rising_edge( clk ) ) then
         v := txstage + 1;

         case txstage is
            when 0|1|2 =>
            when 3     =>
               rst <= '0';
            when 4     =>
            when 5     =>
               -- normal query
               send( x"00000000" );
            when 6     =>
               -- bad version; too long a frame
               send( x"40000000", 4 );
            when 7     =>
               -- bad command
               send( x"20000000" );
            when 8     =>
               -- single word shift
               sendVec( (x"1000001f", x"00000000", x"deadbeef" ) );
            when 9     =>
               -- word and bit shift
               sendVec( (x"10000020", x"00000000", x"affecafe", x"00000000", x"00000001") );
            when 10    =>
               -- extra words
               sendVec( (x"10000004", x"00000000", x"deadbe33", x"deadbeef", x"ffffffff") );
            when 11    =>
               -- short frame (should be truncated)
               sendVec( (x"10000020", x"00000000", x"12345678", x"ffffffff") );
            when 12    =>
               sendVec( (x"1000005f",
                         x"12345678",
                         x"affecafe",
                         x"affecafe",
                         x"12345678",
                         x"abcdef90",
                         x"00000001") );
            when 13    =>
               -- retransmission (send less data; replay should play full set back)
                 txid := slv(unsigned(txid) - 1);
            when 14    =>
               sendVec( (x"1000005f", x"00000000", x"affecafe") );
            when 15    =>
               -- retransmission (send less data; replay should play full set back)
                 txid := slv(unsigned(txid) - 1);
            when 16    =>
               sendVec( (x"1000005f", x"12345678") );
            when 17    =>
               sendVec( (x"1000007f",
                         x"feedbeef",
                         x"01020304",
                         x"feedbeef",
                         x"11121314",
                         x"feedbeef",
                         x"21222324",
                         x"feedbeef",
                         x"31323334") );
   when others  =>
         end case;

         txstage <= v after TPD_C;
      end if;
   end process P_TX;

   P_RX : process( clk )

      variable rxid : slv(7 downto 0) := x"00";
      variable v    : natural;
      variable cnt  : natural;

      procedure rcv(expin : in Word; lst : in sl) is
         variable exp : Word;
      begin
         exp               := expin;
         exp(27 downto 20) := rxid;
         if ( (rv and rr) = '1' ) then
            if ( rd /= exp ) then
               print("RX mismatch; expected " & hstr(exp) & " but got: " & hstr(rd));
            end if;
            assert rd = exp severity failure;
            assert rl = lst severity failure;
            rxid := slv(unsigned(rxid) + 1);
         else
            v := rxstage;
         end if;
      end procedure rcv;

      procedure rcvVec(exp : in WordArray) is
         variable val : Word;
      begin
         v := rxstage;
         if ( rr = '0' ) then
            cnt := 0;
            rr <= '1' after TPD_C;
         elsif ( rv = '1' ) then
            val               := exp(cnt);
            if ( cnt = 0 ) then
               val(27 downto 20) := rxid;
               rxid              := slv(unsigned(rxid) + 1);
            end if;
            if ( rd /= val ) then
               print("rcvVec - mismatch at " & str(cnt) & "; expected " & hstr(val) & " but got: " & hstr(rd));
            end if;
            assert( rd = val ) severity failure;
            cnt := cnt + 1;
            if ( cnt = exp'length ) then
               assert( rl = '1' ) severity failure;
               v := rxstage + 1;
               rr <= '0' after TPD_C;
            else
               assert( rl = '0' ) severity failure;
            end if;
         end if;
      end procedure rcvVec;

   begin
      if ( rising_edge( clk ) ) then
      if ( rst = '1' ) then
         rxstage <= 0 after TPD_C;
      else
         v := rxstage + 1;

         case rxstage is
            when 0 =>
            when 1 =>
               rr <= '1';
            when 2 =>
               rcv( x"00000043", '1' );
            when 3 =>
               rcv( x"20000001", '1' );
            when 4|5|6|7 =>
               -- pause
               rr <= '0';
            when 8 =>
               rr <= '1';
            when 9 =>
               rcv( x"20000002", '1' );
            when 10 =>
               rr <= '0';
            when 11 =>
               rcvVec( (x"1000001f", x"deadbeef") );
            when 12 =>
               rcvVec( (x"10000020", x"affecafe", x"00000001") );
            when 13 =>
               rcvVec( (x"10000004", x"00000013" ) );
            when 14 => -- short frame
               rcvVec( (x"10000020", x"12345678") );
            when 15 =>
               rcvVec( (x"1000005f", x"affecafe", x"12345678", x"00000001") );
            when 16 =>
               rxid := slv(unsigned(rxid) - 1); -- expect retransmission
            when 17 =>
               rcvVec( (x"1000005f", x"affecafe", x"12345678", x"00000001") );
            when 18 =>
               rxid := slv(unsigned(rxid) - 1); -- expect retransmission
            when 19 =>
               rcvVec( (x"1000005f", x"affecafe", x"12345678", x"00000001") );
			when 20 =>
               rcvVec( (x"1000007f",
                        x"01020304",
                        x"11121314",
                        x"21222324",
                        x"31323334") );

            when others  =>
               run <= false;
               report "Test PASSED";
         end case;

         rxstage <= v after TPD_C;
      end if;
      end if;
   end process P_RX;


   P_CLK : process
   begin
      if ( run ) then
         clk <= not clk;
         wait for 50 ns;
      else
         wait;
      end if;
   end process P_CLK;

   U_DUT : entity surf.AxisToJtag
      generic map (
         TPD_G           => TPD_C,
         MEM_DEPTH_G     => 4
      )
      port map (
         axisClk         => clk,
         axisRst         => rst,

         mAxisReq        => mAxisTdi,
         sAxisReq        => sAxisTdi,

         mAxisTdo        => mAxisTdo,
         sAxisTdo        => sAxisTdo,

         tdi             => loopback,
         tdo             => loopback
      );

end architecture AxisToJtagTbImpl;
