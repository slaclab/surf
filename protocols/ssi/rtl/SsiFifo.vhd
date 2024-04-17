-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper on the AxiStreamFifoV2 + inbound/outbound filters
--              The filters remove all malformed SSI frames from being sent
--              on the master AXI stream port.
-------------------------------------------------------------------------------
-- Note: This module does NOT support interleaved tDEST
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiFifo is
   generic (
      -- General Configurations
      TPD_G                  : time                := 1 ns;
      RST_ASYNC_G            : boolean             := false;
      INT_PIPE_STAGES_G      : natural             := 0;  -- Internal FIFO setting
      PIPE_STAGES_G          : natural             := 1;
      SLAVE_READY_EN_G       : boolean             := true;
      -- Valid threshold should always be 1 when using interleaved TDEST
      --       =1 = normal operation
      --       =0 = only when frame ready
      --       >1 = only when frame ready or # entries
      VALID_THOLD_G          : natural             := 1;
      VALID_BURST_MODE_G     : boolean             := false;  -- only used in VALID_THOLD_G>1
      -- FIFO configurations
      GEN_SYNC_FIFO_G        : boolean             := false;
      FIFO_ADDR_WIDTH_G      : positive            := 9;
      FIFO_FIXED_THRESH_G    : boolean             := true;
      FIFO_PAUSE_THRESH_G    : positive            := 1;
      SYNTH_MODE_G           : string              := "inferred";
      MEMORY_TYPE_G          : string              := "block";
      -- Internal FIFO width select, "WIDE", "NARROW" or "CUSTOM"
      -- WIDE uses wider of slave / master. NARROW  uses narrower.
      -- CUSOTM uses passed FIFO_DATA_WIDTH_G
      INT_WIDTH_SELECT_G     : string              := "WIDE";
      INT_DATA_WIDTH_G       : positive            := 16;
      -- If VALID_THOLD_G /=1, FIFO that stores on tLast transaction can be smaller.
      --       Set to 0 for same size as primary FIFO (default)
      --       Set >4 for custom size.
      --       Use at own risk. Overflow of tLast FIFO is not checked
      LAST_FIFO_ADDR_WIDTH_G : natural             := 0;
      -- Index = 0 is output, index = n is input
      CASCADE_PAUSE_SEL_G    : natural             := 0;
      CASCADE_SIZE_G         : positive            := 1;
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G     : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G    : AxiStreamConfigType);
   port (
      -- Slave Interface (sAxisClk domain)
      sAxisClk        : in  sl;
      sAxisRst        : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      -- FIFO status & config (sAxisClk domain)
      fifoPauseThresh : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');
      fifoWrCnt       : out slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      sAxisDropWord   : out sl;
      sAxisDropFrame  : out sl;
      mAxisDropWord   : out sl;
      mAxisDropFrame  : out sl;
      lockupRstEvent  : out sl;
      -- Master Interface (mAxisClk domain)
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType);
end SsiFifo;

architecture rtl of SsiFifo is

   type StateType is (
      WAIT_S,
      MON_S);

   type RegType is record
      fifoRst : sl;
      cnt     : slv(3 downto 0);
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      fifoRst => '0',
      cnt     => x"0",
      state   => WAIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal rxCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal txMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave      : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal txTLastTUser : slv(7 downto 0)     := x"00";

   signal obAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal obAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal fifoFull : sl := '0';
   signal fifoRst  : sl := '0';

begin

