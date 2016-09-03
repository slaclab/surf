-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RawEthLoopBack.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-30
-- Last update: 2015-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:  
-------------------------------------------------------------------------------
-- This file is part of 'SLAC RCE 10G Ethernet Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC RCE 10G Ethernet Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity RawEthLoopBack is
   generic (
      TPD_G : time := 1 ns);      
   port (
      clk         : in  sl;
      rst         : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end RawEthLoopBack;

architecture rtl of RawEthLoopBack is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);  -- 64 bit interface
   
   type StateType is (
      IDLE_S,
      NEXT_S,
      FWD_S);    

   type RegType is record
      cnt      : slv(3 downto 0);
      data     : Slv64Array(0 to 1);
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      cnt      => x"0",
      data     => (others => (others => '0')),
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txCtrl : AxiStreamCtrlType;
   
begin

   comb : process (r, rst, sAxisMaster, txCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txMaster);

      -- Default 64-bit alignment
      v.txMaster.tKeep := x"00FF";

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Ready for new data
            v.rxSlave.tReady := '1';
            -- Check for FIFO transaction
            if (r.rxSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Latch first word
               v.data(0) := sAxisMaster.tData(63 downto 0);
               -- Next state
               v.state   := NEXT_S;
            end if;
         ----------------------------------------------------------------------
         when NEXT_S =>
            -- Check for FIFO transaction
            if (r.rxSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Latch first word
               v.data(1)        := sAxisMaster.tData(63 downto 0);
               -- Stop the transactions
               v.rxSlave.tReady := '0';
               -- Next state
               v.state          := FWD_S;
            end if;
         ----------------------------------------------------------------------
         when FWD_S =>
            -- Check for first write and ready
            if r.cnt = x"0" then
               -- Check if the FIFO is ready
               if txCtrl.pause = '0' then
                  -- Write to FIFO
                  v.txMaster.tValid              := '1';
                  v.txMaster.tData(63 downto 56) := v.data(0)(15 downto 8);
                  v.txMaster.tData(55 downto 48) := v.data(0)(7 downto 0);
                  v.txMaster.tData(47 downto 40) := v.data(1)(31 downto 24);
                  v.txMaster.tData(39 downto 32) := v.data(1)(23 downto 16);
                  v.txMaster.tData(31 downto 24) := v.data(1)(15 downto 8);
                  v.txMaster.tData(23 downto 16) := v.data(1)(7 downto 0);
                  v.txMaster.tData(15 downto 8)  := v.data(0)(63 downto 56);
                  v.txMaster.tData(7 downto 0)   := v.data(0)(55 downto 48);
                  -- Setup for the next write
                  v.cnt                          := x"1";
               end if;
            -- Check for second write and ready
            elsif r.cnt = x"1" then
               -- Check if the FIFO is ready
               if txCtrl.pause = '0' then
                  -- Write to FIFO
                  v.txMaster.tValid              := '1';
                  v.txMaster.tData(63 downto 32) := v.data(1)(63 downto 32);
                  v.txMaster.tData(31 downto 24) := v.data(0)(47 downto 40);
                  v.txMaster.tData(23 downto 16) := v.data(0)(39 downto 32);
                  v.txMaster.tData(15 downto 8)  := v.data(0)(31 downto 24);
                  v.txMaster.tData(7 downto 0)   := v.data(0)(23 downto 16);
                  -- Setup for the next write
                  v.cnt                          := x"F";
                  -- Check the TX FIFO
                  v.rxSlave.tReady               := not(txCtrl.pause);
               end if;
            else
               -- Check the TX FIFO
               v.rxSlave.tReady := not(txCtrl.pause);
               -- Check for FIFO transaction
               if (r.rxSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
                  -- Pass the data through
                  v.txMaster := sAxisMaster;
                  -- Check for last transfer
                  if sAxisMaster.tLast = '1' then
                     -- Reset for the first write
                     v.cnt   := x"0";
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave <= r.rxSlave;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SsiFifo_TX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         EN_FRAME_FILTER_G   => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C) 
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => r.txMaster,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);  

end rtl;
