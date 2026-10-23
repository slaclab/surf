-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 Configuration
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity RoceConfigurator is
   generic (
      TPD_G          : time    := 1 ns;   -- simulation propagation delay
      RST_POLARITY_G : sl      := '1';    -- '1' = active-HIGH reset, '0' = active-LOW
      RST_ASYNC_G    : boolean := false);  -- true = asynchronous reset
   port (
      -- Clock and Reset
      clk                     : in  sl;
      rst                     : in  sl;
      -- RoCE Metadata AXI stream Interface
      mAxisMetaDataReqMaster  : out AxiStreamMasterType;
      mAxisMetaDataReqSlave   : in  AxiStreamSlaveType;
      sAxisMetaDataRespMaster : in  AxiStreamMasterType;
      sAxisMetaDataRespSlave  : out AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilReadMaster          : in  AxiLiteReadMasterType;
      axilReadSlave           : out AxiLiteReadSlaveType;
      axilWriteMaster         : in  AxiLiteWriteMasterType;
      axilWriteSlave          : out AxiLiteWriteSlaveType;
      -- Soft-reset request (active high). A rising edge on the 0xF50 register
      -- fires a fixed-width one-shot here; the engine ORs it into the transport
      -- core's reset to clear stale QP/PSN state on a software reconnect.
      softRst                 : out sl);
end entity RoceConfigurator;

architecture rtl of RoceConfigurator is

   type StateType is (
      IDLE_S,
      DUMP_CONFIG_S,
      GET_RESPONSE_S);

   type RegType is record
      -- AXI-Lite Interface
      metaDataIsSet   : sl;
      metaDataTx      : slv(302 downto 0);
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
      -- RoCE Metadata AXI stream Interface
      metaDataIsReady : sl;
      metaDataRx      : slv(275 downto 0);
      txMaster        : AxiStreamMasterType;
      rxSlave         : AxiStreamSlaveType;
      state           : StateType;
      -- Soft-reset one-shot
      softRstReq      : sl;
      softRstCnt      : natural range 0 to 255;
      softRst         : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- AXI-Lite Interface
      metaDataIsSet   => '0',
      metaDataTx      => (others => '0'),
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      -- RoCE Metadata AXI stream Interface
      metaDataIsReady => '0',
      metaDataRx      => (others => '0'),
      txMaster        => AXI_STREAM_MASTER_INIT_C,
      rxSlave         => AXI_STREAM_SLAVE_INIT_C,
      state           => IDLE_S,
      -- Soft-reset one-shot
      softRstReq      => '0',
      softRstCnt      => 0,
      softRst         => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilReadMaster, axilWriteMaster, mAxisMetaDataReqSlave, r,
                   rst, sAxisMetaDataRespMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      ----------------------------------------------------------------------------------
      -- AXI-Lite Interface
      ----------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Gen registers
      axiSlaveRegister (axilEp, x"F00", 0, v.metaDataIsSet);
      axiSlaveRegister (axilEp, x"F04", 0, v.metaDataTx);
      axiSlaveRegisterR(axilEp, x"F00", 1, r.metaDataIsReady);
      axiSlaveRegisterR(axilEp, x"F2C", 0, r.metaDataRx);
      axiSlaveRegister (axilEp, x"F50", 0, v.softRstReq);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ----------------------------------------------------------------------------------
      -- RoCE Metadata AXI stream Interface
      ----------------------------------------------------------------------------------

      -- AXI stream flow control
      v.rxSlave.tReady := '0';
      if mAxisMetaDataReqSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      case r.state is
         -------------------------------------------------------------------------
         when IDLE_S =>
            -- Check for rising edge event
            if (r.metaDataIsSet = '0') and (v.metaDataIsSet = '1') then
               v.metaDataIsReady := '0';
               v.state           := DUMP_CONFIG_S;
            end if;
         -----------------------------------------------------------------------
         when DUMP_CONFIG_S =>
            v.txMaster.tData(302 downto 0) := r.metaDataTx;
            v.txMaster.tValid              := '1';
            if mAxisMetaDataReqSlave.tReady = '1' then
               v.state := GET_RESPONSE_S;
            end if;
         -----------------------------------------------------------------------
         when GET_RESPONSE_S =>
            if sAxisMetaDataRespMaster.tValid = '1' then
               v.rxSlave.tReady  := '1';
               v.metaDataRx      := sAxisMetaDataRespMaster.tData(275 downto 0);
               v.metaDataIsReady := '1';
               v.state           := IDLE_S;
            end if;
      -----------------------------------------------------------------------
      end case;

      ----------------------------------------------------------------------------------
      -- Soft-reset one-shot (0xF50)
      --
      -- A rising edge on softRstReq loads an 8-bit counter that holds softRst
      -- asserted for 256 clk cycles, giving the RoCE transport core a clean,
      -- FW-guaranteed reset pulse to clear stale QP/PSN state on a software
      -- reconnect. This logic is reset only by the hard 'rst' (the engine feeds
      -- this configurator the un-soft-reset 'rst'), so the request path itself
      -- survives the softRst it generates.
      ----------------------------------------------------------------------------------
      if (r.softRstReq = '0') and (v.softRstReq = '1') then
         v.softRstCnt := 255;
      elsif (r.softRstCnt /= 0) then
         v.softRstCnt := r.softRstCnt - 1;
      end if;
      v.softRst := ite(v.softRstCnt /= 0, '1', '0');

      -- Keep the metadata FSM in lockstep with the transport core across a
      -- soft-reset. softRst (0xF50) resets the core but NOT this configurator
      -- (the one-shot above must survive its own pulse). If the pulse lands
      -- while an exchange is in flight, the core never answers the pre-reset
      -- request and this FSM would stall forever in GET_RESPONSE_S, ignoring
      -- the next SendMetaData -- RecvMetaData never returns to 1, wedging the
      -- reconnect until an FPGA reload. Abort any in-flight exchange and hold
      -- IDLE_S for the pulse so the configurator comes out of soft-reset clean
      -- and resynced. The one-shot state (softRstReq/softRstCnt/softRst) is
      -- intentionally left untouched.
      if (v.softRst = '1') then
         v.state           := IDLE_S;
         v.txMaster.tValid := '0';
         v.metaDataIsReady := '0';
      end if;

      -- Outputs
      axilWriteSlave         <= r.axilWriteSlave;
      axilReadSlave          <= r.axilReadSlave;
      sAxisMetaDataRespSlave <= v.rxSlave;
      mAxisMetaDataReqMaster <= r.txMaster;
      softRst                <= r.softRst;

      -- Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register update
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
