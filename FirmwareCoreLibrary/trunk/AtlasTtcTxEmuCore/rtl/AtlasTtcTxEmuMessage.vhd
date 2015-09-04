-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuMessage.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-05
-- Last update: 2014-07-15
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AtlasTtcTxEmuPkg.all;

entity AtlasTtcTxEmuMessage is
   generic (
      TPD_G : time := 1 ns);      
   port (
      clk         : in  sl;
      rst         : in  sl;
      sync        : in  sl;
      config      : in  AtlasTtcTxEmuConfigType;
      bcrBurstCnt : out slv(31 downto 0);
      ecrBurstCnt : out slv(31 downto 0);
      chB         : out sl);      
end AtlasTtcTxEmuMessage;

architecture rtl of AtlasTtcTxEmuMessage is

   type StateType is (
      IDLE_S,
      START_BIT_S,
      FMT_S,
      SHIFT_REG_S,
      STOP_S,
      WAIT_S);    

   type RegType is record
      chB         : sl;
      ecr         : sl;
      bcr         : sl;
      fmt         : sl;
      iacValid    : sl;
      iacData     : slv(31 downto 0);
      cntEcr      : slv(31 downto 0);
      cntBcr      : slv(31 downto 0);
      shiftReg    : slv(38 downto 0);
      cnt         : slv(7 downto 0);
      bcrBurstCnt : slv(31 downto 0);
      ecrBurstCnt : slv(31 downto 0);
      state       : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal bcCheck  : slv(4 downto 0);
   signal iacCheck : slv(6 downto 0);
   signal bcDataIn,
      bcData : slv(7 downto 0);
   signal iacDataIn,
      iacData : slv(31 downto 0);
   
