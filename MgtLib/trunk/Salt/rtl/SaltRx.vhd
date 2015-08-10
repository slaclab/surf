-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT RX Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity SaltRx is
   generic (
      TPD_G           : time            := 1 ns;
      NUM_BYTES_G     : positive        := 2;
      COMMA_EN_G      : slv(3 downto 0) := "0011";
      COMMA_0_G       : slv             := "----------0101111100";
      COMMA_1_G       : slv             := "----------1010000011";
      COMMA_2_G       : slv             := "XXXXXXXXXXXXXXXXXXXX";
      COMMA_3_G       : slv             := "XXXXXXXXXXXXXXXXXXXX";
      IODELAY_GROUP_G : string          := "SALT_IODELAY_GRP";
      RXCLK2X_FREQ_G  : real            := 200.0;  -- In units of MHz
      XIL_DEVICE_G    : string          := "7SERIES");
   port (
      -- RX Serial Stream
      rxP        : in  sl;
      rxN        : in  sl;
      rxInv      : in  sl := '0';
      -- RX Parallel 8B/10B data bus
      rxDataOut  : out slv(NUM_BYTES_G*8-1 downto 0);
      rxDataKOut : out slv(NUM_BYTES_G-1 downto 0);
      rxCodeErr  : out slv(NUM_BYTES_G-1 downto 0);
      rxDispErr  : out slv(NUM_BYTES_G-1 downto 0);
      rxPhyReady : out sl;
      -- Clock and Reset
      refClk     : in  sl;              -- IODELAY's Reference Clock
      refRst     : in  sl;
      rxClkEn    : out sl;
      rxClk      : in  sl;
      rxClk2x    : in  sl;              -- Twice the frequecy of rxClk (independent of rxClk phase)
      rxClk2xInv : in  sl;              -- Twice the frequecy of rxClk (180 phase of rxClk2x)
      rxRst      : in  sl);   
end SaltRx;

architecture rtl of SaltRx is

   constant MAX_CNT_C : natural := NUM_BYTES_G*10-1;
   
   type StateType is (
      STARTUP_DLY_S,
      UNLOCKED_S,
      LOCKED_S);   

   type RegType is record
      rxPhyReady : sl;
      rxClkEn    : sl;
      cnt        : natural range 0 to MAX_CNT_C;
      rx         : slv(NUM_BYTES_G*10-1 downto 0);
      dataIn     : slv(NUM_BYTES_G*10-1 downto 0);
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      rxPhyReady => '0',
      rxClkEn    => '0',
      cnt        => 0,
      rx         => (others => '0'),
      dataIn     => (others => '0'),
      state      => STARTUP_DLY_S);

   signal r     : RegType := REG_INIT_C;
   signal rin   : RegType;
   signal rxBit : sl;

begin

   SaltRxBit_Inst : entity work.SaltRxBit
      generic map (
         TPD_G           => TPD_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         RXCLK2X_FREQ_G  => RXCLK2X_FREQ_G,
         XIL_DEVICE_G    => XIL_DEVICE_G)       
      port map (
         -- RX Serial Stream
         rxP        => rxP,
         rxN        => rxN,
         rxInv      => rxInv,
         rxBit      => rxBit,
         -- Clock and Reset
         refClk     => refClk,
         refRst     => refRst,
         rxClk      => rxClk,
         rxClk2x    => rxClk2x,
         rxClk2xInv => rxClk2xInv,
         rxRst      => rxRst);

   Decoder8b10b_Inst : entity work.Decoder8b10b
      generic map (
         TPD_G       => TPD_G,
         NUM_BYTES_G => NUM_BYTES_G)
      port map (
         clkEn    => r.rxClkEn,
         clk      => rxClk,
         rst      => rxRst,
         dataIn   => r.dataIn,
         dataOut  => rxDataOut,
         dataKOut => rxDataKOut,
         codeErr  => rxCodeErr,
         dispErr  => rxDispErr);        

   comb : process (r, rxBit, rxRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.rxClkEn := '0';

      -- Shift in the data the message (LSB first)
      v.rx(MAX_CNT_C)            := rxBit;
      v.rx(MAX_CNT_C-1 downto 0) := r.rx(MAX_CNT_C downto 1);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when STARTUP_DLY_S =>
            -- Reset the flag
            v.rxPhyReady := '0';
            -- Increment the counter
            v.cnt        := r.cnt + 1;
            -- Check the counter
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt   := 0;
               -- Next State
               v.state := UNLOCKED_S;
            end if;
         ----------------------------------------------------------------------
         when UNLOCKED_S =>
            -- Align to the COMMA
            if (std_match(v.rx, COMMA_0_G) and (COMMA_EN_G(0) = '1')) or
               (std_match(v.rx, COMMA_1_G) and (COMMA_EN_G(1) = '1')) or
               (std_match(v.rx, COMMA_2_G) and (COMMA_EN_G(2) = '1')) or
               (std_match(v.rx, COMMA_3_G) and (COMMA_EN_G(3) = '1')) then
               -- Set the flag
               v.rxClkEn := '1';
               -- Latch the data bus
               v.dataIn  := v.rx;
               -- Next State
               v.state   := LOCKED_S;
            end if;
         ----------------------------------------------------------------------
         when LOCKED_S =>
            -- Increment the counter
            v.cnt := r.cnt + 1;
            -- Check the counter
            if r.cnt = MAX_CNT_C then
               -- Reset the counter
               v.cnt        := 0;
               -- Set the flags
               v.rxClkEn    := '1';
               v.rxPhyReady := '1';
               -- Latch the data bus
               v.dataIn     := v.rx;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (rxRst = '1') then
         -- Reset the registers
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      rxClkEn    <= r.rxClkEn;
      rxPhyReady <= r.rxPhyReady;

   end process comb;

   seq : process (rxClk) is
   begin
      if rising_edge(rxClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
