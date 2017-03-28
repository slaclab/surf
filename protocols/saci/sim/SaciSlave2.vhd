-------------------------------------------------------------------------------
-- File       : SaciSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-07-12
-- Last update: 2013-03-05
-------------------------------------------------------------------------------
-- Description: Slave module for SACI interface.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

entity SaciSlave2 is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    rstL : in sl;                       -- ASIC global reset

    -- Serial Interface
    saciClk  : in  sl;
    saciSelL : in  sl;                  -- chipSelect
    saciCmd  : in  sl;
    saciRsp  : out sl;

    -- Silly reset hack to get saciSelL | rst onto dedicated reset bar
    rstOutL : out sl;
    rstInL  : in  sl;

    -- Detector (Parallel) Interface
    exec   : out sl;
    ack    : in  sl;
    readL  : out sl;
    cmd    : out slv(6 downto 0);
    addr   : out slv(11 downto 0);
    wrData : out slv(31 downto 0);
    rdData : in  slv(31 downto 0));

end entity SaciSlave2;

architecture rtl of SaciSlave2 is

  type StateType is (WAIT_START_S, SHIFT_IN_S);

  type RegType is record
    shiftReg : slv(54 downto 0);
    state    : StateType;
    exec     : sl;
    readL    : sl;
  end record RegType;

  signal r, rin      : RegType;
  signal saciCmdFall : sl;

  procedure shiftInLeft (
    i : in    sl;
    v : inout slv) is
  begin
    v := v(v'high-1 downto v'low) & i;
  end procedure shiftInLeft;

begin

  -- Chip select also functions as async reset
  rstOutL <= rstL and not saciSelL;


  -- Clock in serial input on falling edge
  fall : process (saciClk, rstInL) is
  begin
    if (rstInL = '0') then
      saciCmdFall <= '0' after TPD_G;
    elsif (falling_edge(saciClk)) then
      saciCmdFall <= saciCmd after TPD_G;
    end if;
  end process fall;


  seq : process (saciClk, rstInL) is
  begin
    if (rstInL = '0') then
      r.shiftReg <= (others => '0') after TPD_G;
      r.state    <= WAIT_START_S    after TPD_G;
      r.exec     <= '0'             after TPD_G;
      r.readL    <= '0'             after TPD_G;
    elsif (rising_edge(saciClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r, saciCmdFall, ack, rdData, saciSelL) is
    variable v : RegType;
  begin
    v := r;

    shiftInLeft(saciCmdFall, v.shiftReg);

    -- Main state machine
    case (r.state) is

      when WAIT_START_S =>

        -- Shift data out and look for next start bit
        if (r.shiftReg(0) = '1') then
          v.state := SHIFT_IN_S;
        end if;

      when SHIFT_IN_S =>
        -- Wait for start bit to shift all the way in then assert exec and readL
        if (r.shiftReg(52) = '1') then
          v.exec  := '1';
          v.readL := r.shiftReg(51);
        end if;

        if (r.exec = '1') then
          v.shiftReg := r.shiftReg;     -- Pause shifting when exec high
          v.readL    := r.readL;
        end if;

        if (ack = '1') then
          v.exec  := '0';
          v.state := WAIT_START_S;
          if (r.shiftReg(52) = '1') then
            v.shiftReg(32 downto 1) := (others => '0');  -- write
          else
            v.shiftReg(32 downto 1) := rdData;           -- read
          end if;
        end if;
        

      when others =>
        v.shiftReg := (others => '0');
        v.state    := WAIT_START_S;
        v.exec     := '0';
        v.readL    := '0';

    end case;


    rin <= v;

    -- Assign outputs from registers
    exec    <= r.exec;
    readL   <= r.readL;
    saciRsp <= r.shiftReg(54);          -- 52 = start, 51 = r/w at time of exec
    cmd     <= r.shiftReg(51 downto 45);
    addr    <= r.shiftReg(44 downto 33);
    wrData  <= r.shiftReg(32 downto 1);

  end process comb;


end architecture rtl;

