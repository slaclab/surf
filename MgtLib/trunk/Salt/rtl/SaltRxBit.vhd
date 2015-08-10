-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRxBit.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2015-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT RX Oversampling Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SaltRxBit is
   generic (
      TPD_G           : time   := 1 ns;
      IODELAY_GROUP_G : string := "SALT_IODELAY_GRP";
      RXCLK2X_FREQ_G  : real   := 200.0;  -- In units of MHz
      XIL_DEVICE_G    : string := "7SERIES");       
   port (
      -- RX Serial Stream
      rxP        : in  sl;
      rxN        : in  sl;
      rxInv      : in  sl := '0';
      rxBit      : out sl;
      -- Clock and Reset
      refClk     : in  sl;              -- IODELAY's Reference Clock
      refRst     : in  sl;
      rxClk      : in  sl;
      rxClk2x    : in  sl;              -- Twice the frequecy of rxClk (independent of rxClk phase)
      rxClk2xInv : in  sl;              -- Twice the frequecy of rxClk (180 phase of rxClk2x)
      rxRst      : in  sl);
end SaltRxBit;

architecture rtl of SaltRxBit is

   constant HPM_C : string := ite((RXCLK2X_FREQ_G > 190.0) and (RXCLK2X_FREQ_G < 210.0), "FALSE", "TRUE");

   type StateType is (
      NORMAL_S,
      SLIP_WAIT_S);   

   type RegType is record
      armed       : sl;
      slip        : sl;
      index       : natural range 0 to 3;
      smpl        : slv(7 downto 0);
      cnt         : slv(7 downto 0);
      serialValid : sl;
      serialBit   : sl;
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      armed       => '0',
      slip        => '0',
      index       => 0,
      smpl        => x"00",
      cnt         => x"00",
      serialValid => '0',
      serialBit   => '0',
      state       => NORMAL_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rx    : sl;
   signal slip  : sl;
   signal rxDly : sl;
   signal smpl  : slv(1 downto 0);

   -- attribute IODELAY_GROUP                  : string;
   -- attribute IODELAY_GROUP of IDELAYE3_Inst : label is IODELAY_GROUP_G;

