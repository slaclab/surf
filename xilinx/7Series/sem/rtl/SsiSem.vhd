-------------------------------------------------------------------------------
-- File       : SsiSem.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2017-02-08
-------------------------------------------------------------------------------
-- Description: SSI wrapper for 7-series SEM module
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

use work.StdRtlPkg.all;
use work.TextUtilPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SemPkg.all;

entity SsiSem is
   generic (
      TPD_G               : time                := 1 ns;
      AXI_ERROR_RESP_G    : slv(1 downto 0)     := AXI_RESP_SLVERR_C;
      COMMON_AXIL_CLK_G   : boolean             := false;
      COMMON_AXIS_CLK_G   : boolean             := false;
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(1);
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(1));
   port (
      -- SEM clock and reset
      semClk          : in  sl;
      semRst          : in  sl;
      -- IPROG Interface
      fpgaReload      : in  sl               := '0';
      fpgaReloadAddr  : in  slv(31 downto 0) := (others => '0');
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      moduleIndex     : in  slv(3 downto 0)  := x"0";
      -- AXI-Lite Interface
      axisClk         : in  sl;
      axisRst         : in  sl;
      semObAxisMaster : out AxiStreamMasterType;
      semObAxisSlave  : in  AxiStreamSlaveType;
      semIbAxisMaster : in  AxiStreamMasterType;
      semIbAxisSlave  : out AxiStreamSlaveType);
end entity SsiSem;

