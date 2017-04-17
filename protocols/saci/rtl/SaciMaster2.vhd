-------------------------------------------------------------------------------
-- File       : SaciMaster2.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-08-10
-- Last update: 2016-06-17
-------------------------------------------------------------------------------
-- Description: New and improved version of the SaciMaster.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity SaciMaster2 is

   generic (
      TPD_G              : time     := 1 ns;
      SYS_CLK_PERIOD_G   : real     := 8.0e-9;
      SACI_CLK_PERIOD_G  : real     := 1.0e-6;
      SACI_CLK_FREERUN_G : boolean  := false;
      SACI_NUM_CHIPS_G   : positive := 1;
      SACI_RSP_BUSSED_G  : boolean  := false);
   port (
      sysClk : in sl;                   -- Main clock
      sysRst : in sl;

      -- Request interface
      req    : in  sl;
      ack    : out sl;
      fail   : out sl;
      chip   : in  slv(log2(SACI_NUM_CHIPS_G)-1 downto 0);
      op     : in  sl;
      cmd    : in  slv(6 downto 0);
      addr   : in  slv(11 downto 0);
      wrData : in  slv(31 downto 0);
      rdData : out slv(31 downto 0);

      -- Serial interface
      saciClk  : out sl;
      saciSelL : out slv(SACI_NUM_CHIPS_G-1 downto 0);
      saciCmd  : out sl;
      saciRsp  : in  slv(ite(SACI_RSP_BUSSED_G, 0, SACI_NUM_CHIPS_G-1) downto 0));


end entity SaciMaster2;