begin

   IBUFDS_Inst : IBUFDS
      port map (
         I  => rxP,
         IB => rxN,
         O  => rx);

   GEN_7SERIES : if (XIL_DEVICE_G = "7SERIES") generate
      
      IDELAYE2_inst : IDELAYE2
         generic map (
            CINVCTRL_SEL          => "FALSE",  -- Enable dynamic clock inversion (FALSE, TRUE)
            DELAY_SRC             => "IDATAIN",       -- Delay input (IDATAIN, DATAIN)
            HIGH_PERFORMANCE_MODE => HPM_C,    -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
            IDELAY_TYPE           => "VARIABLE",      -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
            IDELAY_VALUE          => 0,        -- Input delay tap setting (0-31)
            PIPE_SEL              => "FALSE",  -- Select pipelined mode, FALSE, TRUE
            REFCLK_FREQUENCY      => RXCLK2X_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
            SIGNAL_PATTERN        => "DATA")   -- DATA, CLOCK input signal
         port map (
            CNTVALUEOUT => open,        -- 5-bit output: Counter value output
            DATAOUT     => rxDly,       -- 1-bit output: Delayed data output
            C           => refClk,      -- 1-bit input: Clock input
            CE          => slip,        -- 1-bit input: Active high enable increment/decrement input
            CINVCTRL    => '0',         -- 1-bit input: Dynamic clock inversion input
            CNTVALUEIN  => (others => '0'),    -- 5-bit input: Counter value input
            DATAIN      => '0',         -- 1-bit input: Internal delay data input
            IDATAIN     => rx,          -- 1-bit input: Data input from the I/O
            INC         => '1',         -- 1-bit input: Increment / Decrement tap delay input
            LD          => '0',         -- 1-bit input: Load IDELAY_VALUE input
            LDPIPEEN    => '0',         -- 1-bit input: Enable PIPELINE register to load data input
            REGRST      => refRst);     -- 1-bit input: Active-high reset tap-delay input

      IDDR_Inst : IDDR
         generic map (
            DDR_CLK_EDGE => "SAME_EDGE")  
         port map (
            C  => rxClk2x,
            CE => '1',
            R  => '0',
            S  => '0',
            D  => rxDly,
            Q2 => smpl(1),
            Q1 => smpl(0));         

   end generate;

   GEN_ULTRA_SCALE : if (XIL_DEVICE_G = "ULTRASCALE") generate
      
      IDELAYE3_Inst : IDELAYE3
         generic map (
            CASCADE          => "NONE",   -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            DELAY_FORMAT     => "COUNT",  -- Units of the DELAY_VALUE (COUNT, TIME)
            DELAY_SRC        => "IDATAIN",   -- Delay input (DATAIN, IDATAIN)
            DELAY_TYPE       => "VARIABLE",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            DELAY_VALUE      => 0,      -- Input delay value setting
            IS_CLK_INVERTED  => '0',    -- Optional inversion for CLK
            IS_RST_INVERTED  => '0',    -- Optional inversion for RST
            REFCLK_FREQUENCY => RXCLK2X_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2400.0)
            UPDATE_MODE      => "ASYNC")  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
         port map (
            CASC_OUT    => open,  -- 1-bit output: Cascade delay output to ODELAY input cascade
            CNTVALUEOUT => open,        -- 9-bit output: Counter value output
            DATAOUT     => rxDly,       -- 1-bit output: Delayed data output
            CASC_IN     => '0',   -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
            CASC_RETURN => '0',   -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
            CE          => slip,        -- 1-bit input: Active high enable increment/decrement input
            CLK         => refClk,      -- 1-bit input: Clock input
            CNTVALUEIN  => (others => '0'),  -- 9-bit input: Counter value input
            DATAIN      => '0',         -- 1-bit input: Data input from the logic
            EN_VTC      => '0',         -- 1-bit input: Keep delay constant over VT
            IDATAIN     => rx,          -- 1-bit input: Data input from the IOBUF
            INC         => '1',         -- 1-bit input: Increment / Decrement tap delay input
            LOAD        => '0',         -- 1-bit input: Load DELAY_VALUE input
            RST         => refRst);     -- 1-bit input: Asynchronous Reset to the DELAY_VALUE

      IDDRE1_Inst : IDDRE1
         generic map (
            DDR_CLK_EDGE => "SAME_EDGE")
         port map (
            C  => rxClk2x,
            CB => rxClk2xInv,
            R  => '0',
            D  => rxDly,
            Q2 => smpl(1),
            Q1 => smpl(0));

   end generate;

   SynchronizerOneShot_Inst : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => refClk,
         rst     => refRst,
         dataIn  => r.slip,
         dataOut => slip);

   comb : process (r, smpl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.slip        := '0';
      v.serialValid := '0';

      -- Shift registers
      v.smpl(1 downto 0) := smpl;
      v.smpl(7 downto 2) := r.smpl(5 downto 0);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when NORMAL_S =>
            -- Check the flag
            if r.serialValid = '0' then
               -- Set the flags
               v.serialValid := '1';
               v.armed       := '1';
               -- Latch the bit
               v.serialBit   := r.smpl(3);
               -- Check for locked code
               if (r.smpl(3 downto 0) = x"0") or (r.smpl(3 downto 0) = x"F") then
                  -- Set the index
                  v.index := 0;
               elsif (r.smpl(4 downto 1) = x"0") or (r.smpl(4 downto 1) = x"F") then
                  -- Set the index
                  v.index := 1;
               elsif (r.smpl(5 downto 2) = x"0") or (r.smpl(5 downto 2) = x"F") then
                  -- Set the index
                  v.index := 2;
               elsif (r.smpl(6 downto 3) = x"0") or (r.smpl(6 downto 3) = x"F") then
                  -- Set the index
                  v.index := 3;
               else
                  -- Set the flag
                  v.slip  := '1';
                  -- Next State
                  v.state := SLIP_WAIT_S;
               end if;
               -- Check for index slip
               if (r.armed = '1') and (r.index /= v.index) then
                  -- Set the flag
                  v.slip  := '1';
                  -- Next State
                  v.state := SLIP_WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SLIP_WAIT_S =>
            -- Reset the flag
            v.armed := '0';
            -- Increment the counter
            v.cnt   := r.cnt + 1;
            -- Check the flag
            if r.cnt = x"FF" then
               -- Reset the counter
               v.cnt   := x"00";
               -- Next State
               v.state := NORMAL_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (rxClk2x) is
   begin
      if rising_edge(rxClk2x) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SynchronizerFifo_Inst : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 1)
      port map (
         rst     => rxRst,
         -- Write Ports (wr_clk domain)
         wr_clk  => rxClk2x,
         wr_en   => r.serialValid,
         din(0)  => r.serialBit,
         -- Read Ports (rd_clk domain)
         rd_clk  => rxClk,
         dout(0) => rxBit);    

end rtl;
