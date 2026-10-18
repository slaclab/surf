-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Outbound FIFO buffers
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
use surf.AxiStreamPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxFifo is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G       : boolean                := false;
      SYNTH_MODE_G      : string                 := "inferred";
      MEMORY_TYPE_G     : string                 := "block";
      DROP_ERR_PKT_G    : boolean                := true;
      INT_PIPE_STAGES_G : natural                := 1;
      PIPE_STAGES_G     : natural                := 1;
      FIFO_ADDR_WIDTH_G : positive range 9 to 16 := 11;
      PRIM_COMMON_CLK_G : boolean                := false;
      PRIM_CONFIG_G     : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C;
      BYP_EN_G          : boolean                := false;
      BYP_COMMON_CLK_G  : boolean                := false;
      BYP_CONFIG_G      : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C;
      -- MAC-internal stream format; EMAC_TIMING_AXIS_CONFIG_C adds the TID token.
      INT_CONFIG_G      : AxiStreamConfigType    := INT_EMAC_AXIS_CONFIG_C;
      -- Timing port: tokened drop retires and no SsiFifo lockup self-reset, so
      -- no stored frame is discarded without a retire (timing-port.md section 6)
      TIMING_EN_G       : boolean                := false);
   port (
      -- Clock and Reset
      sClk        : in  sl;
      sRst        : in  sl;
      -- Status/Config (sClk domain)
      phyReady    : in  sl;
      rxFifoDrop  : out sl;
      pauseThresh : in  slv(15 downto 0);
      -- Primary Interface
      mPrimClk    : in  sl;
      mPrimRst    : in  sl;
      sPrimMaster : in  AxiStreamMasterType;
      sPrimCtrl   : out AxiStreamCtrlType;
      mPrimMaster : out AxiStreamMasterType;
      mPrimSlave  : in  AxiStreamSlaveType;
      -- Bypass interface
      mBypClk     : in  sl;
      mBypRst     : in  sl;
      sBypMaster  : in  AxiStreamMasterType;
      sBypCtrl    : out AxiStreamCtrlType;
      mBypMaster  : out AxiStreamMasterType;
      mBypSlave   : in  AxiStreamSlaveType;
      -- Timing port (TIMING_EN_G only, sClk = mPrimClk): a frame swallowed at
      -- its SOF beat retires inbound; a stored EOFE frame retires outbound.
      -- At most one of the two fires for one frame.
      retireIb    : out EthMacTokenRetireType;
      retireOb    : out EthMacTokenRetireType);
end EthMacRxFifo;

architecture rtl of EthMacRxFifo is

   constant MAX_THRESH_SLV_C : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

   constant VALID_THOLD_C : natural := ite(DROP_ERR_PKT_G, 0, 1);

   type RegType is record
      rxFifoDrop      : sl;
      fifoPauseThresh : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      -- Timing mode: the previous input beat, which the inbound filter's
      -- registered drop strobes describe, and whether its frame lost its SOF
      prevValid       : sl;
      prevSof         : sl;
      prevLast        : sl;
      prevToken       : EthMacTokenType;
      sofSwallowed    : sl;
      retireIb        : EthMacTokenRetireType;
      retireOb        : EthMacTokenRetireType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rxFifoDrop      => '0',
      fifoPauseThresh => MAX_THRESH_SLV_C,
      prevValid       => '0',
      prevSof         => '0',
      prevLast        => '0',
      prevToken       => EMAC_TOKEN_NONE_C,
      sofSwallowed    => '0',
      retireIb        => ETH_MAC_TOKEN_RETIRE_INIT_C,
      retireOb        => ETH_MAC_TOKEN_RETIRE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal primDrop     : sl              := '0';
   signal bypDrop      : sl              := '0';
   signal primDropWord : sl              := '0';
   signal primObDrop   : sl              := '0';
   signal primObTId    : slv(7 downto 0) := (others => '0');

--   attribute dont_touch      : string;
--   attribute dont_touch of r : signal is "TRUE";

