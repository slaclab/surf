-------------------------------------------------------------------------------
-- File       : SaciMasterSync.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-08-10
-- Last update: 2013-03-01
-------------------------------------------------------------------------------
-- Description: Saci Master Synchronization Wrapper
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
-- use work.SynchronizePkg.all;
use work.SaciMasterPkg.all;

entity SaciMasterSync is
  
  generic (
    TPD_G                 : time    := 1 ns;
    SYNCHRONIZE_CONTROL_G : boolean := true
  );

  port (
    clk : in sl;                        -- Main clock
    rst : in sl;

    -- Serial interface
    saciClk  : out sl;
    saciSelL : out slv(SACI_NUM_SLAVES_C-1 downto 0);
    saciCmd  : out sl;
    saciRsp  : in  sl;
    
    saciHalfClk   : in slv(7 downto 0);

    -- Parallel interface
    saciMasterIn  : in  SaciMasterInType;
    saciMasterOut : out SaciMasterOutType);

end entity SaciMasterSync;

architecture rtl of SaciMasterSync is

  type SynchronizerType is record
    tmp  : sl;
    sync : sl;
    last : sl;
  end record;
  constant SYNCHRONIZER_INIT_0_C : SynchronizerType := (tmp => '0', sync => '0', last => '0');
  constant SYNCHRONIZER_INIT_1_C : SynchronizerType := (tmp => '1', sync => '1', last => '1');
  procedure synchronize (
    input   : in  sl;
    current : in  SynchronizerType;
    nextOut : out SynchronizerType) is
  begin
    nextOut.tmp  := input;
    nextOut.sync := current.tmp;
    nextOut.last := current.sync;
  end procedure;  

  type StateType is (IDLE_S, CHIP_SELECT_S, TX_S, RX_START_S, RX_HEADER_S, RX_DATA_S, ACK_S);

  type RegType is record
    reqSync    : SynchronizerType;
    resetSync  : SynchronizerType;
    state      : StateType;
    shiftReg   : slv(52 downto 0);
    shiftCount : unsigned(5 downto 0);

    saciSelL      : slv(SACI_NUM_SLAVES_C-1 downto 0);
    saciCmd       : sl;
    saciMasterOut : SaciMasterOutType;
  end record RegType;

  signal r, rin      : RegType;
  signal saciRspFall : sl;
  
  signal saciClkCnt     : unsigned(31 downto 0);
  signal saciClkCntRst  : std_logic;
  signal saciClkRising  : std_logic;
  signal saciClkFalling : std_logic;
  signal iSaciClk       : std_logic;
  signal iSaciClkD      : std_logic;