--   assert (SLAVE_AXI_CONFIG_G.TDEST_INTERLEAVE_C = false)
--      report "SsiFifo does NOT support interleaved TDEST" severity failure;

   assert (SLAVE_AXI_CONFIG_G.TUSER_BITS_C >= 2)
      report "SsiFifo:  SLAVE_AXI_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   assert (MASTER_AXI_CONFIG_G.TUSER_BITS_C >= 2)
      report "SsiFifo:  MASTER_AXI_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   ----------------------
   -- Inbound FIFO Filter
   ----------------------
   U_IbFilter : entity surf.SsiIbFrameFilter
      generic map (
         TPD_G            => TPD_G,
         RST_ASYNC_G      => RST_ASYNC_G,
         SLAVE_READY_EN_G => SLAVE_READY_EN_G,
         AXIS_CONFIG_G    => SLAVE_AXI_CONFIG_G)
      port map (
         -- Slave Interface
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         sAxisCtrl      => sAxisCtrl,
         sAxisDropWord  => sAxisDropWord,
         sAxisDropFrame => sAxisDropFrame,
         -- Master Interface
         mAxisMaster    => rxMaster,
         mAxisSlave     => rxSlave,
         mAxisCtrl      => rxCtrl,
         -- Clock and Reset
         axisClk        => sAxisClk,
         axisRst        => sAxisRst);

   ------------------
   -- AXI Stream FIFO
   ------------------
   U_Fifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G                  => TPD_G,
         RST_ASYNC_G            => RST_ASYNC_G,
         INT_PIPE_STAGES_G      => INT_PIPE_STAGES_G,
         PIPE_STAGES_G          => PIPE_STAGES_G,
         SLAVE_READY_EN_G       => true,  -- Using TREADY between FIFO and IbFilter
         VALID_THOLD_G          => VALID_THOLD_G,
         VALID_BURST_MODE_G     => VALID_BURST_MODE_G,
         GEN_SYNC_FIFO_G        => true,  -- Using external U_ASYNC_FIFO instead
         FIFO_ADDR_WIDTH_G      => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G    => FIFO_FIXED_THRESH_G,
         FIFO_PAUSE_THRESH_G    => FIFO_PAUSE_THRESH_G,
         SYNTH_MODE_G           => SYNTH_MODE_G,
         MEMORY_TYPE_G          => MEMORY_TYPE_G,
         INT_WIDTH_SELECT_G     => INT_WIDTH_SELECT_G,
         INT_DATA_WIDTH_G       => INT_DATA_WIDTH_G,
         LAST_FIFO_ADDR_WIDTH_G => LAST_FIFO_ADDR_WIDTH_G,
         CASCADE_PAUSE_SEL_G    => CASCADE_PAUSE_SEL_G,
         CASCADE_SIZE_G         => CASCADE_SIZE_G,
         SLAVE_AXI_CONFIG_G     => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G    => SLAVE_AXI_CONFIG_G)
      port map (
         -- Slave Interface (sAxisClk domain)
         sAxisClk        => sAxisClk,
         sAxisRst        => fifoRst,
         sAxisMaster     => rxMaster,
         sAxisSlave      => rxSlave,
         sAxisCtrl       => rxCtrl,
         -- FIFO status & config (sAxisClk domain)
         fifoPauseThresh => fifoPauseThresh,
         fifoWrCnt       => fifoWrCnt,
         fifoFull        => fifoFull,
         -- Master Interface (sAxisClk domain)
         mAxisClk        => sAxisClk,
         mAxisRst        => fifoRst,
         mAxisMaster     => txMaster,
         mAxisSlave      => txSlave,
         mTLastTUser     => txTLastTUser);

   --------------
   -- Normal Mode
   --------------
   NOT_CACHED : if (VALID_THOLD_G = 1) generate
      fifoRst        <= sAxisRst;
      lockupRstEvent <= '0';
   end generate;

   ---------------------------------------------
   -- Prevent locking up when VALID_THOLD_G /= 1
   ---------------------------------------------
   PREVENT_LOCKUP : if (VALID_THOLD_G /= 1) generate

      comb : process (fifoFull, r, sAxisRst, txMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Reset strobe Signals
         v.fifoRst := '0';

         -- State Machine
         case (r.state) is
            ----------------------------------------------------------------------
            when WAIT_S =>
               -- Increment the counter
               v.cnt := r.cnt + 1;
               -- Check for roll over (allowing FIFO to settle after rst)
               if (v.cnt = 0) then
                  -- Next state
                  v.state := MON_S;
               end if;
            ----------------------------------------------------------------------
            when MON_S =>
               -- Check for lock up condition
               if (fifoFull = '1') and (txMaster.tValid = '0') then
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
                  -- Check for roll over (effectively a timeout)
                  if (v.cnt = 0) then
                     -- Reset the FIFO to get out of lockup state
                     v.fifoRst := '1';
                     -- Next state
                     v.state   := WAIT_S;
                  end if;
               else
                  -- Reset the counter
                  v.cnt := x"0";
               end if;
         ----------------------------------------------------------------------
         end case;

         -- Outputs
         lockupRstEvent <= r.fifoRst;
         fifoRst        <= r.fifoRst or sAxisRst;

         -- Synchronous Reset
         if (RST_ASYNC_G = false and sAxisRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

      end process comb;

      seq : process (sAxisClk, sAxisRst) is
      begin
         if (RST_ASYNC_G) and (sAxisRst = '1') then
            r <= REG_INIT_C after TPD_G;
         elsif rising_edge(sAxisClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;

   end generate;

   -----------------------
   -- Outbound FIFO Filter
   -----------------------
   U_ObFilter : entity surf.SsiObFrameFilter
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         VALID_THOLD_G => VALID_THOLD_G,
         PIPE_STAGES_G => PIPE_STAGES_G,
         AXIS_CONFIG_G => SLAVE_AXI_CONFIG_G)
      port map (
         -- Slave Interface (sAxisClk domain)
         sAxisMaster    => txMaster,
         sAxisSlave     => txSlave,
         sTLastTUser    => txTLastTUser,
         -- Master Interface
         mAxisMaster    => obAxisMaster,
         mAxisSlave     => obAxisSlave,
         mAxisDropWord  => mAxisDropWord,
         mAxisDropFrame => mAxisDropFrame,
         -- Clock and Reset
         axisClk        => sAxisClk,
         axisRst        => sAxisRst);

   -----------------------
   -- sAxisClk /= mAxisClk
   -----------------------
   GEN_ASYNC : if (GEN_SYNC_FIFO_G = false) generate
      U_ASYNC_FIFO : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            -- FIFO configurations
            SYNTH_MODE_G        => SYNTH_MODE_G,
            MEMORY_TYPE_G       => "distributed",
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 4,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
         port map (
            -- Slave Port
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => obAxisMaster,
            sAxisSlave  => obAxisSlave,
            -- Master Port
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave);
   end generate;

   ----------------------
   -- sAxisClk = mAxisClk
   ----------------------
   GEN_SYNC : if (GEN_SYNC_FIFO_G = true) generate
      U_Resize : entity surf.AxiStreamGearbox
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            READY_EN_G          => SLAVE_READY_EN_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
         port map (
            -- Clock and reset
            axisClk     => sAxisClk,
            axisRst     => sAxisRst,
            -- Slave Port
            sAxisMaster => obAxisMaster,
            sAxisSlave  => obAxisSlave,
            -- Master Port
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave);
   end generate;

end rtl;