begin

   U_Fifo : entity surf.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => VALID_THOLD_C,
         PREVENT_LOCKUP_G    => not TIMING_EN_G,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_G,
         MASTER_AXI_CONFIG_G => PRIM_CONFIG_G)
      port map (
         sAxisClk        => sClk,
         sAxisRst        => sRst,
         sAxisMaster     => sPrimMaster,
         sAxisCtrl       => sPrimCtrl,
         sAxisDropWord   => primDropWord,
         sAxisDropFrame  => primDrop,
         mAxisDropFrame  => primObDrop,
         mAxisDropTId    => primObTId,
         fifoPauseThresh => r.fifoPauseThresh,
         mAxisClk        => mPrimClk,
         mAxisRst        => mPrimRst,
         mAxisMaster     => mPrimMaster,
         mAxisSlave      => mPrimSlave);

   BYP_DISABLED : if (BYP_EN_G = false) generate
      sBypCtrl   <= AXI_STREAM_CTRL_UNUSED_C;
      mBypMaster <= AXI_STREAM_MASTER_INIT_C;
   end generate;

   BYP_ENABLED : if (BYP_EN_G = true) generate
      U_Fifo : entity surf.SsiFifo
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            RST_POLARITY_G      => RST_POLARITY_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => VALID_THOLD_C,
            -- FIFO configurations
            SYNTH_MODE_G        => SYNTH_MODE_G,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            GEN_SYNC_FIFO_G     => PRIM_COMMON_CLK_G,
            FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
            FIFO_FIXED_THRESH_G => false,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => INT_CONFIG_G,
            MASTER_AXI_CONFIG_G => BYP_CONFIG_G)
         port map (
            sAxisClk        => sClk,
            sAxisRst        => sRst,
            sAxisMaster     => sBypMaster,
            sAxisCtrl       => sBypCtrl,
            sAxisDropFrame  => bypDrop,
            fifoPauseThresh => r.fifoPauseThresh,
            mAxisClk        => mBypClk,
            mAxisRst        => mBypRst,
            mAxisMaster     => mBypMaster,
            mAxisSlave      => mBypSlave);
   end generate;

   assert (TIMING_EN_G = false) or (PRIM_COMMON_CLK_G = true and BYP_EN_G = false and DROP_ERR_PKT_G = true)
      report "EthMacRxFifo: TIMING_EN_G requires PRIM_COMMON_CLK_G, DROP_ERR_PKT_G and no bypass"
      severity failure;

   comb : process (bypDrop, pauseThresh, phyReady, primDrop, primDropWord,
                   primObDrop, primObTId, r, sPrimMaster, sRst) is
      variable v         : RegType;
      variable swallowed : sl;
   begin
      -- Latch the current value
      v := r;

      -- OR-ing drop flags together
      v.rxFifoDrop := primDrop or bypDrop;

      -- Check the programmable threshold
      if pauseThresh >= (2**FIFO_ADDR_WIDTH_G)-1 then
         v.fifoPauseThresh := MAX_THRESH_SLV_C;
      else
         v.fifoPauseThresh := pauseThresh(FIFO_ADDR_WIDTH_G-1 downto 0);
      end if;

      -- Timing-mode retires. The inbound strobes are registered: they describe
      -- the beat the importer presented on the previous cycle (the importer
      -- cannot be stalled). A frame retires inbound only if its SOF beat was
      -- swallowed, so nothing of it is stored; a mid-frame overflow stores a
      -- terminated partial frame, which retires outbound when it is dropped.
      v.retireIb := ETH_MAC_TOKEN_RETIRE_INIT_C;
      v.retireOb := ETH_MAC_TOKEN_RETIRE_INIT_C;
      if TIMING_EN_G then
         swallowed := r.sofSwallowed;
         if (r.prevValid = '1') and (r.prevSof = '1') then
            swallowed := primDropWord;
         end if;
         if (r.prevValid = '1') and (r.prevLast = '1') and (primDrop = '1') and (swallowed = '1') and
            (r.prevToken /= EMAC_TOKEN_NONE_C) then
            v.retireIb.valid := '1';
            v.retireIb.token := r.prevToken;
         end if;
         v.sofSwallowed := swallowed;
         if (primObDrop = '1') and (primObTId(EMAC_TOKEN_BITS_C-1 downto 0) /= EMAC_TOKEN_NONE_C) then
            v.retireOb.valid := '1';
            v.retireOb.token := primObTId(EMAC_TOKEN_BITS_C-1 downto 0);
         end if;
         v.prevValid := sPrimMaster.tValid;
         v.prevSof   := axiStreamGetUserBit(INT_CONFIG_G, sPrimMaster, EMAC_SOF_BIT_C, 0);
         v.prevLast  := sPrimMaster.tLast;
         v.prevToken := sPrimMaster.tId(EMAC_TOKEN_BITS_C-1 downto 0);
      end if;

      -- Outputs
      rxFifoDrop <= r.rxFifoDrop;
      retireIb   <= r.retireIb;
      retireOb   <= r.retireOb;

      -- Link loss clears the legacy drop strobe and threshold only; the
      -- retire tracking must still report a frame the importer just ended.
      if (phyReady = '0') then
         v.rxFifoDrop      := REG_INIT_C.rxFifoDrop;
         v.fifoPauseThresh := REG_INIT_C.fifoPauseThresh;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and sRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sClk, sRst) is
   begin
      if (RST_ASYNC_G and sRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(sClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
