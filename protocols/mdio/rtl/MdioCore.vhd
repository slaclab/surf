-------------------------------------------------------------------------------
-- Title      : MDIO Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Execute a MDIO-read or -write transaction
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
use surf.MdioPkg.all;

entity MdioCore is
   generic (
      TPD_G               : time                            := 1 ns;
      -- half-period of MDC in clk cycles; MDC is a subharmonic of clk
      DIV_G               : natural range 1 to natural'high := 1
   );
   port (
      -- clock and reset
      clk                 : in    sl;
      rst                 : in    sl;

      -- programming interface;
      trg                 : in    sl;               -- assert trg for ONE clock
      cmd                 : in    MdioCommandType;  -- cmd is latched during 'trg'
      din                 : out   slv(15 downto 0); -- read back data - valid during 'don'
      don                 : out   sl;               -- cmd completed; asserted for one clk

      -- MDIO interface
      mdc                 : out   sl;
      mdo                 : out   sl;
      mdi                 : in    sl
   );
end entity MdioCore;

architecture MdioCoreImpl of MdioCore is

   constant DIV_BITS_C : positive := bitSize( DIV_G - 1);

   type State is ( IDLE, RUN );

   type RegType is record
     dataOut : slv(32 downto 0);
     din     : slv(15 downto 0);
     count   : slv( 5 downto 0);
     div     : slv(DIV_BITS_C - 1 downto 0);
     mdc     : sl;
     don     : sl;
     state   : State;
   end record;

   constant REG_INIT_C : RegType := (
     dataOut => ( others => '1' ),
     din     => ( others => '0' ),
     count   => ( others => '1' ),
     div     => ( others => '0' ),
     mdc     => '0',
     don     => '0',
     state   => IDLE
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   mdo    <= r.dataOut(32);
   mdc    <= r.mdc;

   don    <= r.don;
   din    <= r.din;

   COMB : process(r, trg, mdi, cmd)
      variable v : RegType;
   begin
      v        := r;
      v.don    := '0';

      v.div    := slv( unsigned(r.div) - 1 );

      if ( r.state = IDLE ) then
         if ( trg /= '0' ) then
            v.state                 := RUN;
            v.dataOut(31 downto 30) := "01";                                  -- start
            v.dataOut(29 downto 28) := ite( cmd.rdNotWr = '1', "10", "01" ); -- op
            v.dataOut(27 downto 23) := cmd.phyAddr;
            v.dataOut(22 downto 18) := cmd.regAddr;
            v.dataOut(17)           := '1';
            v.dataOut(16)           := cmd.rdNotWr;
            v.dataOut(15 downto  0) := cmd.dataOut;
            v.div                   := toSlv(DIV_G - 1, DIV_BITS_C);
         end if;
      else
         if ( unsigned(r.div) = 0 ) then
            v.div := toSlv(DIV_G - 1, DIV_BITS_C);
            v.mdc := ite( r.mdc = '0', '1', '0' );

            if ( r.mdc /= '0' ) then
               v.count := slv( unsigned(r.count) - 1 );
               if ( unsigned(r.count) = 0 ) then
                  v.state               := IDLE;
                  v.don                 := '1';
               end if;
               if ( v.count(5) = '0' or v.state = IDLE ) then -- count < 32 or last iteration
                  v.dataOut( 32 downto 1 ) := r.dataOut(31 downto 0);
                  v.dataOut( 0 )           := '1';
               end if;
            else
               v.din( 15 downto 1 ) := r.din (14 downto 0);
               v.din( 0 )           := mdi;
            end if;
         end if;
      end if;

      rin <= v;

   end process COMB;

   SEQ  : process( clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( rst /= '0' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process SEQ;

end architecture MdioCoreImpl;
