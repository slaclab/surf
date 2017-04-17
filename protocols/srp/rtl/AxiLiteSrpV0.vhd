-------------------------------------------------------------------------------
-- File       : AxiLiteSrpV0.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-09
-- Last update: 2016-06-09
-------------------------------------------------------------------------------
-- Description: SLAC Register Protocol Version 0, AXI-Lite Interface
--
-- Documentation: https://confluence.slac.stanford.edu/x/aRmVD
--
-- Note: This module only supports 32-bit aligned addresses and 32-bit transactions.  
--
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteSrpV0 is
   generic (
      -- General Config
      TPD_G : time := 1 ns;

      AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;

      -- FIFO Config
      RESP_THOLD_G        : integer range 0 to (2**24) := 1;      -- =1 = normal operation
      SLAVE_READY_EN_G    : boolean                    := false;
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G      : boolean                    := false;  --if set to true, this module is only Xilinx compatible only!!!
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      GEN_SYNC_FIFO_G     : boolean                    := false;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 2**8;

      -- AXI Stream IO Config
      AXI_STREAM_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (

      -- Streaming Master (Tx) Data Interface (mAxisClk domain)
      mAxisClk    : in  sl;
      mAxisRst    : in  sl := '0';
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;

      -- Streaming Slave (Rx) Interface (sAxisClk domain) 
      sAxisClk    : in  sl;
      sAxisRst    : in  sl := '0';
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

      -- AXI Lite Bus Slave (axiLiteClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType
      );

end AxiLiteSrpV0;

architecture rtl of AxiLiteSrpV0 is

   constant INTERNAL_AXIS_CFG_C : AxiStreamConfigType := ssiAxiStreamConfig(16, TKEEP_COMP_C);

   constant TIMEOUT_COUNT_C : integer := 156250000;

   signal rxFifoAxisMaster : AxiStreamMasterType;
   signal rxFifoAxisSlave  : AxiStreamSlaveType;
   signal txFifoAxisMaster : AxiStreamMasterType;
   signal txFifoAxisSlave  : AxiStreamSlaveType;


   type StateType is (WAIT_AXIL_REQ_S, WAIT_AXIS_RESP_S, BLEED_S);

   type RegType is record
      state            : StateType;
      txnCount         : slv(31 downto 0);
      timeoutCount     : slv(31 downto 0);
      sAxilWriteSlave  : AxiLiteWriteSlaveType;
      sAxilReadSlave   : AxiLiteReadSlaveType;
      txFifoAxisMaster : AxiStreamMasterType;
      rxFifoAxisSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => WAIT_AXIL_REQ_S,
      txnCount         => (others => '0'),
      timeoutCount     => (others => '0'),
      sAxilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      txFifoAxisMaster => AXI_STREAM_MASTER_INIT_C,
      rxFifoAxisSlave  => AXI_STREAM_SLAVE_INIT_C);


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch                    : string;
   -- attribute dont_touch of r               : signal is "TRUE";
   -- attribute dont_touch of rxFifoAxisMaster : signal is "TRUE";
   -- attribute dont_touch of rxFifoAxisSlave  : signal is "TRUE";   
   -- attribute dont_touch of txFifoAxisMaster : signal is "TRUE";
   -- attribute dont_touch of txFifoAxisSlave  : signal is "TRUE";

begin

   ----------------------------------
   -- Output FIFO 
   ----------------------------------
   TxAxiStreamFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         INT_PIPE_STAGES_G   => 0,
         VALID_THOLD_G       => RESP_THOLD_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => INTERNAL_AXIS_CFG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         sAxisClk    => axilClk,
         sAxisRst    => axilRst,
         sAxisMaster => txFifoAxisMaster,
         sAxisSlave  => txFifoAxisSlave,
         sAxisCtrl   => open,
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   ----------------------------------
   -- Input FIFO 
   ----------------------------------
   RxAxiStreamFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         INT_PIPE_STAGES_G   => 0,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => INTERNAL_AXIS_CFG_C)
      port map (
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => sAxisCtrl,
         mAxisClk    => axilClk,
         mAxisRst    => axilRst,
         mAxisMaster => rxFifoAxisMaster,
         mAxisSlave  => rxFifoAxisSlave);

   -------------------------------------
   -- Master State Machine
   -------------------------------------

   comb : process (axilRst, r, rxFifoAxisMaster, sAxilReadMaster, sAxilWriteMaster, txFifoAxisSlave) is
      variable v  : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      v := r;

      v.rxFifoAxisSlave.tReady := '0';

      if (txFifoAxisSlave.tReady = '1') then
         v.txFifoAxisMaster.tValid := '0';
      end if;

      axiSlaveWaitTxn(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilStatus);

      case (r.state) is

         when WAIT_AXIL_REQ_S =>
            v.timeoutCount := (others => '0');
            if (axilStatus.writeEnable = '1') then
               v.txFifoAxisMaster.tData(31 downto 0)   := r.txnCount;
               v.txFifoAxisMaster.tData(61 downto 32)  := sAxilWriteMaster.awaddr(31 downto 2);
               v.txFifoAxisMaster.tData(63 downto 62)  := "01";               
               v.txFifoAxisMaster.tData(95 downto 64)  := sAxilWriteMaster.wdata(31 downto 0);
               v.txFifoAxisMaster.tData(127 downto 96) := (others => '0');
               v.txFifoAxisMaster.tKeep                := X"FFFF";
               v.txFifoAxisMaster.tValid               := '1';
               v.txFifoAxisMaster.tLast                := '1';
               ssiSetUserSof(INTERNAL_AXIS_CFG_C, v.txFifoAxisMaster, '1');
               v.state                                 := WAIT_AXIS_RESP_S;
            elsif (axilStatus.readEnable = '1') then
               v.txFifoAxisMaster.tData(31 downto 0)   := r.txnCount;
               v.txFifoAxisMaster.tData(61 downto 32)  := sAxilReadMaster.araddr(31 downto 2);
               v.txFifoAxisMaster.tData(63 downto 62)  := "00";
               v.txFifoAxisMaster.tData(95 downto 64)  := (others => '0');
               v.txFifoAxisMaster.tData(127 downto 96) := (others => '0');
               v.txFifoAxisMaster.tKeep                := X"FFFF";
               v.txFifoAxisMaster.tValid               := '1';
               v.txFifoAxisMaster.tLast                := '1';
               ssiSetUserSof(INTERNAL_AXIS_CFG_C, v.txFifoAxisMaster, '1');
               v.state                                 := WAIT_AXIS_RESP_S;
            end if;

         when WAIT_AXIS_RESP_S =>
            v.timeoutCount := r.timeoutCount + 1;
            if (rxFifoAxisMaster.tValid = '1') then
               v.txnCount               := r.txnCount + 1;
               v.rxFifoAxisSlave.tReady := '1';

               -- Check write response
               if (axilStatus.writeEnable = '1') then
                  if (rxFifoAxisMaster.tData(31 downto 0) = r.txnCount and
                      rxFifoAxisMaster.tData(61 downto 32) = sAxilWriteMaster.awaddr(31 downto 2) and
                      rxFifoAxisMaster.tData(63 downto 62) = "01" and
                      rxFifoAxisMaster.tData(95 downto 64) = sAxilWriteMaster.wdata and
                      rxFifoAxisMaster.tData(127 downto 96) = 0 and
                      rxFifoAxisMaster.tKeep = X"FFFF" and
                      rxFifoAxisMaster.tLast = '1' and
                      ssiGetUserSof(INTERNAL_AXIS_CFG_C, rxFifoAxisMaster) = '1')
                  then
                     axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);
                     v.state := WAIT_AXIL_REQ_S;
                  elsif (rxFifoAxisMaster.tLast = '0') then
                     axiSlaveWriteResponse(v.sAxilWriteSlave, AXIL_ERR_RESP_G);
                     v.state := BLEED_S;
                  else
                     axiSlaveWriteResponse(v.sAxilWriteSlave, AXIL_ERR_RESP_G);
                     v.state := WAIT_AXIL_REQ_S;                     
                  end if;

               -- Check read response
               elsif (axilStatus.readEnable = '1') then
                  if (rxFifoAxisMaster.tData(31 downto 0) = r.txnCount and
                      rxFifoAxisMaster.tData(61 downto 32) = sAxilReadMaster.araddr(31 downto 2) and
                      rxFifoAxisMaster.tData(63 downto 62) = "00" and                      
                      rxFifoAxisMaster.tData(127 downto 96) = 0 and
                      rxFifoAxisMaster.tKeep = X"FFFF" and
                      rxFifoAxisMaster.tLast = '1' and
                      ssiGetUserSof(INTERNAL_AXIS_CFG_C, rxFifoAxisMaster) = '1')
                  then
                     v.sAxilReadSlave.rdata := rxFifoAxisMaster.tdata(95 downto 64);
                     axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);
                     v.state               := WAIT_AXIL_REQ_S;
                  elsif (rxFifoAxisMaster.tLast = '0') then
                     v.sAxilReadSlave.rdata := (others => '1');
                     axiSlaveReadResponse(v.sAxilReadSlave, AXIL_ERR_RESP_G);
                     v.state := BLEED_S;
                  else
                     v.sAxilReadSlave.rdata := (others => '1');                     
                     axiSlaveReadResponse(v.sAxilReadSlave, AXIL_ERR_RESP_G);
                     v.state               := WAIT_AXIL_REQ_S;                     
                  end if;
               end if;

            -- Handle timeout
            elsif (r.timeoutCount = TIMEOUT_COUNT_C) then
               if (axilStatus.writeEnable = '1') then
                  axiSlaveWriteResponse(v.sAxilWriteSlave, AXIL_ERR_RESP_G);
               else
                  v.sAxilReadSlave.rdata := (others => '1');                  
                  axiSlaveReadResponse(v.sAxilReadSlave, AXIL_ERR_RESP_G);
               end if;
            end if;

         when BLEED_S =>
            v.rxFifoAxisSlave.tReady := '1';
            if (rxFifoAxisMaster.tValid = '1' and rxFifoAxisMaster.tLast = '1') then
               v.state := WAIT_AXIL_REQ_S;
            end if;
      end case;


      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave  <= r.sAxilWriteSlave;
      sAxilReadSlave   <= r.sAxilReadSlave;
      txFifoAxisMaster <= r.txFifoAxisMaster;
      rxFifoAxisSlave  <= v.rxFifoAxisSlave;


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

