-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuV2EngineA.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-12
-- Platform   : Vivado 2014.3
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
use work.AtlasTtcTxEmuV2Pkg.all;

entity AtlasTtcTxEmuV2EngineA is
   generic (
      TPD_G          : time     := 1 ns;
      CASCADE_SIZE_G : positive := 1);      
   port (
      -- Channel A Interface
      busy   : in  sl;
      sync   : in  sl;
      chA    : out sl;
      -- Control interface
      config : in  AtlasTtcTxEmuV2EngineConfigType;
      status : out AtlasTtcTxEmuV2EngineStatusType;
      -- Clock and Reset
      clk    : in  sl;
      rst    : in  sl);
end AtlasTtcTxEmuV2EngineA;

architecture rtl of AtlasTtcTxEmuV2EngineA is

   type StateType is (
      IDLE_S,
      CNT_S,
      POLLING_S); 

   type RegType is record
      chA     : sl;
      running : sl;
      rdEn    : sl;
      cnt     : slv(31 downto 0);
      size    : slv(31 downto 0);
      state   : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      chA     => '0',
      running => '0',
      rdEn    => '0',
      cnt     => (others => '0'),
      size    => (others => '0'),
      state   => IDLE_S);       

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal data  : slv(31 downto 0);
   signal valid : sl;

begin

   Fifo_Inst : entity work.FifoCascade
      generic map (
         TPD_G           => TPD_G,
         CASCADE_SIZE_G  => CASCADE_SIZE_G,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => true,
         FWFT_EN_G       => true,
         DATA_WIDTH_G    => 32,
         ADDR_WIDTH_G    => 10)                  
      port map (
         -- Resets
         rst      => rst,
         --Write Ports (wr_clk domain)
         wr_clk   => clk,
         wr_en    => config.wrEn,
         din      => config.data,
         overflow => status.overflow,
         full     => status.full,
         --Read Ports (rd_clk domain)
         rd_clk   => clk,
         rd_en    => r.rdEn,
         dout     => data,
         valid    => valid,
         empty    => status.empty);

   comb : process (busy, config, data, r, rst, sync, valid) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.rdEn := '0';

      -- Phase up with the time multiplexer
      if sync = '1' then
         -- Reset strobing signals
         v.chA := '0';
         -- State Machine
         case (r.state) is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- No Operation
               null;
            ----------------------------------------------------------------------
            when CNT_S =>
               -- Increment the counter
               v.cnt := r.cnt + 1;
               -- Check the counter
               if r.cnt = r.size then
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next State
                  v.State := POLLING_S;
               end if;
            ----------------------------------------------------------------------
            when POLLING_S =>
               -- Check if the FIFO has data
               if valid = '1' then
                  -- ACK the FIFO read
                  v.rdEn := '1';
                  -- Generate L1 Trigger if not busy
                  v.chA  := not(busy);
                  -- Check if IDLEs in-between triggers
                  if data /= 0 then
                     -- Latch the preset value
                     v.size  := (data-1);
                     -- Next State
                     v.State := CNT_S;
                  end if;
               end if;
         ----------------------------------------------------------------------
         end case;
      end if;

      -- Check for a start command
      if config.startCmd = '1' then
         -- Set the status flag
         v.running := '1';
         -- Reset the counter
         v.cnt     := (others => '0');
         -- Check if zero IDLEs in preset
         if config.preset = 0 then
            -- Next State
            v.State := POLLING_S;
         else
            -- Latch the preset value
            v.size  := (config.preset-1);
            -- Next State
            v.State := CNT_S;
         end if;
      end if;

      -- Check for a stop command
      if config.stopCmd = '1' then
         -- Set the status flag
         v.running := '0';
         -- Next State
         v.State   := IDLE_S;
      end if;

      -- Synchronous Reset
      if rst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      chA            <= r.chA;
      status.running <= r.running;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
