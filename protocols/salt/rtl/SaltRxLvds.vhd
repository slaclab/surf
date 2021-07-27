-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SALT TX Engine Module
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
use surf.Code8b10bPkg.all;

entity SaltRxLvds is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      SIM_DEVICE_G    : string  := "ULTRASCALE";
      IODELAY_GROUP_G : string  := "SALT_GROUP";
      REF_FREQ_G      : real    := 200.0);  -- IDELAYCTRL's REFCLK (in units of Hz)
   port (
      -- Clocks and Resets
      clk125MHz      : in  sl;
      rst125MHz      : in  sl;
      clk156MHz      : in  sl;
      rst156MHz      : in  sl;
      clk625MHz      : in  sl;
      -- GMII Interface
      rxEn           : out sl;
      rxErr          : out sl;
      rxData         : out slv(7 downto 0);
      rxLinkUp       : out sl;
      -- Configuration Interface
      enUsrDlyCfg    : in  sl               := '0';  -- Enable User delay config
      usrDlyCfg      : in  slv(8 downto 0)  := (others => '0');  -- User delay config
      bypFirstBerDet : in  sl               := '1';  -- Set to '1' if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns "1Gb/s" )
      minEyeWidth    : in  slv(7 downto 0)  := toSlv(80, 8);  -- Sets the minimum eye width required for locking (units of IDELAY step)
      lockingCntCfg  : in  slv(23 downto 0) := ite(SIMULATION_G, x"00_0064", x"00_FFFF");  -- Number of error-free event before state=LOCKED_S
      -- LVDS RX Port
      rxP            : in  sl;
      rxN            : in  sl);
end SaltRxLvds;

architecture rtl of SaltRxLvds is

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      rxEn   : sl;
      rxErr  : sl;
      rxData : slv(7 downto 0);
      state  : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      rxEn   => '0',
      rxErr  => '0',
      rxData => (others => '0'),
      state  => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dlyLoad : sl;
   signal dlyCfg  : slv(8 downto 0);

   signal data8b  : slv(7 downto 0);
   signal data10b : slv(9 downto 0);

   signal data      : slv(7 downto 0);
   signal dataK     : sl;
   signal codeError : sl;
   signal dispError : sl;
   signal slip      : sl;
   signal linkUp    : sl;

   signal enUsrDlyCfgSync    : sl;
   signal usrDlyCfgSync      : slv(8 downto 0);
   signal bypFirstBerDetSync : sl;
   signal minEyeWidthSync    : slv(7 downto 0);
   signal lockingCntCfgSync  : slv(23 downto 0);


begin

   rxLinkUp <= linkUp;

   U_SaltRxDeser : entity surf.SaltRxDeser
      generic map (
         TPD_G           => TPD_G,
         SIM_DEVICE_G    => SIM_DEVICE_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         REF_FREQ_G      => REF_FREQ_G)
      port map (
         -- SELECTIO Ports
         rxP     => rxP,
         rxN     => rxN,
         -- Clock and Reset Interface
         clkx4   => clk625MHz,
         clkx1   => clk156MHz,
         rstx1   => rst156MHz,
         -- Delay Configuration
         dlyLoad => dlyLoad,
         dlyCfg  => dlyCfg,
         -- Output
         dataOut => data8b);

   U_Gearbox : entity surf.AsyncGearbox
      generic map (
         TPD_G                => TPD_G,
         SLAVE_WIDTH_G        => 8,
         MASTER_WIDTH_G       => 10,
         -- Pipelining generics
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0,
         -- Async FIFO generics
         FIFO_MEMORY_TYPE_G   => "distributed",
         FIFO_ADDR_WIDTH_G    => 5)
      port map (
         -- Slave Interface
         slaveClk    => clk156MHz,
         slaveRst    => rst156MHz,
         slaveData   => data8b,
         slaveValid  => '1',
         slaveReady  => open,
         -- sequencing and slip (ASYNC input)
         slip        => slip,
         -- Master Interface
         masterClk   => clk125MHz,
         masterRst   => rst125MHz,
         masterData  => data10b,
         masterValid => open,
         masterReady => '1');

   U_decoder : entity surf.Decoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => 1,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false)
      port map (
         clk         => clk125MHz,
         rst         => rst125MHz,
         dataIn      => data10b,
         dataOut     => data,
         dataKOut(0) => dataK,
         codeErr(0)  => codeError,
         dispErr(0)  => dispError);

   U_GearboxAligner : entity surf.SelectIoRxGearboxAligner
      generic map (
         TPD_G        => TPD_G,
         CODE_TYPE_G  => "LINE_CODE",
         SIMULATION_G => SIMULATION_G)
      port map (
         -- Clock and Reset
         clk             => clk125MHz,
         rst             => rst125MHz,
         -- Line-Code Interface (CODE_TYPE_G = "LINE_CODE")
         lineCodeValid   => '1',
         lineCodeErr     => codeError,
         lineCodeDispErr => dispError,
         linkOutOfSync   => '0',
         -- 64b/66b Interface (CODE_TYPE_G = "SCRAMBLER")
         rxHeaderValid   => '0',
         rxHeader        => (others => '0'),
         -- Link Status and Gearbox Slip
         bitSlip         => slip,
         -- IDELAY (DELAY_TYPE="VAR_LOAD") Interface
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- Configuration Interface
         enUsrDlyCfg     => enUsrDlyCfgSync,
         usrDlyCfg       => usrDlyCfgSync,
         bypFirstBerDet  => bypFirstBerDetSync,
         minEyeWidth     => minEyeWidthSync,
         lockingCntCfg   => lockingCntCfgSync,
         -- Status Interface
         errorDet        => open,
         locked          => linkUp);

   U_SyncConfig : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 43)
      port map (
         clk                   => clk125MHz,
         -- Input
         dataIn(23 downto 0)   => lockingCntCfg,
         dataIn(31 downto 24)  => minEyeWidth,
         dataIn(40 downto 32)  => usrDlyCfg,
         dataIn(41)            => enUsrDlyCfg,
         dataIn(42)            => bypFirstBerDet,
         -- Output
         dataOut(23 downto 0)  => lockingCntCfgSync,
         dataOut(31 downto 24) => minEyeWidthSync,
         dataOut(40 downto 32) => usrDlyCfgSync,
         dataOut(41)           => enUsrDlyCfgSync,
         dataOut(42)           => bypFirstBerDetSync);

   comb : process (data, dataK, linkUp, r, rst125MHz) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Init
            v.rxEn   := '0';
            v.rxData := x"00";
            -- Check for Start_of_Packet
            if (dataK = '1') and (data = K_27_7_C) then
               -- Next state
               v.state := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if moving data
            if (dataK = '0') then
               -- Move data
               v.rxEn   := '1';
               v.rxData := data;
            else
               -- Init
               v.rxEn   := '0';
               v.rxData := x"00";
               -- Next state
               v.state  := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxEn   <= r.rxEn;
      rxErr  <= r.rxErr;
      rxData <= r.rxData;

      -- Reset
      if (rst125MHz = '1') or (linkUp = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk125MHz) is
   begin
      if rising_edge(clk125MHz) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
