-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2DescEmulate.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-02
-- Last update: 2017-09-15
-------------------------------------------------------------------------------
-- Description:
-- Descriptor manager for AXI DMA read and write engines.
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiDmaPkg.all;
use work.ArbiterPkg.all;

entity AxiStreamDmaV2DescEmulate is
   generic (
      TPD_G             : time                  := 1 ns;
      AXI_CACHE_G       : slv(3 downto 0)       := "0000";
      READ_EN_G         : boolean               := false;
      CHAN_COUNT_G      : integer range 1 to 16 := 1;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)      := x"00000000";
      AXI_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_OK_C;
      AXI_READY_EN_G    : boolean               := false;
      AXI_CONFIG_G      : AxiConfigType         := AXI_CONFIG_INIT_C;
      DESC_AWIDTH_G     : integer range 4 to 12 := 12;
      DESC_ARB_G        : boolean               := true;
      ACK_WAIT_BVALID_G : boolean               := true);
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Local AXI Lite Bus
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Additional signals
      interrupt       : out sl;
      online          : out slv(CHAN_COUNT_G-1 downto 0);
      acknowledge     : out slv(CHAN_COUNT_G-1 downto 0);
      -- DMA write descriptor request, ack and return
      dmaWrDescReq    : in  AxiWriteDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescAck    : out AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRet    : in  AxiWriteDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : out slv(CHAN_COUNT_G-1 downto 0);
      -- DMA read descriptor request, ack and return
      dmaRdDescReq    : out AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescAck    : in  slv(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRet    : in  AxiReadDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : out slv(CHAN_COUNT_G-1 downto 0);
      -- Config
      axiCache        : out slv(3 downto 0);
      -- AXI Interface
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType := AXI_CTRL_UNUSED_C);
end AxiStreamDmaV2DescEmulate;

architecture rtl of AxiStreamDmaV2DescEmulate is

   type RegType is record

      -- Write descriptor interface
      dmaWrDescAck    : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

      -- Read descriptor interface
      dmaRdDescReq    : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

   end record RegType;

   constant REG_INIT_C : RegType := (
      dmaWrDescAck    => (others => AXI_WRITE_DMA_DESC_ACK_INIT_C),
      dmaWrDescRetAck => (others => '0'),
      dmaRdDescReq    => (others => AXI_READ_DMA_DESC_REQ_INIT_C),
      dmaRdDescRetAck => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   axilReadSlave   <= AXI_LITE_READ_SLAVE_INIT_C;
   axilWriteSlave  <= AXI_LITE_WRITE_SLAVE_INIT_C;
   interrupt       <= '0';
   online          <= (others=>'0');
   acknowledge     <= (others=>'0');
   axiWriteMaster  <= AXI_WRITE_MASTER_INIT_C;

   comb : process (axiRst, r, dmaRdDescAck, dmaRdDescRet, dmaWrDescReq, dmaWrDescRet) is
      variable v : RegType;
   begin

      --------------------------------------
      -- Write Descriptor Requests
      --------------------------------------

      -- Clear acks
      for i in 0 to CHAN_COUNT_G-1 loop
         v.dmaWrDescAck(i).valid := '0';

         if dmaWrDescReq(i).valid = '1' then
            v.dmaWrDescAck(i).valid    := '1';
            v.dmaWrDescAck(i).address  := r.dmaWrDescAck(i).Address  + 8192;
            v.dmaWrDescAck(i).dropEn   := '0';
            v.dmaWrDescAck(i).maxSize  := x"FFFFFFFF";
            v.dmaWrDescAck(i).contEn   :='1';
            v.dmaWrDescAck(i).buffId   := r.dmaWrDescAck(i).buffId + 1;
         end if;
      end loop;

      --------------------------------------
      -- Read/Write Descriptor Returns
      --------------------------------------

      for i in 0 to CHAN_COUNT_G-1 loop
         v.dmaWrDescRetAck(i) := dmaWrDescRet(i).valid;
         v.dmaRdDescRetAck(i) := dmaRdDescRet(i).valid;
      end loop;

      --------------------------------------
      -- Read Descriptor Requests
      --------------------------------------

      -- Clear requests
      for i in 0 to CHAN_COUNT_G-1 loop
         if dmaRdDescAck(i) = '1' then
            v.dmaRdDescReq(i).valid := '0';
         end if;
      end loop;

      for i in 0 to CHAN_COUNT_G-1 loop
         if v.dmaRdDescReq(i).valid = '0' and READ_EN_G then
            v.dmaRdDescReq(i)                     := AXI_READ_DMA_DESC_REQ_INIT_C;
            v.dmaRdDescReq(i).valid               := '1';
            v.dmaRdDescReq(i).address             := r.dmaRdDescReq(i).address + 8192;
            v.dmaRdDescReq(i).dest                := (others=>'0');
            v.dmaRdDescReq(i).size(23 downto 0)   := x"001000";
            v.dmaRdDescReq(i).firstUser           := (others=>'0');
            v.dmaRdDescReq(i).lastUser            := (others=>'0');
            v.dmaRdDescReq(i).buffId(11 downto 0) := r.dmaRdDescReq(i).buffId(11 downto 0) + 1;
            v.dmaRdDescReq(i).continue            := '0';
         end if;
      end loop;

      -- Reset      
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      dmaWrDescAck    <= r.dmaWrDescAck;
      dmaWrDescRetAck <= r.dmaWrDescRetAck;
      dmaRdDescReq    <= r.dmaRdDescReq;
      dmaRdDescRetAck <= r.dmaRdDescRetAck;
      axiCache        <= AXI_CACHE_G;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

