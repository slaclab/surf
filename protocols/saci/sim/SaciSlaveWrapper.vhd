-------------------------------------------------------------------------------
-- File       : SaciSlaveWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-17
-- Last update: 2016-06-17
-------------------------------------------------------------------------------
-- Description: Simulation testbed for SaciSlaveWrapper
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

entity SaciSlaveWrapper is
  generic (
    TPD_G : time := 1 ns);
  port (
    asicRstL : in  sl;
    saciClk  : in  sl;
    saciSelL : in  sl;                  -- chipSelect
    saciCmd  : in  sl;
    saciRsp  : out sl);

end entity SaciSlaveWrapper;

architecture rtl of SaciSlaveWrapper is
  
  signal saciSlaveRstL : sl;
  signal exec          : sl;
  signal ack           : sl;
  signal readL         : sl;
  signal cmd           : slv(6 downto 0);
  signal addr          : slv(11 downto 0);
  signal wrData        : slv(31 downto 0);
  signal rdData        : slv(31 downto 0);
  signal saciRspInt : sl;
  
begin

  saciRsp <= saciRspInt when saciSelL = '0' else 'Z';

  SaciSlave_i : entity work.SaciSlave2
    generic map (
      TPD_G => TPD_G)
    port map (
      rstL     => asicRstL,
      saciClk  => saciClk,
      saciSelL => saciSelL,
      saciCmd  => saciCmd,
      saciRsp  => saciRspInt,
      rstOutL  => saciSlaveRstL,
      rstInL   => saciSlaveRstL,
      exec     => exec,
      ack      => ack,
      readL    => readL,
      cmd      => cmd,
      addr     => addr,
      wrData   => wrData,
      rdData   => rdData);

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
