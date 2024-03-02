-------------------------------------------------------------------------------
-- Title      : AxiStream BatcherV1 Protocol: https://confluence.slac.stanford.edu/x/th1SDg
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite wrapper for AXI-Stream Batcher
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity AxiStreamBatcherAxil is
   generic (
      TPD_G                        : time     := 1 ns;
      COMMON_CLOCK_G               : boolean  := false;
      MAX_NUMBER_SUB_FRAMES_G      : positive := 32;
      SUPER_FRAME_BYTE_THRESHOLD_G : natural  := 8192;
      MAX_CLK_GAP_G                : natural  := 256;
      AXIS_CONFIG_G                : AxiStreamConfigType;
      INPUT_PIPE_STAGES_G          : natural  := 0;
      OUTPUT_PIPE_STAGES_G         : natural  := 1);
   port (
      -- AXIS Interfaces (axisClk domain)
      axisClk         : in  sl;
      axisRst         : in  sl;
      idle            : out sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity AxiStreamBatcherAxil;

architecture rtl of AxiStreamBatcherAxil is

   type RegType is record
      softRst                 : sl;
      blowoff                 : sl;
      superFrameByteThreshold : slv(31 downto 0);
      maxSubFrames            : slv(15 downto 0);
      maxClkGap               : slv(31 downto 0);
      axilReadSlave           : AxiLiteReadSlaveType;
      axilWriteSlave          : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      softRst                 => '0',
      blowoff                 => '0',
      superFrameByteThreshold => toSlv(SUPER_FRAME_BYTE_THRESHOLD_G, 32),
      maxSubFrames            => toSlv(MAX_NUMBER_SUB_FRAMES_G, 16),
      maxClkGap               => toSlv(MAX_CLK_GAP_G, 32),
      axilReadSlave           => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave          => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal syncAxilReadMaster  : AxiLiteReadMasterType;
   signal syncAxilReadSlave   : AxiLiteReadSlaveType;
   signal syncAxilWriteMaster : AxiLiteWriteMasterType;
   signal syncAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal axisReset     : sl;
   signal batcherIdle   : sl;
   signal sAxisSlaveTmp : AxiStreamSlaveType;

begin

   idle <= batcherIdle;

   U_AxiStreamBatcher : entity surf.AxiStreamBatcher
      generic map (
         TPD_G                        => TPD_G,
         MAX_NUMBER_SUB_FRAMES_G      => MAX_NUMBER_SUB_FRAMES_G,
         SUPER_FRAME_BYTE_THRESHOLD_G => SUPER_FRAME_BYTE_THRESHOLD_G,
         MAX_CLK_GAP_G                => MAX_CLK_GAP_G,
         AXIS_CONFIG_G                => AXIS_CONFIG_G,
         INPUT_PIPE_STAGES_G          => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G         => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk                 => axisClk,                    -- [in]
         axisRst                 => axisReset,                  -- [in]
         superFrameByteThreshold => r.superFrameByteThreshold,  -- [in]
         maxSubFrames            => r.maxSubFrames,             -- [in]
         maxClkGap               => r.maxClkGap,                -- [in]
         idle                    => batcherIdle,                -- [out]
         sAxisMaster             => sAxisMaster,                -- [in]
         sAxisSlave              => sAxisSlaveTmp,              -- [out]
         mAxisMaster             => mAxisMaster,                -- [out]
         mAxisSlave              => mAxisSlave);                -- [in]

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLOCK_G)
      port map (
         sAxiClk         => axilClk,              -- [in]
         sAxiClkRst      => axilClk,              -- [in]
         sAxiReadMaster  => axilReadMaster,       -- [in]
         sAxiReadSlave   => axilReadSlave,        -- [out]
         sAxiWriteMaster => axilWriteMaster,      -- [in]
         sAxiWriteSlave  => axilWriteSlave,       -- [out]
         mAxiClk         => axisClk,              -- [in]
         mAxiClkRst      => axisRst,              -- [in]
         mAxiReadMaster  => syncAxilReadMaster,   -- [out]
         mAxiReadSlave   => r.axilReadSlave,      -- [in]
         mAxiWriteMaster => syncAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => r.axilWriteSlave);    -- [in]

   comb : process (axisRst, batcherIdle, r, sAxisSlaveTmp, syncAxilReadMaster,
                   syncAxilWriteMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.softRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, syncAxilWriteMaster, syncAxilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      axiSlaveRegister (axilEp, X"00", 0, v.superFrameByteThreshold);
      axiSlaveRegister (axilEp, X"04", 0, v.maxSubFrames);
      axiSlaveRegister (axilEp, X"08", 0, v.maxClkGap);
      axiSlaveRegisterR(axilEp, X"0C", 0, batcherIdle);
      axiSlaveRegister (axilEp, x"F8", 0, v.blowOff);
      axiSlaveRegister (axilEp, x"FC", 0, v.softRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Outputs
      axisReset         <= axisRst or r.softRst or r.blowOff;
      sAxisSlave.tReady <= sAxisSlaveTmp.tReady or r.blowOff;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