begin

   comb : process (bcCheck, bcData, config, iacCheck, iacData, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check for IAC data
      if config.iacValid = '1' then
         v.iacValid := '1';
         v.iacData  := config.iacData;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset signals
            v.chB := '1';
            v.ecr := '0';
            v.bcr := '0';
            -- Check for continuous mode
            if config.enbleContinousMode = '1' then
               -- Increment the counter
               v.cntEcr := r.cntEcr + 1;
               -- Check the counter value
               if r.cntEcr = config.ecrPeriod then
                  -- Reset the counter
                  v.cntEcr := (others => '0');
                  -- Set the trigger flag
                  v.ecr    := '1';
               end if;
               -- Increment the counter
               v.cntBcr := r.cntBcr + 1;
               -- Check the counter value
               if r.cntBcr = config.bcrPeriod then
                  -- Reset the counter
                  v.cntBcr := (others => '0');
                  -- Set the trigger flag
                  v.bcr    := '1';
               end if;
               -- Next State
               v.State := START_BIT_S;
            -- Check if burst mode and not burst reset
            elsif (config.enbleBurstMode = '1') and (config.burstRst = '0') then
               -- Increment the counter
               v.cntEcr := r.cntEcr + 1;
               -- Check the counter value
               if r.cntEcr = config.ecrPeriod then
                  -- Reset the counter
                  v.cntEcr := (others => '0');
                  -- Check the burst counter
                  if (config.ecrBurstCnt /= r.ecrBurstCnt) then
                     -- Increment the counter
                     v.ecrBurstCnt := r.ecrBurstCnt + 1;
                     -- Set the trigger flag
                     v.ecr         := '1';
                  end if;
               end if;
               -- Increment the counter
               v.cntBcr := r.cntBcr + 1;
               -- Check the counter value
               if r.cntBcr = config.bcrPeriod then
                  -- Reset the counter
                  v.cntBcr := (others => '0');
                  -- Check the burst counter
                  if (config.bcrBurstCnt /= r.bcrBurstCnt) then
                     -- Increment the counter
                     v.bcrBurstCnt := r.bcrBurstCnt + 1;
                     -- Set the trigger flag
                     v.bcr         := '1';
                  end if;
               end if;
               -- Next State
               v.State := START_BIT_S;
            else
               v.cntEcr := (others => '0');
               v.cntBcr := (others => '0');
            end if;
         ----------------------------------------------------------------------
         when START_BIT_S =>
            -- Check for BC message
            if r.fmt = '0' then
               -- Set the start bit
               v.chB := '0';
            else
               -- Check for valid IAC message
               if r.iacValid = '1' then
                  -- Set the start bit
                  v.chB := '0';
               end if;
            end if;
            -- Next State
            v.State := FMT_S;
         ----------------------------------------------------------------------
         when FMT_S =>
            -- Send the FMT bit
            v.chB := r.fmt;
            -- Check for BC message
            if r.fmt = '0' then
               -- Latch the BC data
               v.shiftReg(38 downto 31) := bcData;
               v.shiftReg(30 downto 26) := bcCheck;
               v.shiftReg(25 downto 0)  := (others => '0');
            else
               -- Check for a start bit
               if r.chB = '0' then
                  -- Latch the IAC data
                  v.shiftReg(38 downto 7) := iacData;
                  v.shiftReg(6 downto 0)  := iacCheck;
                  -- Reset the flag
                  v.iacValid              := '0';
               else
                  -- Don't send any data
                  v.shiftReg := (others => '1');
               end if;
            end if;
            -- Next State
            v.State := SHIFT_REG_S;
         ----------------------------------------------------------------------
         when SHIFT_REG_S =>
            -- Shift the data out
            v.chB                   := r.shiftReg(38);
            v.shiftReg(38 downto 1) := r.shiftReg(37 downto 0);
            v.shiftReg(0)           := '1';
            -- Increment the counter
            v.cnt                   := r.cnt + 1;
            -- Check if this is a BC Message or IAC message
            if r.fmt = '0' then         -- BC Message
               -- Check the counter Value
               if r.cnt = 12 then       -- (8 data bits + 5 check bits - 1)
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next State
                  v.state := STOP_S;
               end if;
            else                        -- IAC Message
               -- Check the counter Value
               if r.cnt = 38 then       -- (32 data bits + 7 check bits - 1)
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next State
                  v.state := STOP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when STOP_S =>
            -- Set the stop bit
            v.chB   := '1';
            -- Next State
            v.State := WAIT_S;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Increment the counter
            v.cnt := r.cnt + 1;
            -- Check if this is a BC Message or IAC message
            if r.fmt = '0' then
               -- Check the counter Value
               if r.cnt = 2 then        -- 20 CLK cycle = 17 BC + 3 WAIT - 1
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Toggle the FMT bit
                  v.fmt   := not(r.fmt);
                  -- Next State
                  v.state := START_BIT_S;
               end if;
            else                        -- IAC Message
               -- Check the counter Value
               if r.cnt = 3 then        -- 46 CLK cycle = 42 BC + 4 WAIT - 1
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Toggle the FMT bit
                  v.fmt   := not(r.fmt);
                  -- Next State
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      chB         <= r.chB;
      bcrBurstCnt <= r.bcrBurstCnt;
      ecrBurstCnt <= r.ecrBurstCnt;
      iacDataIn   <= r.iacData;
      bcDataIn(7) <= '0';
      bcDataIn(6) <= '0';
      bcDataIn(5) <= '0';
      bcDataIn(4) <= '0';
      bcDataIn(3) <= '0';
      bcDataIn(2) <= '0';
      bcDataIn(1) <= r.ecr;
      bcDataIn(0) <= r.bcr;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         -- Check for reset
         if (rst = '1') then
            r <= REG_INIT_C after TPD_G;
         else
            -- Phase up with the time multiplexer
            if sync = '1' then
               r <= rin after TPD_G;
            end if;
            -- Check for counter resets
            if (config.rstCnt(1) = '1') then
               -- Reset the counter
               r.cntEcr <= (others => '0') after TPD_G;
            end if;
            -- Check for counter resets
            if (config.rstCnt(2) = '1') then
               -- Reset the counter
               r.cntBcr <= (others => '0') after TPD_G;
            end if;
            -- Check for burst reset
            if config.burstRst = '1' then
               -- Reset the counter
               r.bcrBurstCnt <= (others => '0') after TPD_G;
               r.ecrBurstCnt <= (others => '0') after TPD_G;
            end if;
         end if;
      end if;
   end process seq;

   AtlasTtcTxEncoder5BitsWrapper_Inst : entity work.AtlasTtcTxEncoder5BitsWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         dataIn   => bcDataIn,
         dataOut  => bcData,
         checkOut => bcCheck);  

   AtlasTtcTxEncoder7BitsWrapper_Inst : entity work.AtlasTtcTxEncoder7BitsWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         dataIn   => iacDataIn,
         dataOut  => iacData,
         checkOut => iacCheck);           

end rtl;
