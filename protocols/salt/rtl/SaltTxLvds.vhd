-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SALT TX Engine Module
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

library surf;
use surf.StdRtlPkg.all;
use surf.Code8b10bPkg.all;

entity SaltTxLvds is
   generic (
      TPD_G        : time   := 1 ns;
      SIM_DEVICE_G : string := "ULTRASCALE");
   port (
      -- Clocks and Resets
      clk125MHz : in  sl;
      rst125MHz : in  sl;
      clk156MHz : in  sl;
      rst156MHz : in  sl;
      clk625MHz : in  sl;
      -- GMII Interface
      txEn      : in  sl;
      txData    : in  slv(7 downto 0);
      -- LVDS TX Port
      txP       : out sl;
      txN       : out sl);
end SaltTxLvds;

architecture rtl of SaltTxLvds is

   type StateType is (
      IDLE_S,
      MOVE_S,
      TERM_S);

   type RegType is record
      txData : slv(7 downto 0);
      dataK  : sl;
      data   : slv(7 downto 0);
      state  : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      txData => (others => '0'),
      dataK  => '1',
      data   => K_28_5_C,
      state  => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal data10b : slv(9 downto 0);
   signal data8b  : slv(7 downto 0);

begin

   comb : process (r, rst125MHz, txData, txEn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Keep a delayed copy
      v.txData := txData;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if no data inbound
            if (txEn = '0') then
               -- IDLE char
               v.dataK := '1';
               v.data  := K_28_5_C;
            else
               -- Start_of_Packet
               v.dataK := '1';
               v.data  := K_27_7_C;
               -- Next state
               v.state := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Move the data
            v.dataK := '0';
            v.data  := r.txData;
            -- Check if no data inbound
            if (txEn = '0') then
               -- Next state
               v.state := TERM_S;
            end if;
         ----------------------------------------------------------------------
         when TERM_S =>
            -- End_of_Packet
            v.dataK := '1';
            v.data  := K_29_7_C;
            -- Next state
            v.state := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst125MHz = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk125MHz) is
   begin
      if rising_edge(clk125MHz) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Encoder : entity surf.Encoder8b10b
      generic map (
         TPD_G          => TPD_G,
         NUM_BYTES_G    => 1,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false)
      port map (
         clk        => clk125MHz,
         rst        => rst125MHz,
         dataIn     => r.data,
         dataKIn(0) => r.dataK,
         dataOut    => data10b);

   U_Gearbox : entity surf.AsyncGearbox
      generic map (
         TPD_G                => TPD_G,
         SLAVE_WIDTH_G        => 10,
         MASTER_WIDTH_G       => 8,
         -- Pipelining generics
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0,
         -- Async FIFO generics
         FIFO_MEMORY_TYPE_G   => "distributed",
         FIFO_ADDR_WIDTH_G    => 5)
      port map (
         -- Slave Interface
         slaveClk    => clk125MHz,
         slaveRst    => rst125MHz,
         slaveData   => data10b,
         slaveValid  => '1',
         slaveReady  => open,
         -- Master Interface
         masterClk   => clk156MHz,
         masterRst   => rst156MHz,
         masterData  => data8b,
         masterValid => open,
         masterReady => '1');

   U_TxSer : entity surf.SaltTxSer
      generic map (
         TPD_G        => TPD_G,
         SIM_DEVICE_G => SIM_DEVICE_G)
      port map (
         -- SELECTIO Ports
         txP    => txP,
         txN    => txN,
         -- Clock and Reset Interface
         clkx4  => clk625MHz,
         clkx1  => clk156MHz,
         rstx1  => rst156MHz,
         -- Output
         dataIn => data8b);

end rtl;
