-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SrpV3Axi.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-04-14
-- Last update: 2016-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SLAC Register Protocol Version 3, AXI Interface
--
-- Documentation: https://confluence.slac.stanford.edu/x/cRmVD
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
use work.AxiPkg.all;
use work.AxiDmaPkg.all;
use work.SrpV3Pkg.all;

entity SrpV3Axi is
   generic (
      TPD_G               : time                    := 1 ns;
      PIPE_STAGES_G       : natural range 0 to 16   := 0;
      FIFO_PAUSE_THRESH_G : positive range 1 to 511 := 256;
      SLAVE_READY_EN_G    : boolean                 := true;
      GEN_SYNC_FIFO_G     : boolean                 := false;
      ALTERA_SYN_G        : boolean                 := false;
      ALTERA_RAM_G        : string                  := "M9K";
      AXI_CLK_FREQ_G      : real                    := 156.25E+6;  -- units of Hz
      AXI_CONFIG_G        : AxiConfigType           := (33, 4, 1, 8);
      AXI_BURST_G         : slv(1 downto 0)         := "01";
      AXI_CACHE_G         : slv(3 downto 0)         := "1111";
      ACK_WAIT_BVALID_G   : boolean                 := true;
      AXI_STREAM_CONFIG_G : AxiStreamConfigType     := ssiAxiStreamConfig(2));
   port (
      -- AXIS Slave Interface (sAxisClk domain) 
      sAxisClk        : in  sl;
      sAxisRst        : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisCtrl       : out AxiStreamCtrlType;
      -- AXIS Master Interface (mAxisClk domain) 
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Master AXI Interface  (mAxiClk domain) 
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiWriteMaster : out AxiWriteMasterType;
      axiWriteSlave  : in  AxiWriteSlaveType;
      axiReadMaster  : out AxiReadMasterType;
      axiReadSlave   : in  AxiReadSlaveType);
end SrpV3Axi;

architecture rtl of SrpV3Axi is



   type RegType is record
      srpAck   : SrpV3AckType;
      wrDmaReq : AxiWriteDmaReqType;
      rdDmaReq : AxiReadDmaReqType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      srpAck   => SRPV3_ACK_INIT_C,
      wrDmaReq => AXI_WRITE_DMA_REQ_INIT_C,
      rdDmaReq => AXI_READ_DMA_REQ_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal srpReq      : SrpV3ReqType;
   signal wrDmaAck    : AxiWriteDmaAckType;
   signal rdDmaAck    : AxiReadDmaAckType;
   signal srpWrMaster : AxiStreamMasterType;
   signal srpWrSlave  : AxiStreamSlaveType;
   signal srpRdMaster : AxiStreamMasterType;
   signal srpRdSlave  : AxiStreamSlaveType;

   -- attribute dont_touch                    : string;
   -- attribute dont_touch of r               : signal is "TRUE";

begin

   U_SrpV3Core_1 : entity work.SrpV3Core
      generic map (
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         SRP_CLK_FREQ_G     => AXI_CLK_FREQ_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         sAxisClk    => sAxisClk,       -- [in]
         sAxisRst    => sAxisRst,       -- [in]
         sAxisMaster => sAxisMaster,    -- [in]
         sAxisSlave  => sAxisSlave,     -- [out]
         sAxisCtrl   => sAxisCtrl,      -- [out]
         mAxisClk    => mAxisClk,       -- [in]
         mAxisRst    => mAxisRst,       -- [in]
         mAxisMaster => mAxisMaster,    -- [out]
         mAxisSlave  => mAxisSlave,     -- [in]
         srpClk      => axiClk,         -- [in]
         srpRst      => axiRst,         -- [in]
         srpReq      => srpReq,         -- [out]
         srpAck      => r.srpAck,       -- [in]
         srpWrMaster => srpWrMaster,    -- [out]
         srpWrSlave  => srpWrSlave,     -- [in]
         srpRdMaster => srpRdMaster,    -- [in]
         srpRdSlave  => srpRdSlave);    -- [out]

   U_AxiStreamDmaWrite_1 : entity work.AxiStreamDmaWrite
      generic map (
         TPD_G             => TPD_G,
         AXI_READY_EN_G    => true,
         AXIS_CONFIG_G     => AXIS_CONFIG_C,
         AXI_CONFIG_G      => AXI_CONFIG_G,
         AXI_BURST_G       => AXI_BURST_G,
         AXI_CACHE_G       => AXI_CACHE_G,
         ACK_WAIT_BVALID_G => ACK_WAIT_BVALID_G)
      port map (
         axiClk         => axiClk,              -- [in]
         axiRst         => axiRst,              -- [in]
         dmaReq         => r.wrDmaReq,          -- [in]
         dmaAck         => wrDmaAck,            -- [out]
         axisMaster     => srpWrMaster,         -- [in]
         axisSlave      => srpWrSlave,          -- [out]
         axiWriteMaster => axiWriteMaster,      -- [out]
         axiWriteSlave  => axiWriteSlave,       -- [in]
         axiWriteCtrl   => AXI_CTRL_UNUSED_C);  -- [in]

   U_AxiStreamDmaRead_1 : entity work.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_G,
         AXI_BURST_G     => AXI_BURST_G,
         AXI_CACHE_G     => AXI_CACHE_G)
      port map (
         axiClk        => axiClk,                    -- [in]
         axiRst        => axiRst,                    -- [in]
         dmaReq        => r.rdDmaReq,                -- [in]
         dmaAck        => rdDmaAck,                  -- [out]
         axisMaster    => srpRdMaster,               -- [out]
         axisSlave     => srpRdSlave,                -- [in]
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,  -- [in]
         axiReadMaster => axiReadMaster,             -- [out]
         axiReadSlave  => axiReadSlave);             -- [in]


   comb : process (r, rdDmaAck, srpReq, wrDmaAck) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      v.wrDmaReq.request := srpReq.request and toSl(srpReq.opcode = SRP_WRITE_C or srpReq.opcode = SRP_POSTED_WRITE_C);
      v.wrDmaReq.address := srpReq.addr;
      v.wrDmaReq.maxSize := srpReq.reqSize;

      v.rdDmaReq.request := srpReq.request and toSl(srpReq.opcode = SRP_READ_C);
      v.rdDmaReq.address := srpReq.addr;
      v.rdDmaReq.size    := srpReq.reqSize;

      v.srpAck.done := '0';
      if (srpReq.request = '1') then
         if (srpReq.opcode = SRP_WRITE_C or srpReq.opcode = SRP_POSTED_WRITE_C) then
            v.srpAck.done                 := wrDmaAck.done;
            v.srpAck.respCode(1 downto 0) := wrDmaAck.errorValue;
         elsif (srpReq.opcode = SRP_READ_C) then
            v.srpAck.done                 := rdDmaAck.done;
            v.srpAck.respCode(1 downto 0) := rdDmaAck.errorValue;
         end if;
      end if;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   -- Outputs    
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
