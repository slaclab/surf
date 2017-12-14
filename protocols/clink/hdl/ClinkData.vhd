-------------------------------------------------------------------------------
-- File       : ClinkData.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink data de-serializer. 
-- Wrapper for ClinkDeSerial when used as dedicated data channel.
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
use work.ClinkPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkData is
   generic ( 
      TPD_G    : time    := 1 ns;
      INV_34_G : boolean := false);
   port (
      -- Cable Input
      cblHalfP   : inout slv(4 downto 0); --  8, 10, 11, 12,  9
      cblHalfM   : inout slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Delay clock, 200Mhz
      dlyClk     : in  sl; 
      dlyRst     : in  sl; 
      -- System clock and reset, must be 100Mhz or greater
      sysClk     : in  sl;
      sysRst     : in  sl;
      -- Status and config
      linkConfig : in  ClLinkConfigType;
      linkStatus : out ClLinkStatusType;
      -- Data output
      parData    : out slv(27 downto 0);
      parValid   : out sl;
      parReady   : in  sl);
end ClinkData;

architecture rtl of ClinkData is

   type LinkState is (RESET_S, WAIT_C_S, SHIFT_C_S, CHECK_C_S, LOAD_C_S, SHIFT_D_S, CHECK_D_S, DONE_S);
  
   -- Each delay tap = 1/(32 * 2 * 200Mhz) = 78ps 
   -- Input rate = 85Mhz * 7 = 595Mhz = 1.68nS = 21.55 taps

   type RegType is record
      state    : LinkState;
      lastClk  : slv(6 downto 0);
      delay    : slv(4 downto 0);
      delayLd  : sl;
      bitSlip  : sl;
      count    : integer range 0 to 99;
      status   : ClLinkStatusType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => RESET_S,
      lastClk  => (others=>'0'),
      delay    => "01111", -- 15 taps, > 1/2 cycle
      delayLd  => '0',
      bitSlip  => '0',
      count    => 99,
      status   => CL_LINK_STATUS_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clinkClk : sl;
   signal clinkRst : sl;
   signal intData  : slv(27 downto 0);
   signal parClock : slv(6 downto 0);

begin

   -------------------------------
   -- DeSerializer
   -------------------------------
   U_DataShift: entity work.ClinkDataShift
      generic map ( 
         TPD_G    => TPD_G,
         INV_34_G => INV_34_G)
      port map (
         cblHalfP    => cblHalfP,
         cblHalfM    => cblHalfM,
         linkRst     => linkConfig.reset,
         dlyClk      => dlyClk,
         dlyRst      => dlyRst,
         clinkClk    => clinkClk,
         clinkRst    => clinkRst,
         parData     => intData,
         parClock    => parClock,
         delay       => r.delay,
         delayLd     => r.delayLd,
         bitSlip     => r.bitSlip);

   -------------------------------
   -- State Machine
   -------------------------------
   comb : process (clinkRst, r, parClock) is
      variable v  : RegType;
   begin

      v := r;

      -- Init
      v.bitSlip := '0';
      v.delayLd := '0';

      -- Counter
      if r.count = 0 then
         v.count := 99;
      else
         v.count := r.count - 1;
      end if;

      -- State machine
      case r.state is

         -- Reset state
         when RESET_S =>
            if r.count = 0 then
               v.state   := WAIT_C_S;
               v.delayLd := '1';
            end if;

         -- Wait while recording clock state
         when WAIT_C_S =>
            v.lastClk := parClock;

            if r.count = 0 then
               v.state := SHIFT_C_S;
            end if;

         -- Shift clock one delay tick
         when SHIFT_C_S =>
            v.delay   := r.delay + 1;
            v.delayLd := '1';
            v.state   := CHECK_C_S;

         -- Check for clock value change
         when CHECK_C_S =>
            if r.count = 0 then

               -- Check for error
               if r.delay = 31 then
                  v.state := DONE_S;

               -- Check for clock change
               elsif parClock /= r.lastClk then
                  v.state := LOAD_C_S;

               -- Shift again
               else
                  v.state := SHIFT_C_S;
               end if;
            end if;

         -- Load final clock shift
         when LOAD_C_S =>
            v.delay   := r.delay - "01010"; -- 10 = 1/2 cycle
            v.delayLd := '1';
            v.state   := CHECK_D_S;

         when CHECK_D_S =>
            if r.count = 0 then
               if parClock = "1100011" then
                  v.state := DONE_S;
               else
                  v.state := SHIFT_D_S;
               end if;
            end if;

         when SHIFT_D_S =>
            v.bitSlip := '1';
            v.state   := CHECK_D_S;
            v.status.shiftCnt := r.status.shiftCnt + 1;

         when DONE_S =>
            if r.count = 0 then
               if parClock = "1100011" and r.delay /= 31 then
                  v.status.locked := '1';
               else
                  v.status.locked := '0';
               end if;
            end if;

         when others =>
      end case;

      v.status.delay := r.delay;

      -- Reset
      if (clinkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -- sync logic
   seq : process (clinkClk) is
   begin
      if (rising_edge(clinkClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   --------------------------------------
   -- Output FIFO and status
   --------------------------------------
   U_DataFifo: entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         BRAM_EN_G       => false,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 28,
         ADDR_WIDTH_G    => 4)
      port map (
         rst           => clinkRst,
         wr_clk        => clinkClk,
         wr_en         => '1',
         din           => intData,
         rd_clk        => sysClk,
         rd_en         => parReady,
         dout          => parData,
         valid         => parValid);

   U_Locked: entity work.Synchronizer
      generic map ( TPD_G => TPD_G )
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.locked,
         dataOut => linkStatus.locked);

   U_Delay: entity work.SynchronizerVector
      generic map ( 
         TPD_G   => TPD_G,
         WIDTH_G => 5)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.delay,
         dataOut => linkStatus.delay);

   U_ShiftCnt: entity work.SynchronizerVector
      generic map ( 
         TPD_G   => TPD_G,
         WIDTH_G => 3)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.shiftCnt,
         dataOut => linkStatus.shiftCnt);

end architecture rtl;

