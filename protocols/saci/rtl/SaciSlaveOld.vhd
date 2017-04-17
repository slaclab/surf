-------------------------------------------------------------------------------
-- File       : SaciSlaveOld.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-07-12
-- Last update: 2016-06-17
-------------------------------------------------------------------------------
-- Description: Slave module for SACI interface. Legacy (bloated) version.
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

entity SaciSlaveOld is
  
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

end entity SaciSlaveOld;

architecture rtl of SaciSlaveOld is

  type StateType is (IDLE_S,
                     SHIFT_HEADER_IN_S,
                     SHIFT_DATA_IN_S,
                     EXEC_S,
                     SHIFT_HEADER_OUT_S,
                     SHIFT_DATA_OUT_S);

  type RegType is record
    headerShiftReg : slv(20 downto 0);
    dataShiftReg   : slv(31 downto 0);
    shiftCount     : unsigned(5 downto 0);
    state          : StateType;
    exec           : sl;
    writeFlag      : sl;
    saciRsp        : sl;
  end record RegType;

  signal r, rin      : RegType;
  signal saciCmdFall : sl;

  procedure shiftInLeft (
    i : in  sl;
    r : in  slv;
    v : out slv) is
  begin
    if (r'ascending) then
      v := r(r'low+1 to r'high) & i;
    else
      v := r(r'high-1 downto r'low) & i;
    end if;
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
      r.headerShiftReg <= (others => '0') after TPD_G;
      r.dataShiftReg   <= (others => '0') after TPD_G;
      r.shiftCount     <= (others => '0') after TPD_G;
      r.state          <= IDLE_S          after TPD_G;
      r.exec           <= '0'             after TPD_G;
      r.writeFlag      <= '0'             after TPD_G;
      r.saciRsp        <= '0'             after TPD_G;
    elsif (rising_edge(saciClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r, saciCmdFall, ack, rdData, saciSelL) is
    variable rVar : RegType;
  begin
    rVar := r;

    -- Defualt values
    -- Overridden in some states
    rVar.exec    := '0';
    rVar.saciRsp := '0';

    -- Main state machine
    case (r.state) is
      
      when IDLE_S =>
        -- Shift in bits until a start bit is seen
        shiftInLeft(saciCmdFall, r.headerShiftReg, rVar.headerShiftReg);
        rVar.shiftCount := (others => '0');
        rVar.dataShiftReg := (others => '0');
        if (saciCmdFall = '1') then
          rVar.state := SHIFT_HEADER_IN_S;
        end if;

      when SHIFT_HEADER_IN_S =>
        -- Shift in the header
        shiftInLeft(saciCmdFall, r.headerShiftReg, rVar.headerShiftReg);
        rVar.shiftCount := r.shiftCount + 1;
        if (r.shiftCount = 19) then
          -- Header rx'd, check r/w bit
          rVar.writeFlag  := r.headerShiftReg(18);
          rVar.shiftCount := (others => '0');
          if (r.headerShiftReg(18) = '1') then  -- r/w bit will be at index 19 when frozen
            -- Write
            rVar.state := SHIFT_DATA_IN_S;
          else
            -- Read
            rVar.state := EXEC_S;
          end if;
        end if;

      when SHIFT_DATA_IN_S =>
        -- Write being performed, shift in write data
        shiftInLeft(saciCmdFall, r.dataShiftReg, rVar.dataShiftReg);
        rVar.shiftCount := r.shiftCount + 1;
        if (r.shiftCount = 31) then
          rVar.state := EXEC_S;
        end if;

      when EXEC_S =>
        -- Do exec/ack cycle
        rVar.exec         := '1';
        rVar.shiftCount   := (others => '0');
        if (ack = '1') then
          rVar.dataShiftReg := rdData;
          rVar.state := SHIFT_HEADER_OUT_S;
        end if;

      when SHIFT_HEADER_OUT_S =>
        -- Always send back the header, even on writes, as an ack to the other side
        rVar.shiftCount := r.shiftCount + 1;
        rVar.saciRsp    := r.headerShiftReg(20);
        -- Technically shifting out but its the same
        -- Any saciCmd data shifted in here will be ignored (but there shouldn't be any)
        shiftInLeft(saciCmdFall, r.headerShiftReg, rVar.headerShiftReg);
        if (r.shiftCount = 20) then
          rVar.shiftCount := (others => '0');
          if (r.writeFlag = '1') then
            -- Done
            rVar.state := IDLE_S;
          else
            -- Must now send read data back
            rVar.state := SHIFT_DATA_OUT_S;
          end if;

        end if;

      when SHIFT_DATA_OUT_S =>
        -- Read being performed, the read data obtained during EXEC_S
        rVar.shiftCount := r.shiftCount + 1;
        rVar.saciRsp    := r.dataShiftReg(31);
        shiftInLeft(saciCmdFall, r.dataShiftReg, rVar.dataShiftReg);
        if (r.shiftCount = 32) then
          rVar.state := IDLE_S;
        end if;

      when others =>
        rVar.headerShiftReg := (others => '0');
        rVar.dataShiftReg   := (others => '0');
        rVar.shiftCount     := (others => '0');
        rVar.state          := IDLE_S;
        rVar.exec           := '0';
        rVar.writeFlag      := '0';
        rVar.saciRsp        := '0';

    end case;


    rin     <= rVar;

    -- Assign outputs from registers
    exec    <= r.exec;
    readL   <= r.writeFlag;
    cmd     <= r.headerShiftReg(18 downto 12);
    addr    <= r.headerShiftReg(11 downto 0);
    wrData  <= r.dataShiftReg;
    saciRsp <= r.saciRsp;

  end process comb;

--  data    <= r.dataShiftReg when r.writeFlag = '1' else (others => 'Z');
--  saciRsp <= r.saciRsp      when saciSelL = '0'    else 'Z';

end architecture rtl;

