-------------------------------------------------------------------------------
-- File       : IprogUltraScale.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-18
-- Last update: 2016-04-13
-------------------------------------------------------------------------------
-- Description:   Uses the ICAP primitive to internally 
--                toggle the PROG_B via IPROG command
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

library unisim;
use unisim.vcomponents.all;

entity IprogUltraScale is
   generic (
      TPD_G          : time    := 1 ns;
      USE_SLOWCLK_G  : boolean := false;
      BUFR_CLK_DIV_G : natural := 8;
      RST_POLARITY_G : sl      := '1');      
   port (
      clk         : in sl;
      rst         : in sl;
      slowClk     : in sl               := '0';
      start       : in sl;
      bootAddress : in slv(31 downto 0) := X"00000000");
end IprogUltraScale;

architecture rtl of IprogUltraScale is

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

   type StateType is (IDLE_S, PROG_S);

   type RegType is record
      state       : StateType;
      csl         : sl;
      rdy         : sl;
      rnw         : sl;
      cnt         : slv(3 downto 0);
      configData  : slv(31 downto 0);
      bootAddress : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      csl         => '1',
      rdy         => '1',
      rnw         => '1',
      cnt         => (others => '0'),
      configData  => (others => '0'),
      bootAddress => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal divClk    : sl;
   signal icape2Clk : sl;
   signal icape2Rst : sl;
   signal startEdge : sl;
   signal rdy       : sl;

begin
   
   icape2Clk <= slowClk when(USE_SLOWCLK_G) else divClk;

   BUFGCE_DIV_Inst : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => BUFR_CLK_DIV_G)
      port map (
         I   => clk,
         CE  => '1',
         CLR => '0',
         O   => divClk);         

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G         => TPD_G,
         IN_POLARITY_G => RST_POLARITY_G)
      port map (
         clk      => icape2Clk,
         asyncRst => rst,
         syncRst  => icape2Rst);

   SynchronizerOneShot_1 : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => icape2Clk,
         rst     => icape2Rst,
         dataIn  => start,
         dataOut => startEdge);

   ICAPE3_Inst : ICAPE3
      generic map (
         DEVICE_ID         => X"03628093",  -- Specifies the pre-programmed Device ID value to be used for simulation purposes
         ICAP_AUTO_SWITCH  => "DISABLE",    -- Enable switch ICAP using sync word
         SIM_CFG_FILE_NAME => "NONE")  -- Specifies the Raw Bitstream (RBT) file to be parsed by the simulation model
      port map (
         AVAIL   => rdy,                -- 1-bit output: Availability status of ICAP
         O       => open,               -- 32-bit output: Configuration data output bus
         PRDONE  => open,  -- 1-bit output: Indicates completion of Partial Reconfiguration
         PRERROR => open,  -- 1-bit output: Indicates Error during Partial Reconfiguration
         CLK     => icape2Clk,          -- 1-bit input: Clock input
         CSIB    => r.csl,              -- 1-bit input: Active-Low ICAP enable
         I       => r.configData,       -- 32-bit input: Configuration data input bus
         RDWRB   => r.rnw);             -- 1-bit input: Read/Write Select input

   comb : process (bootAddress, icape2Rst, r, rdy, startEdge) is
      variable v : RegType;
   begin
      v := r;

      v.rdy := rdy;

      case (r.state) is
         when IDLE_S =>
            v.csl         := '1';
            v.rnw         := '1';
            v.cnt         := (others => '0');
            v.bootAddress := bootAddress;
            if (startEdge = '1') then
               v.state := PROG_S;
            end if;

         when PROG_S =>
            if rdy = '1' then
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
                     v.configData := selectMapBitSwapping(bitReverse(r.bootAddress));
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
            end if;
            -- Check for interrupt
            if (r.rdy = '1') and (rdy = '0') then
               -- Reset the IPROG procedure
               v.csl := '1';
               v.rnw := '1';
               v.cnt := (others => '0');
            end if;
         when others => null;
      end case;

      if (icape2Rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
   end process comb;

   seq : process (icape2Clk) is
   begin
      if (rising_edge(icape2Clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
