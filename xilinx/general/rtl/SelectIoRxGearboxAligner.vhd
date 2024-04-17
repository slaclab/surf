-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Aligns the SELECTIO LVDS RX gearbox.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

entity SelectIoRxGearboxAligner is
   generic (
      TPD_G           : time                   := 1 ns;
      SIMULATION_G    : boolean                := false;
      CODE_TYPE_G     : string                 := "LINE_CODE";  -- or "SCRAMBLER"
      DLY_STEP_SIZE_G : positive range 1 to 16 := 1);  -- 1 for Ultrascale or 16 for 7-Series
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- Line-Code Interface (CODE_TYPE_G = "LINE_CODE")
      lineCodeValid   : in  sl;
      lineCodeErr     : in  sl;
      lineCodeDispErr : in  sl;
      linkOutOfSync   : in  sl;
      -- 64b/66b Interface (CODE_TYPE_G = "SCRAMBLER")
      rxHeaderValid   : in  sl;
      rxHeader        : in  slv(1 downto 0);
      -- Gearbox Slip
      bitSlip         : out sl;
      -- IDELAY (DELAY_TYPE="VAR_LOAD") Interface
      dlyLoad         : out sl;
      dlyCfg          : out slv(8 downto 0);  -- Ultrascale: CNTVALUEIN=dlyCfg(8 downto 0), 7-series: CNTVALUEIN=dlyCfg(8 downto 4)
      -- Configuration Interface
      enUsrDlyCfg     : in  sl               := '0';  -- Enable User delay config
      usrDlyCfg       : in  slv(8 downto 0)  := (others => '0');  -- User delay config
      bypFirstBerDet  : in  sl               := '1';  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
      minEyeWidth     : in  slv(7 downto 0)  := toSlv(80, 8);  -- Sets the minimum eye width required for locking (units of IDELAY step)
      lockingCntCfg   : in  slv(23 downto 0) := ite(SIMULATION_G, x"00_0064", x"00_FFFF");  -- Number of error-free event before state=LOCKED_S
      -- Status Interface
      eyeWidth        : out slv(8 downto 0);
      errorDet        : out sl;
      locked          : out sl);
end entity SelectIoRxGearboxAligner;

