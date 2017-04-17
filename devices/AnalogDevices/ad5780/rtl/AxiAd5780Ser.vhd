-------------------------------------------------------------------------------
-- File       : AxiAd5780Ser.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-25
-------------------------------------------------------------------------------
-- Description: AD5780 DAC Module's serializer
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

use work.StdRtlPkg.all;
use work.AxiAd5780Pkg.all;

entity AxiAd5780Ser is
   generic (
      TPD_G          : time := 1 ns;
      AXI_CLK_FREQ_G : real := 200.0E+6);    -- units of Hz      
   port (
      -- DAC Ports
      dacIn         : in  AxiAd5780InType;
      dacOut        : out AxiAd5780OutType;
      -- DAC Data Interface (axiClk domain)
      halfSckPeriod : in  slv(31 downto 0);
      sdoDisable    : in  sl;
      binaryOffset  : in  sl;
      dacTriState   : in  sl;
      opGnd         : in  sl;
      rbuf          : in  sl;
      dacData       : in  slv(17 downto 0);  -- 2's complement by default
      dacUpdated    : out sl;
      -- Clocks and Resets
      axiClk        : in  sl;
      axiRst        : in  sl;
      dacRst        : in  sl); 
end AxiAd5780Ser;

architecture rtl of AxiAd5780Ser is

   constant CS_WAIT_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, 20.0E+6));  -- 50 ns wait min.

   type StateType is (
      RST_S,
      RST_WAIT_S,
      SCK_HIGH_S,
      SCK_LOW_S,
      CS_HI_S);
   type RegType is record
      rstL       : sl;
      csL        : sl;
      sck        : sl;
      sdi        : sl;
      dacUpdated : sl;
      cnt        : slv(7 downto 0);
      cntSck     : slv(31 downto 0);
      csWait     : natural range 0 to CS_WAIT_C;
      reg        : slv(23 downto 0);
      state      : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      '0',
      '1',
      '1',
      '1',
      '0',
      (others => '0'),
      (others => '0'),
      0,
      (others => '0'),
      RST_S); 
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (binaryOffset, dacData, dacRst, dacTriState, halfSckPeriod, opGnd, r, rbuf,
                   sdoDisable) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.dacUpdated := '0';

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when RST_S =>
            -- Increment counter
            v.cntSck := r.cntSck + 1;
            if r.cntSck = 255 then
               -- Reset the counter
               v.cntSck := (others => '0');
               -- Increment counter
               v.cnt    := r.cnt + 1;
               if r.cnt = 255 then
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Release the Reset
                  v.rstL  := '1';
                  -- Next state
                  v.state := RST_WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RST_WAIT_S =>
            -- Preset the serial bit
            v.sdi    := '0';
            -- Increment counter
            v.cntSck := r.cntSck + 1;
            if r.cntSck = 255 then
               -- Reset the counter
               v.cntSck := (others => '0');
               -- Increment counter
               v.cnt    := r.cnt + 1;
               if r.cnt = 255 then
                  -- Reset the counter
                  v.cnt               := (others => '0');
                  -- Configure the DAC
                  v.reg(23 downto 20) := "0010";       -- CTRL_REG: write to control register
                  v.reg(19 downto 6)  := (others => '0');  -- Reserved: reserved should be set to zero
                  -- Configuration bits
                  v.reg(5)            := sdoDisable;   -- SDODIS: disable SDO
                  v.reg(4)            := binaryOffset;     -- BIN/2sC: use 2's complement
                  v.reg(3)            := dacTriState;  -- DACTRI: put DAC into normal operating mode
                  v.reg(2)            := opGnd;        -- OPGND: put DAC into normal operating mode
                  v.reg(1)            := rbuf;         -- RBUF: Unity-Gain Configuration 
                  v.reg(0)            := '0';  -- Reserved: reserved should be set to zero             
                  -- Set the chip select flag
                  v.csL               := '0';
                  -- Preset the counter
                  v.cntSck            := halfSckPeriod;
                  -- Next state
                  v.state             := SCK_HIGH_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SCK_HIGH_S =>
            -- High phase of SCK
            v.sck    := '1';
            -- Set the serial bit
            v.sdi    := r.reg(23);
            -- Increment counter
            v.cntSck := r.cntSck + 1;
            if r.cntSck = halfSckPeriod then
               if r.cnt = 23 then
                  -- Preset the counter
                  v.cntSck := halfSckPeriod;
               else
                  -- Reset the counter
                  v.cntSck := (others => '0');
               end if;
               -- Next state
               v.state := SCK_LOW_S;
            end if;
         ----------------------------------------------------------------------
         when SCK_LOW_S =>
            -- Low phase of SCK
            v.sck    := '0';
            -- Increment counter
            v.cntSck := r.cntSck + 1;
            if r.cntSck = halfSckPeriod then
               -- Reset the counter
               v.cntSck           := (others => '0');
               -- Shift Register
               v.reg(23 downto 1) := r.reg(22 downto 0);
               v.reg(0)           := '0';
               -- Increment counter
               v.cnt              := r.cnt + 1;
               if r.cnt = 23 then
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next state
                  v.state := CS_HI_S;
               else
                  -- Next state
                  v.state := SCK_HIGH_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CS_HI_S =>
            -- High phase of SCK
            v.sck    := '1';
            -- Release the chip select
            v.csL    := '1';
            -- Preset the serial bit
            v.sdi    := '0';
            -- Increment counter
            v.csWait := r.csWait + 1;
            if r.csWait = CS_WAIT_C then
               -- Reset the counter
               v.csWait     := 0;
               -- Latch the DAC data
               v.reg        := "0001" & dacData & "00";
               -- Set the chip select flag
               v.csL        := '0';
               -- Preset the counter
               v.cntSck     := halfSckPeriod;
               -- Strobe the refresh flag
               v.dacUpdated := '1';
               -- Next state
               v.state      := SCK_HIGH_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if dacRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dacUpdated <= r.dacUpdated;

      dacOut.dacSync <= r.csL;
      dacOut.dacSclk <= r.sck;
      dacOut.dacSdi  <= r.sdi;
      dacOut.dacLdac <= '0';
      dacOut.dacClr  <= '1';
      dacOut.dacRst  <= r.rstL;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
