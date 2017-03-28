-------------------------------------------------------------------------------
-- File       : Iprog7SeriesCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-09
-- Last update: 2015-09-10
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx 7-Series IPROG CMD
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

use work.StdRtlPkg.all;

entity Iprog7SeriesCore is
   generic (
      TPD_G         : time    := 1 ns;
      SYNC_RELOAD_G : boolean := true);
   port (
      -- Can be asynchronous if SYNC_RELOAD_G=false
      reload     : in sl;
      reloadAddr : in slv(31 downto 0) := X"00000000";

      icapClk    : in  sl;
      icapClkRst : in  sl;
      icapReq    : out sl;
      icapGrant  : in  sl := '1';
      icapCsl    : out sl;
      icapRnw    : out sl;
      icapI      : out slv(31 downto 0));

end Iprog7SeriesCore;

architecture rtl of Iprog7SeriesCore is

   constant BYPASS_SYNC_C : boolean := not SYNC_RELOAD_G;

   function selectMapBitSwapping (input : slv) return slv is
      variable i      : integer;
      variable j      : integer;
      variable output : slv(0 to 31);
   begin
      for i in 0 to 3 loop
         for j in 0 to 7 loop
            output((8*i)+j) := input((8*i)+(7-j));
         end loop;
      end loop;
      return output;
   end function selectMapBitSwapping;

   type StateType is (IDLE_S, REQ_S, PROG_S);

   type RegType is record
      state      : StateType;
      req        : sl;
      csl        : sl;
      rnw        : sl;
      cnt        : slv(3 downto 0);
      configData : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      req        => '0',
      csl        => '1',
      rnw        => '1',
      cnt        => (others => '0'),
      configData => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal icapReloadAddr : slv(31 downto 0);
   signal icapReload     : sl;

begin

   -- Synchronize reload addr to icap clk
   SynchronizerAddress_1 : entity work.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => BYPASS_SYNC_C,
         STAGES_G      => 2,
         WIDTH_G       => 32)
      port map (
         clk     => icapClk,
         rst     => icapClkRst,
         dataIn  => reloadAddr,
         dataOut => icapReloadAddr);

   -- Capture edge of start on icapClk
   SynchronizerStart_1 : entity work.SynchronizerEdge
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3)
      port map (
         clk        => icapClk,
         rst        => icapClkRst,
         dataIn     => reload,
         risingEdge => icapReload);

   comb : process (icapClkRst, icapGrant, icapReload, icapReloadAddr, r) is
      variable v : RegType;
   begin
      v := r;

      case (r.state) is
         when IDLE_S =>
            v.csl := '1';
            v.rnw := '1';
            v.cnt := (others => '0');
            if (icapReload = '1') then
               if (icapGrant = '1') then
                  v.state := PROG_S;
               else
                  v.state := REQ_S;
               end if;
               v.req := '1';
            end if;

         when REQ_S =>
            -- Wait to be granted access to the ICAP
            if (icapGrant = '1') then
               v.state := PROG_S;
            end if;

         when PROG_S =>
            v.csl := '0';
            v.rnw := '0';
            v.cnt := r.cnt + 1;
            case (r.cnt) is
               when X"0" =>
                  --Sync Word
                  v.configData := selectMapBitSwapping(X"AA995566");
               when X"1" =>
                  --Type 1 NO OP
                  v.configData := selectMapBitSwapping(X"20000000");
               when X"2" =>
                  --Type 1 Write 1 Words to WBSTAR
                  v.configData := selectMapBitSwapping(X"30020001");
               when X"3" =>
                  --Warm Boot Start Address (Load the Desired Address)
                  v.configData := selectMapBitSwapping(bitReverse(icapReloadAddr));
               when X"4" =>
                  --Type 1 Write 1 Words to CMD
                  v.configData := selectMapBitSwapping(X"30008001");
               when X"5" =>
                  --IPROG Command
                  v.configData := selectMapBitSwapping(X"0000000F");
               when X"6" =>
                  --Type 1 NO OP
                  v.configData := selectMapBitSwapping(X"20000000");
                  v.state      := IDLE_S;
               when others => null;
            end case;

         when others => null;
      end case;

      if (icapClkRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      icapRnw <= r.rnw;
      icapCsl <= r.csl;
      icapI   <= r.configData;
      icapReq <= r.req;

   end process comb;

   seq : process (icapClk) is
   begin
      if (rising_edge(icapClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