architecture rtl of SelectIoRxGearboxAligner is

   constant SLIP_WAIT_C : positive := 100;

   type StateType is (
      UNLOCKED_S,
      SLIP_WAIT_S,
      LOCKING_S,
      EYE_SCAN_S,
      BIT_WAIT_S,
      BIT_ALIGN_S,
      LOCKED_S);

   type RegType is record
      enUsrDlyCfg : sl;
      usrDlyCfg   : slv(8 downto 0);
      dlyLoad     : slv(1 downto 0);
      dlyConfig   : slv(8 downto 0);
      dlyCache    : slv(8 downto 0);
      slipWaitCnt : natural range 0 to SLIP_WAIT_C-1;
      goodCnt     : slv(23 downto 0);
      bitSlip     : sl;
      errorDet    : sl;
      firstError  : sl;
      armed       : sl;
      scanDone    : sl;
      eyeWidth    : slv(8 downto 0);
      locked      : sl;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      enUsrDlyCfg => '0',
      usrDlyCfg   => (others => '0'),
      dlyLoad     => (others => '0'),
      dlyConfig   => (others => '0'),
      dlyCache    => (others => '0'),
      slipWaitCnt => 0,
      goodCnt     => (others => '0'),
      bitSlip     => '0',
      errorDet    => '0',
      firstError  => '0',
      armed       => '0',
      scanDone    => '0',
      eyeWidth    => (others => '0'),
      locked      => '0',
      state       => UNLOCKED_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert ((CODE_TYPE_G = "LINE_CODE") or (CODE_TYPE_G = "SCRAMBLER"))
      report "CODE_TYPE_G must be LINE_CODE or SCRAMBLER"
      severity failure;

   comb : process (bypFirstBerDet, enUsrDlyCfg, lineCodeDispErr, lineCodeErr,
                   lineCodeValid, linkOutOfSync, lockingCntCfg, minEyeWidth, r,
                   rst, rxHeader, rxHeaderValid, usrDlyCfg) is
      variable v : RegType;

      procedure slipProcedure is
      begin

         -- Update the Delay module
         v.dlyLoad(1) := '1';

         -- Check for max value
         if (r.dlyConfig >= 255) then

            -- Set min. value
            v.dlyConfig := (others => '0');

            -- Slip by 1-bit in the gearbox
            v.bitSlip := '1';

            -- Reset the flag
            v.firstError := '0';

         else

            -- Increment the counter
            v.dlyConfig := r.dlyConfig + DLY_STEP_SIZE_G;

            -- Reset the flag
            v.firstError := '1';

         end if;

         -- Reset the flags
         v.armed    := '0';
         v.scanDone := '0';
         v.locked   := '0';

         -- Reset the counter
         v.goodCnt := (others => '0');

         -- Next state
         v.state := SLIP_WAIT_S;

      end procedure slipProcedure;

      variable scanCnt    : slv(8 downto 0);
      variable scanHalf   : slv(8 downto 0);
      variable eyescanCfg : slv(8 downto 0);
      variable valid      : sl;

   begin
      -- Latch the current value
      v := r;

      -- Update the local variables
      scanCnt    := (r.dlyConfig-r.dlyCache);
      scanHalf   := '0' & scanCnt(8 downto 1);
      eyescanCfg := '0' & minEyeWidth;

      -- Reset strobes
      v.bitSlip  := '0';
      v.errorDet := '0';

      -- Shift register
      v.dlyLoad := '0' & r.dlyLoad(1);

      -- 64b/66b Interface
      if (CODE_TYPE_G = "SCRAMBLER") then
         valid := rxHeaderValid;
         -- Check for bad header
         if (rxHeaderValid = '1') and ((rxHeader = "00") or (rxHeader = "11")) then
            v.errorDet := '1';
         end if;

      -- Line-Code Interface
      elsif (CODE_TYPE_G = "LINE_CODE") then
         valid := lineCodeValid;
         -- Check for bad header
         if (lineCodeValid = '1') and ((lineCodeErr = '1') or (lineCodeDispErr = '1')) then
            v.errorDet := '1';
         end if;
         -- Check for out-of-sync after locked
         if (r.locked = '1') and (linkOutOfSync = '1') then
            valid      := '1';
            v.errorDet := '1';
         end if;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when UNLOCKED_S =>
            -- Check for data
            if (valid = '1') then
               -- Check for bad header
               if (v.errorDet = '1') then
                  -- Execute the slip procedure
                  slipProcedure;
               else
                  -- Next state
                  v.state := LOCKING_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SLIP_WAIT_S =>
            -- Check the counter
            if (r.slipWaitCnt = SLIP_WAIT_C-1) or (r.enUsrDlyCfg = '1') then

               -- Reset the counter
               v.slipWaitCnt := 0;

               -- Check if eye scan completed
               if (r.scanDone = '1') or (r.enUsrDlyCfg = '1') then

                  -- 64b/66b Interface
                  if (CODE_TYPE_G = "SCRAMBLER") then
                     -- Next state
                     v.state := LOCKED_S;

                  -- Line-Code Interface
                  elsif (CODE_TYPE_G = "LINE_CODE") then
                     -- Next state
                     v.state := BIT_ALIGN_S;

                  end if;

               -- Check for armed mode
               elsif (r.armed = '1') then
                  -- Next state
                  v.state := EYE_SCAN_S;
               else
                  -- Next state
                  v.state := UNLOCKED_S;
               end if;

            else
               -- Increment the counter
               v.slipWaitCnt := r.slipWaitCnt + 1;
            end if;
         ----------------------------------------------------------------------
         when LOCKING_S =>
            -- Check for data
            if (valid = '1') then

               -- Check for bad header
               if (v.errorDet = '1') then
                  -- Execute the slip procedure
                  slipProcedure;

               elsif (r.goodCnt < lockingCntCfg) then
                  -- Increment the counter
                  v.goodCnt := r.goodCnt + 1;
               else

                  -- Check if no bit errors detected yet during this IDELAY sweep
                  if (r.firstError = '0') and (bypFirstBerDet = '0') then
                     -- Execute the slip procedure
                     slipProcedure;

                  else

                     -- Set the flag
                     v.armed := '1';

                     -- Reset the counter
                     v.goodCnt := (others => '0');

                     -- Make a cached copy
                     v.dlyCache := r.dlyConfig;

                     -- Update the Delay module
                     v.dlyLoad(1) := '1';
                     v.dlyConfig  := r.dlyConfig + DLY_STEP_SIZE_G;

                     -- Next state
                     v.state := SLIP_WAIT_S;

                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when EYE_SCAN_S =>
            -- Check for data
            if (valid = '1') then

               -- Check for bad header and less than min. eye width configuration
               if (v.errorDet = '1') and (scanCnt <= eyescanCfg) then
                  -- Execute the slip procedure
                  slipProcedure;

               -- Check for not roll over and not
               elsif (r.goodCnt < lockingCntCfg) and (v.errorDet = '0') then
                  -- Increment the counter
                  v.goodCnt := r.goodCnt + 1;
               else

                  -- Reset the counter
                  v.goodCnt := (others => '0');

                  -- Update the Delay module
                  v.dlyLoad(1) := '1';
                  v.dlyConfig  := r.dlyConfig + DLY_STEP_SIZE_G;

                  -- Check for last count or first header error after min. eye width
                  if (scanCnt >= 255) or (v.errorDet = '1') then

                     -- Set to half way between eye
                     v.dlyConfig := r.dlyCache + scanHalf;

                     -- Update the status register with measured value
                     v.eyeWidth := scanCnt;

                     -- Set the flag
                     v.scanDone := '1';

                  end if;

                  -- Next state
                  v.state := SLIP_WAIT_S;

               end if;
            end if;
         ----------------------------------------------------------------------
         when BIT_WAIT_S =>
            -- Check the counter
            if (r.slipWaitCnt = SLIP_WAIT_C-1) then

               -- Reset the counter
               v.slipWaitCnt := 0;

               -- Next state
               v.state := BIT_ALIGN_S;

            else
               -- Increment the counter
               v.slipWaitCnt := r.slipWaitCnt + 1;
            end if;
         ----------------------------------------------------------------------
         when BIT_ALIGN_S =>
            -- Check for code error
            if (valid = '1') and (v.errorDet = '1') then

               -- Reset the counter
               v.slipWaitCnt := 0;

               -- Execute the slip procedure
               slipProcedure;

            -- Check for out-of-sync flag
            elsif (linkOutOfSync = '1') then

               -- Slip by 1-bit in the gearbox
               v.bitSlip := '1';

               -- Reset the counter
               v.slipWaitCnt := 0;

               -- Next state
               v.state := BIT_WAIT_S;

            -- Check the counter
            elsif (r.slipWaitCnt = SLIP_WAIT_C-1) then

               -- Reset the counter
               v.slipWaitCnt := 0;

               -- Next state
               v.state := LOCKED_S;

            else

               -- Increment the counter
               v.slipWaitCnt := r.slipWaitCnt + 1;

            end if;
         ----------------------------------------------------------------------
         when LOCKED_S =>
            -- Check for data
            if (valid = '1') then

               -- Check for bad header
               if (v.errorDet = '1') then
                  -- Execute the slip procedure
                  slipProcedure;

               else
                  -- Set the flag
                  v.locked := '1';
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Keep a delayed copy
      v.enUsrDlyCfg := enUsrDlyCfg;
      v.usrDlyCfg   := usrDlyCfg;

      -- Check for changes in enUsrDlyCfg values or usrDlyCfg values or dlyConfig value
      if (r.enUsrDlyCfg /= v.enUsrDlyCfg) or (r.usrDlyCfg /= v.usrDlyCfg) or (r.dlyConfig /= v.dlyConfig) then
         -- Update the RX IDELAY configuration
         v.dlyLoad(1) := '1';
      end if;

      -- Outputs
      eyeWidth <= r.eyeWidth;
      locked   <= r.locked;
      bitSlip  <= r.bitSlip;
      dlyLoad  <= r.dlyLoad(0);
      errorDet <= r.errorDet;

      -- Check if using user delay configuration
      if (r.enUsrDlyCfg = '1') then
         -- Force to user configuration
         dlyCfg <= usrDlyCfg;
      else
         -- Else use the automatic value
         dlyCfg <= r.dlyConfig;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