begin

  --------------------------------------------------------------------------------------------------
  -- Saci clock counter
  --------------------------------------------------------------------------------------------------
  saci_clk_p : process (clk, rst) is
  begin
    if rising_edge(clk) then
      
      if rst = '1' or saciClkCntRst = '1' then
        saciClkCnt <= (others=>'0') after TPD_G;
      elsif saciClkCnt = to_integer(unsigned(saciHalfClk)) then
        saciClkCnt <= (others=>'0') after TPD_G;
      else
        saciClkCnt <= saciClkCnt + 1 after TPD_G;
      end if;
      
      if rst = '1' or saciClkCntRst = '1' then
        iSaciClk <= '0' after TPD_G;
      elsif saciClkCnt = to_integer(unsigned(saciHalfClk)) then
        iSaciClk <= not iSaciClk after TPD_G;
      end if;
      
      if rst = '1' or saciClkCntRst = '1' then
        iSaciClkD <= '0' after TPD_G;
      else
        iSaciClkD <= iSaciClk after TPD_G;
      end if;
      
    end if;
  end process;
  
  saciClk <= iSaciClk;
  saciClkRising <= iSaciClk and not iSaciClkD;
  saciClkFalling <= iSaciClkD and not iSaciClk;
  
  
  --------------------------------------------------------------------------------------------------
  -- Capture serial input 
  --------------------------------------------------------------------------------------------------
  fall : process (clk, rst) is
  begin
    if (rst = '1') then
      saciRspFall <= '0' after TPD_G;
    elsif (rising_edge(clk)) then
      saciRspFall <= saciRsp after TPD_G;
    end if;
  end process fall;

  seq : process (clk, rst) is
  begin
    if (rst = '1') then
      r.reqSync              <= SYNCHRONIZER_INIT_0_C after TPD_G;
      r.resetSync            <= SYNCHRONIZER_INIT_0_C after TPD_G;
      r.state                <= IDLE_S                after TPD_G;
      r.shiftReg             <= (others => '0')       after TPD_G;
      r.shiftCount           <= (others => '0')       after TPD_G;
      r.saciSelL             <= (others => '1')       after TPD_G;
      r.saciCmd              <= '0'                   after TPD_G;
      r.saciMasterOut.ack    <= '0'                   after TPD_G;
      r.saciMasterOut.fail   <= '0'                   after TPD_G;
      r.saciMasterOut.rdData <= (others => '0')       after TPD_G;
    elsif (rising_edge(clk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r, saciRspFall, saciMasterIn, saciClkRising) is
    variable rVar     : RegType;
    variable reqVar   : sl;
    variable resetVar : sl;
  begin
    rVar := r;
    
    -- Synchronize control inputs to serial clock
    synchronize(saciMasterIn.req, r.reqSync, rVar.reqSync);
    synchronize(saciMasterIn.reset, r.resetSync, rVar.resetSync);
    if (SYNCHRONIZE_CONTROL_G) then
      reqVar   := r.reqSync.sync;
      resetVar := r.resetSync.sync;
    else
      reqVar   := saciMasterIn.req;
      resetVar := saciMasterIn.reset;
    end if;

    rVar.shiftCount        := (others => '0');
    rVar.saciMasterOut.ack := '0';
    
    saciClkCntRst <= '0';

    if (resetVar = '1') then
      rVar.saciSelL          := (others => '1');
      rVar.shiftReg          := (others => '0');
      rVar.shiftCount        := (others => '0');
      rVar.state             := IDLE_S;
      rVar.saciMasterOut.ack := '1';
    else

      case (r.state) is
        when IDLE_S =>
          saciClkCntRst <= '1';
          rVar.saciMasterOut.fail := '0';
          rVar.saciSelL           := (others => '1');
          rVar.shiftReg           := (others => '0');
          rVar.shiftCount         := (others => '0');
          if (reqVar = '1') then
            saciClkCntRst <= '0';
            -- New command, load shift reg
            rVar.shiftReg(52)           := '1';  -- Start bit
            rVar.shiftReg(51)           := saciMasterIn.op;
            rVar.shiftReg(50 downto 44) := saciMasterIn.cmd;
            rVar.shiftReg(43 downto 32) := saciMasterIn.addr;
            if (saciMasterIn.op = '1') then
              rVar.shiftReg(31 downto 0) := saciMasterIn.wrData;
            else
              rVar.shiftReg(31 downto 0) := (others => '0');
            end if;
            rVar.state := CHIP_SELECT_S;
          end if;

        when CHIP_SELECT_S =>
          rVar.saciSelL := (others => '1');
          rVar.saciSelL(to_integer(unsigned(saciMasterIn.chip))) := '0';
          if saciClkRising = '1' then
            rVar.state                                             := TX_S;
          else
            rVar.state                                             := CHIP_SELECT_S;
          end if;

        when TX_S =>
          -- Shift out data on saciCmd
          rVar.saciCmd    := r.shiftReg(52);
          if saciClkRising = '1' then
            rVar.shiftReg   := r.shiftReg(51 downto 0) & '0';
            rVar.shiftCount := r.shiftCount + 1;
          else
            rVar.shiftReg   := r.shiftReg;
            rVar.shiftCount := r.shiftCount;
          end if;
          
          if (saciMasterIn.op = '0' and r.shiftCount = 21) then     -- Read
            rVar.state := RX_START_S;
          elsif (saciMasterIn.op = '1' and r.shiftCount = 53) then  -- Write
            rVar.state := RX_START_S;
          end if;
          

        when RX_START_S =>
          -- Wait for saciRsp start bit
          rVar.shiftCount := (others => '0');
          if (saciRspFall = '1' and saciClkRising = '1') then
            rVar.state := RX_HEADER_S;
          else
            rVar.state := RX_START_S;
          end if;

        when RX_HEADER_S =>
          -- Shift data in and check that header is correct
          if saciClkRising = '1' then
            rVar.shiftCount := r.shiftCount + 1;
            --shiftInLeft(saciRspFall, r.shiftReg, rVar.shiftReg);
            rVar.shiftReg := r.shiftReg(r.shiftReg'high-1 downto r.shiftReg'low) & saciRspFall;     
          else
            rVar.shiftCount := r.shiftCount;
            rVar.shiftReg := r.shiftReg; 
          end if;
          if (r.shiftCount = 20) then
            if (r.shiftReg(19) /= saciMasterIn.op or
                r.shiftReg(18 downto 12) /= saciMasterIn.cmd or
                r.shiftReg(11 downto 0) /= saciMasterIn.addr) then
              rVar.saciMasterOut.fail := '1';
            end if;
            if (saciMasterIn.op = '0') then
              rVar.state := RX_DATA_S;
            else
              rVar.state := ACK_S;
            end if;
          end if;

        when RX_DATA_S =>
          if saciClkRising = '1' then
            rVar.shiftCount := r.shiftCount + 1;
            --shiftInLeft(saciRspFall, r.shiftReg, rVar.shiftReg);
            rVar.shiftReg := r.shiftReg(r.shiftReg'high-1 downto r.shiftReg'low) & saciRspFall; 
            if (r.shiftCount = 51) then
              rVar.state := ACK_S;
            end if;
          else
            rVar.shiftCount := r.shiftCount;
            rVar.shiftReg := r.shiftReg; 
          end if;
          
          

        when ACK_S =>
          rVar.saciMasterOut.ack    := '1';
          rVar.saciMasterOut.rdData := r.shiftReg(31 downto 0);
          if (reqVar = '0') then
            rVar.saciMasterOut.ack  := '0';
            rVar.saciMasterOut.fail := '0';
            rVar.state              := IDLE_S;
          end if;
          
        when others => null;
      end case;

    end if;

    rin <= rVar;

    saciSelL      <= r.saciSelL;
    saciCmd       <= r.saciCmd;
    saciMasterOut <= r.saciMasterOut;
    
  end process comb;

end architecture rtl;