architecture rtl of SsiSem is

   constant SEM_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);
   constant RET_CHAR_C        : character           := cr;
   constant RET_SLV_C         : slv(7 downto 0)     := conv_std_logic_vector(character'pos(RET_CHAR_C), 8);

   type RegType is record
      sofNext          : sl;
      count            : slv(2 downto 0);
      heartbeatCount   : slv(31 downto 0);
      iprogIcapReqLast : sl;
      semIb            : SemIbType;
      axiWriteSlave    : AxiLiteWriteSlaveType;
      axiReadSlave     : AxiLiteReadSlaveType;
      txSsiMaster      : SsiMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sofNext          => '1',
      count            => (others => '0'),
      heartbeatCount   => (others => '0'),
      iprogIcapReqLast => '0',
      semIb            => SEM_IB_INIT_C,
      axiWriteSlave    => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave     => AXI_LITE_READ_SLAVE_INIT_C,
      txSsiMaster      => ssiMasterInit(SEM_AXIS_CONFIG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;

   signal txAxisMaster : AxiStreamMasterType;
   signal txAxisCtrl   : AxiStreamCtrlType;
   signal rxAxisMaster : AxiStreamMasterType;
   signal rxAxisSlave  : AxiStreamSlaveType;

   signal statusIdle   : sl;
   signal statusHalted : sl;
   signal semIb        : SemIbType;
   signal semOb        : SemObType;
   signal idx          : slv(3 downto 0);

   -- attribute dont_touch            : string;
   -- attribute dont_touch of r       : signal is "TRUE";

begin

   ------------------------------   
   --  Soft Error Mitigation Core
   ------------------------------   
   U_Sem : entity work.SemWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         semClk => semClk,
         semRst => semRst,
         -- SEM Interface
         semIb  => semIb,
         semOb  => semOb);

   ------------------------
   -- Sync the Module index
   ------------------------
   U_SyncFifo : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_AXIL_CLK_G,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => 4,
         ADDR_WIDTH_G => 4)
      port map (
         rst    => axilRst,
         wr_clk => axilClk,
         din    => moduleIndex,
         rd_clk => semClk,
         dout   => idx);

   -------------------------------------
   -- Synchronize AXI-Lite bus to semClk
   -------------------------------------
   U_AxiLiteAsync : entity work.AxiLiteAsync
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         COMMON_CLK_G     => COMMON_AXIL_CLK_G)
      port map (
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         mAxiClk         => semClk,
         mAxiClkRst      => semRst,
         mAxiReadMaster  => axiReadMaster,
         mAxiReadSlave   => axiReadSlave,
         mAxiWriteMaster => axiWriteMaster,
         mAxiWriteSlave  => axiWriteSlave);

   ---------------------------------
   -- Synchronize AXIS bus to semClk
   ---------------------------------
   U_TxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 0,
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_AXIS_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 14,
         SLAVE_AXI_CONFIG_G  => SEM_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
      port map (
         sAxisClk    => semClk,
         sAxisRst    => semRst,
         sAxisMaster => txAxisMaster,
         sAxisCtrl   => txAxisCtrl,
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => semObAxisMaster,
         mAxisSlave  => semObAxisSlave);

   U_RxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_AXIS_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 14,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(1))
      port map (
         sAxisClk    => axisClk,
         sAxisRst    => axisRst,
         sAxisMaster => semIbAxisMaster,
         sAxisSlave  => semIbAxisSlave,
         mAxisClk    => semClk,
         mAxisRst    => semRst,
         mAxisMaster => rxAxisMaster,
         mAxisSlave  => rxAxisSlave);

   ------------------------------
   -- Determined the state of SEM
   ------------------------------
   statusIdle   <= not (semOb.initialization or semOb.observation or semOb.correction or semOb.classification or semOb.injection);
   statusHalted <= (semOb.initialization and semOb.observation and semOb.correction and semOb.classification and semOb.injection);

   comb : process (axiReadMaster, axiWriteMaster, idx, r, rxAxisMaster, semOb,
                   semRst, statusHalted, statusIdle, txAxisCtrl) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable c      : integer range 0 to 7;
   begin
      -- Latch the current value   
      v := r;

      -- Reset strobes
      v.semIb.injectStrobe := '0';

      -- Count heartbeats
      if (semOb.heartbeat = '1') then
         v.heartbeatCount := r.heartbeatCount + 1;
      end if;

      ---------------------------------------------------
      -- Convert tx data stream to 64-bit wide SSI frames
      ---------------------------------------------------
      if (r.sofNext = '1') then
         v.txSsiMaster.data(7 downto 0)   := toSlv(character'pos('F'), 8);
         v.txSsiMaster.data(15 downto 8)  := toSlv(character'pos('E'), 8);
         v.txSsiMaster.data(23 downto 16) := toSlv(character'pos('B'), 8);
         v.txSsiMaster.data(31 downto 24) := toSlv(character'pos(' '), 8);
         v.txSsiMaster.data(39 downto 32) := toSlv(character'pos('0'), 8);
         case idx is
            when X"0" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('0'), 8);
            when X"1" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('1'), 8);
            when X"2" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('2'), 8);
            when X"3" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('3'), 8);
            when X"4" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('4'), 8);
            when X"5" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('5'), 8);
            when X"6" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('6'), 8);
            when X"7" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('7'), 8);
            when X"8" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('8'), 8);
            when X"9" =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('9'), 8);
            when others =>
               v.txSsiMaster.data(47 downto 40) := toSlv(character'pos('?'), 8);
         end case;
         v.txSsiMaster.data(55 downto 48) := toSlv(character'pos(':'), 8);
         v.txSsiMaster.data(63 downto 56) := toSlv(character'pos(' '), 8);
         v.txSsiMaster.valid              := '1';
         v.txSsiMaster.sof                := '1';
         v.txSsiMaster.eof                := '0';
         v.count                          := (others => '0');
         v.sofNext                        := '0';
      else
         if (semOb.txWrite = '1') then
            v.count := r.count + 1;
         end if;
         -- Stupid Vivado can't handle dynamic ranges properly so we have to do this shit instead
         c := conv_integer(r.count);
         case c is
            when 0 => v.txSsiMaster.data := (others => '0');
                      v.txSsiMaster.data(7 downto 0) := semOb.txData;
            when 1 => v.txSsiMaster.data(15 downto 8)  := semOb.txData;
            when 2 => v.txSsiMaster.data(23 downto 16) := semOb.txData;
            when 3 => v.txSsiMaster.data(31 downto 24) := semOb.txData;
            when 4 => v.txSsiMaster.data(39 downto 32) := semOb.txData;
            when 5 => v.txSsiMaster.data(47 downto 40) := semOb.txData;
            when 6 => v.txSsiMaster.data(55 downto 48) := semOb.txData;
            when 7 => v.txSsiMaster.data(63 downto 56) := semOb.txData;
         end case;

         v.txSsiMaster.valid := toSl((c = 7) or (semOb.txData = RET_SLV_C)) and semOb.txWrite;
         v.txSsiMaster.sof   := '0';
         v.txSsiMaster.eof   := toSl(semOb.txData = RET_SLV_C) and semOb.txWrite;

         if (v.txSsiMaster.valid = '1') then
            -- Reset count on EOF so next frame starts at 0
            if (v.txSsiMaster.eof = '1') then
               v.sofNext := '1';
            end if;
         end if;
      end if;

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------   

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      axiSlaveRegisterR(axilEp, x"00", 0, semOb.initialization);
      axiSlaveRegisterR(axilEp, x"00", 1, semOb.observation);
      axiSlaveRegisterR(axilEp, x"00", 2, semOb.correction);
      axiSlaveRegisterR(axilEp, x"00", 3, semOb.classification);
      axiSlaveRegisterR(axilEp, x"00", 4, semOb.injection);
      axiSlaveRegisterR(axilEp, x"00", 5, statusIdle);
      axiSlaveRegisterR(axilEp, x"00", 6, statusHalted);
      axiSlaveRegisterR(axilEp, x"00", 7, semOb.essential);
      axiSlaveRegisterR(axilEp, x"00", 8, semOb.uncorrectable);
      axiSlaveRegisterR(axilEp, x"04", 0, r.heartbeatCount);
      axiSlaveRegister(axilEp, x"0C", 0, v.semIb.injectStrobe);
      axiSlaveRegister(axilEp, x"10", 0, v.semIb.injectAddress(31 downto 0));
      axiSlaveRegister(axilEp, x"14", 0, v.semIb.injectAddress(39 downto 32));

      axiSlaveDefault(axilEp, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);

      -----------------------------
      -- Allow IPROG access to ICAP
      -----------------------------
      v.iprogIcapReqLast := semOb.iprogIcapReq;
      if (semOb.iprogIcapReq = '1' and r.iprogIcapReqLast = '0') then
         v.semIb.injectStrobe  := '1';
         v.semIb.injectAddress := X"E000000000";
      end if;

      --------
      -- Reset
      --------
      if (semRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave         <= r.axiReadSlave;
      axiWriteSlave        <= r.axiWriteSlave;
      semIb                <= r.semIb;
      semIb.iprogIcapGrant <= statusIdle and semOb.iprogIcapReq;
      semIb.rxData         <= rxAxisMaster.tData(7 downto 0);
      semIb.rxEmpty        <= not(rxAxisMaster.tValid);
      semIb.txFull         <= txAxisCtrl.pause;
      txAxisMaster         <= ssi2AxisMaster(SEM_AXIS_CONFIG_C, r.txSsiMaster);
      rxAxisSlave.tReady   <= semOb.rxRead;

   end process comb;

   seq : process (semClk) is
   begin
      if (rising_edge(semClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
