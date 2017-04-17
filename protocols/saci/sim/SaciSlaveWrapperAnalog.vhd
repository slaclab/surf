-------------------------------------------------------------------------------
-- File       : SaciSlaveWrapperAnalog.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-17
-- Last update: 2016-06-17
-------------------------------------------------------------------------------
-- Description: Simulation testbed for SaciSlaveWrapperAnalog
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
use work.StdRtlPkg.all;

entity SaciSlaveWrapperAnalog is
  generic (
    TPD_G : time := 1 ns);
  port (
    asicRstL : in  sl;
    saciClk  : in  sl;
    saciSelL : in  sl;                  -- chipSelect
    saciCmd  : in  sl;
    saciRsp  : out sl);

end entity SaciSlaveWrapperAnalog;

architecture rtl of SaciSlaveWrapperAnalog is
  
  signal saciSlaveRstL : sl;
  signal exec          : sl;
  signal ack           : sl;
  signal readL         : sl;
  signal cmd           : slv(6 downto 0);
  signal addr          : slv(11 downto 0);
  signal wrData        : slv(31 downto 0);
  signal rdData        : slv(31 downto 0);
  signal saciRspInt    : sl;
  
begin

  saciRsp <= saciRspInt when saciSelL = '0' else 'Z';

  SaciSlave_i : entity work.SaciSlaveAnalog
    port map (
      rstL      => asicRstL,
      CLK       => saciClk,
      saciSelL  => saciSelL,
      saciCmd   => saciCmd,
      saciRsp   => saciRspInt,
      rstOutL   => saciSlaveRstL,
      RST       => saciSlaveRstL,
      exec      => exec,
      ack       => ack,
      readL     => readL,
      cmd_0     => cmd(0),
      cmd_1     => cmd(1),
      cmd_2     => cmd(2),
      cmd_3     => cmd(3),
      cmd_4     => cmd(4),
      cmd_5     => cmd(5),
      cmd_6     => cmd(6),
      addr_0    => addr(0),
      addr_1    => addr(1),
      addr_2    => addr(2),
      addr_3    => addr(3),
      addr_4    => addr(4),
      addr_5    => addr(5),
      addr_6    => addr(6),
      addr_7    => addr(7),
      addr_8    => addr(8),
      addr_9    => addr(9),
      addr_10   => addr(10),
      addr_11   => addr(11),
      wrData_0  => wrData(0),
      wrData_1  => wrData(1),
      wrData_2  => wrData(2),
      wrData_3  => wrData(3),
      wrData_4  => wrData(4),
      wrData_5  => wrData(5),
      wrData_6  => wrData(6),
      wrData_7  => wrData(7),
      wrData_8  => wrData(8),
      wrData_9  => wrData(9),
      wrData_10 => wrData(10),
      wrData_11 => wrData(11),
      wrData_12 => wrData(12),
      wrData_13 => wrData(13),
      wrData_14 => wrData(14),
      wrData_15 => wrData(15),
      wrData_16 => wrData(16),
      wrData_17 => wrData(17),
      wrData_18 => wrData(18),
      wrData_19 => wrData(19),
      wrData_20 => wrData(20),
      wrData_21 => wrData(21),
      wrData_22 => wrData(22),
      wrData_23 => wrData(23),
      wrData_24 => wrData(24),
      wrData_25 => wrData(25),
      wrData_26 => wrData(26),
      wrData_27 => wrData(27),
      wrData_28 => wrData(28),
      wrData_29 => wrData(29),
      wrData_30 => wrData(30),
      wrData_31 => wrData(31),
      rdData_0  => rdData(0),
      rdData_1  => rdData(1),
      rdData_2  => rdData(2),
      rdData_3  => rdData(3),
      rdData_4  => rdData(4),
      rdData_5  => rdData(5),
      rdData_6  => rdData(6),
      rdData_7  => rdData(7),
      rdData_8  => rdData(8),
      rdData_9  => rdData(9),
      rdData_10 => rdData(10),
      rdData_11 => rdData(11),
      rdData_12 => rdData(12),
      rdData_13 => rdData(13),
      rdData_14 => rdData(14),
      rdData_15 => rdData(15),
      rdData_16 => rdData(16),
      rdData_17 => rdData(17),
      rdData_18 => rdData(18),
      rdData_19 => rdData(19),
      rdData_20 => rdData(20),
      rdData_21 => rdData(21),
      rdData_22 => rdData(22),
      rdData_23 => rdData(23),
      rdData_24 => rdData(24),
      rdData_25 => rdData(25),
      rdData_26 => rdData(26),
      rdData_27 => rdData(27),
      rdData_28 => rdData(28),
      rdData_29 => rdData(29),
      rdData_30 => rdData(30),
      rdData_31 => rdData(31));


  SaciSlaveRam_1 : entity work.SaciSlaveRam
    port map (
      saciClkOut => saciClk,
      exec       => exec,
      ack        => ack,
      readL      => readL,
      cmd        => cmd,
      addr       => addr,
      wrData     => wrData,
      rdData     => rdData);

end architecture rtl;