architecture rtl of SaciMaster2 is

   constant SACI_CLK_HALF_PERIOD_C  : integer := integer(SACI_CLK_PERIOD_G / (2.0*SYS_CLK_PERIOD_G))-1;
   constant SACI_CLK_COUNTER_SIZE_C : integer := log2(SACI_CLK_HALF_PERIOD_C);

   type StateType is (IDLE_S, TX_S, RX_START_S, RX_HEADER_S, RX_DATA_S, ACK_S);

   type RegType is record
      state      : StateType;
      shiftReg   : slv(52 downto 0);
      shiftCount : slv(5 downto 0);

      --Saci clk gen
      clkCount       : slv(SACI_CLK_COUNTER_SIZE_C-1 downto 0);
      saciClkRising  : sl;
      saciClkFalling : sl;

      -- System Outputs
      ack    : sl;
      fail   : sl;
      rdData : slv(31 downto 0);

      -- SACI Outputs
      saciClk  : sl;
      saciSelL : slv(SACI_NUM_CHIPS_G-1 downto 0);
      saciCmd  : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      shiftReg       => (others => '0'),
      shiftCount     => (others => '0'),
      clkCount       => (others => '0'),
      saciClkRising  => '0',
      saciClkFalling => '0',
      ack            => '0',
      fail           => '0',
      rdData         => (others => '0'),
      saciClk        => '0',
      saciSelL       => (others => '1'),
      saciCmd        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal saciRspSync : slv(saciRsp'range);

begin

   -------------------------------------------------------------------------------------------------
   -- Synchronize saciRsp to sysClk
   -------------------------------------------------------------------------------------------------
   RSP_SYNC : for i in saciRsp'range generate
      U_Synchronizer_1 : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => sysClk,           -- [in]
            rst     => sysRst,           -- [in]
            dataIn  => saciRsp(i),       -- [in]
            dataOut => saciRspSync(i));  -- [out]
   end generate RSP_SYNC;

   -------------------------------------------------------------------------------------------------
   -- Main logic
   -------------------------------------------------------------------------------------------------
   comb : process (addr, chip, cmd, op, r, req, saciRspSync, sysRst, wrData) is
      variable v        : RegType;
      variable rspIndex : integer;
   begin
      v := r;

      -- Default values
      v.ack        := '0';
      rspIndex     := ite(SACI_RSP_BUSSED_G, 0, conv_integer(chip));

      -- Run the saciClk
      v.clkCount := r.clkCount + 1;
      if (r.clkCount = SACI_CLK_HALF_PERIOD_C) then
         v.saciClk  := not r.saciClk;
         v.clkCount := (others => '0');
      end if;

      -- Create saciClk edge strobes
      v.saciClkRising  := '0';
      v.saciClkFalling := '0';
      if (r.clkCount = SACI_CLK_HALF_PERIOD_C-1) then
         if (r.saciClk = '0') then
            v.saciClkRising := '1';
         end if;
         if (r.saciClk = '1') then
            v.saciClkFalling := '1';
         end if;
      end if;

      case (r.state) is
         when IDLE_S =>
            v.fail       := '0';
            v.shiftReg   := (others => '0');
            v.shiftCount := (others => '0');
            v.saciSelL   := (others => '1');
            -- Hold clock inactive while idle
            -- Make this configurable?
            if (not SACI_CLK_FREERUN_G) then
               v.saciClk  := '0';
               v.clkCount := (others => '0');
            end if;

            -- Start new command on the falling edge of saciClk
            -- If clock is not freerunning then start right away
            if (req = '1' and r.saciClk = '0' and r.clkCount = 0) then
               -- New command, load shift reg
               v.shiftReg(52)           := '1';  -- Start bit
               v.shiftReg(51)           := op;
               v.shiftReg(50 downto 44) := cmd;
               v.shiftReg(43 downto 32) := addr;
               if (op = '1') then
                  v.shiftReg(31 downto 0) := wrData;
               else
                  v.shiftReg(31 downto 0) := (others => '0');
               end if;
               -- Assert saciSelL line
               v.saciSelL := not decode(chip)(SACI_NUM_CHIPS_G-1 downto 0);
               v.state    := TX_S;
            end if;

         when TX_S =>
            -- Shift out data on rising edge of saciClk
            if r.saciClkRising = '1' then
               v.saciCmd    := r.shiftReg(52);
               v.shiftReg   := r.shiftReg(51 downto 0) & '0';
               v.shiftCount := r.shiftCount + 1;
            end if;

            if (op = '0' and r.shiftCount = 21) then     -- Read
               v.state := RX_START_S;
            elsif (op = '1' and r.shiftCount = 53) then  -- Write
               v.state := RX_START_S;
            end if;


         when RX_START_S =>
            -- Clear last saciCmd on rising edge of saciCLk
            if (r.saciClkRising = '1') then
               v.saciCmd := '0';
            end if;
            
            -- Wait for saciRsp start bit
            v.shiftCount := (others => '0');
            if (saciRspSync(rspIndex) = '1' and r.saciClkFalling = '1') then
               v.state := RX_HEADER_S;
            end if;

         when RX_HEADER_S =>
            -- Shift data in and check that header is correct
            if (r.saciClkFalling = '1') then
               v.shiftCount := r.shiftCount + 1;
               v.shiftReg   := r.shiftReg(r.shiftReg'high-1 downto r.shiftReg'low) & saciRspSync(rspIndex);
            end if;

            if (r.shiftCount = 20) then
               -- Check that op, cmd and addr in response are correct
               if (r.shiftReg(19) /= op or
                   r.shiftReg(18 downto 12) /= cmd or
                   r.shiftReg(11 downto 0) /= addr) then
                  v.fail := '1';
               end if;

               if (op = '0') then
                  v.state := RX_DATA_S;
               else
                  v.state := ACK_S;
               end if;
            end if;

         when RX_DATA_S =>
            if (r.saciClkFalling = '1') then
               v.shiftCount := r.shiftCount + 1;
               v.shiftReg   := r.shiftReg(r.shiftReg'high-1 downto r.shiftReg'low) & saciRspSync(rspIndex);
               if (r.shiftCount = 51) then
                  v.state := ACK_S;
               end if;
            end if;


         when ACK_S =>
            v.ack    := '1';
            v.rdData := r.shiftReg(31 downto 0);
            if (req = '0') then
               v.ack   := '0';
               v.fail  := '0';
               v.state := IDLE_S;
            end if;

      end case;

      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      saciSelL <= r.saciSelL;
      saciCmd  <= r.saciCmd;
      saciClk  <= r.saciClk;
      ack      <= r.ack;
      fail     <= r.fail;
      rdData   <= r.rdData;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


end architecture rtl;
