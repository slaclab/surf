library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package EvrV1Pkg is

   type EvrV1StatusType is record      
      tsFifoTsLow     : slv(31 downto 0);
      tsFifoTsHigh    : slv(31 downto 0);
      tsFifoEventCode : slv(7 downto 0);
      tsFifoValid     : sl;
      tsFifoNext      : sl;
      tsFifoWrCnt     : slv(8 downto 0);
      eventRamReset   : Slv32Array(1 downto 0);
      eventRamSet     : Slv32Array(1 downto 0);
      eventRamPulse   : Slv32Array(1 downto 0);
      eventRamInt     : Slv32Array(1 downto 0);
      intFlag         : slv(31 downto 0);
      dbrx            : sl;
      dbrdy           : sl;
      dbcs            : sl;
      rxSize          : slv(11 downto 0);
      dbData          : slv(31 downto 0);
      dbInt           : sl;
      dbIntEna        : sl;
   end record;

   type EvrV1ConfigType is record
      pulseControl  : Slv32Array(11 downto 0);
      pulsePrescale : Slv32Array(11 downto 0);
      pulseDelay    : Slv32Array(11 downto 0);
      pulseWidth    : Slv32Array(11 downto 0);
      tsFifoRdEna   : sl;
      eventRamData  : slv(31 downto 0);
      eventRamCs    : Slv4Array(1 downto 0);
      eventRamAddr  : slv(7 downto 0);
      eventRamWe    : Slv4Array(1 downto 0);
      mapRamPage    : sl;
      evrEnable     : sl;
      outputMap     : Slv16Array(11 downto 0);
      uSecDivider   : slv(31 downto 0);
      intControl    : slv(31 downto 0);
      dbena         : sl;
      dbdis         : sl;
      dben          : sl;
      dbRdAddr      : slv(8 downto 0);
      irqClr        : slv(31 downto 0);
      intEventEn    : sl;
      extEventEn    : sl;
      intEventCode  : slv(7 downto 0);
      extEventCode  : slv(7 downto 0);
      intEventCount : slv(31 downto 0);
   end record;
   constant EVR_V1_CONFIG_INIT_C : EvrV1ConfigType := (
      pulseControl  => (others => (others => '0')),
      pulsePrescale => (others => (others => '0')),
      pulseDelay    => (others => (others => '0')),
      pulseWidth    => (others => (others => '0')),
      tsFifoRdEna   => '0',
      eventRamData  => (others => '0'),
      eventRamCs    => (others => (others => '0')),
      eventRamAddr  => (others => '0'),
      eventRamWe    => (others => (others => '0')),
      mapRamPage    => '0',
      evrEnable     => '0',
      outputMap     => (others => (others => '0')),
      uSecDivider   => (others => '0'),
      intControl    => (others => '0'),
      dbena         => '0',
      dbdis         => '0',
      dben          => '0',
      dbRdAddr      => (others => '0'),
      irqClr        => (others => '0'),
      intEventEn    => '0',
      extEventEn    => '0',
      intEventCode  => (others => '0'),
      extEventCode  => (others => '0'),
      intEventCount => (others => '0')); 

end package;
