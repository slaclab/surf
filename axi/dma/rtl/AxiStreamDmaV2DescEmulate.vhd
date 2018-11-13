-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2DescEmulate.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Emulates the firmware/software descriptor manager 
--              for AXI DMA read and write engines.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiDmaPkg.all;
use surf.ArbiterPkg.all;

--! Entity declaration for AxiStreamDmaV2DescEmulate
entity AxiStreamDmaV2DescEmulate is
   generic (
      TPD_G             : time                  := 1 ns;
      AXI_CACHE_G       : slv(3 downto 0)       := "0000";
      CHAN_COUNT_G      : integer range 1 to 16 := 1;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)      := x"00000000";
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
      axilReadSlave   : out AxiLiteReadSlaveType         := AXI_LITE_READ_SLAVE_EMPTY_OK_C;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType        := AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
      -- Additional signals
      interrupt       : out sl                           := '0';
      online          : out slv(CHAN_COUNT_G-1 downto 0) := (others => '0');
      acknowledge     : out slv(CHAN_COUNT_G-1 downto 0) := (others => '0');
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
      axiRdCache      : out slv(3 downto 0)              := AXI_CACHE_G;
      axiWrCache      : out slv(3 downto 0)              := AXI_CACHE_G;
      -- AXI Interface
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiWriteCtrl    : in  AxiCtrlType                  := AXI_CTRL_UNUSED_C);
end AxiStreamDmaV2DescEmulate;

--! architecture declaration
architecture rtl of AxiStreamDmaV2DescEmulate is

   type RegType is record
      dmaWrDescAck    : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
      dmaWrDescRetAck : slv(CHAN_COUNT_G-1 downto 0);
      dmaRdDescReq    : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
      dmaRdDescRetAck : slv(CHAN_COUNT_G-1 downto 0);
      wrIndex         : Slv8Array(CHAN_COUNT_G-1 downto 0);
      rdIndex         : Slv8Array(CHAN_COUNT_G-1 downto 0);
      fillCnt         : Slv8Array(CHAN_COUNT_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      dmaWrDescAck    => (others => AXI_WRITE_DMA_DESC_ACK_INIT_C),
      dmaWrDescRetAck => (others => '0'),
      dmaRdDescReq    => (others => AXI_READ_DMA_DESC_REQ_INIT_C),
      dmaRdDescRetAck => (others => '0'),
      wrIndex         => (others => (others => '0')),
      rdIndex         => (others => (others => '0')),
      fillCnt         => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   axilReadSlave  <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
   axilWriteSlave <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
   interrupt      <= '0';
   online         <= (others => '0');
   acknowledge    <= (others => '0');
   axiWriteMaster <= AXI_WRITE_MASTER_INIT_C;

   comb : process (axiRst, dmaRdDescAck, dmaRdDescRet, dmaWrDescReq,
                   dmaWrDescRet, r) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value   
      v := r;

      -- Loop through the DMA lanes
      for i in CHAN_COUNT_G-1 downto 0 loop

         -- Reset strobes
         v.dmaWrDescAck(i).valid := '0';
         v.dmaWrDescRetAck(i)    := '0';
         v.dmaRdDescRetAck(i)    := '0';

         -- Flow control
         if dmaRdDescAck(i) = '1' then
            v.dmaRdDescReq(i).valid := '0';
         end if;
         if dmaRdDescRet(i).valid = '1' then
            -- Reset the flag
            v.dmaRdDescRetAck(i) := '1';
            -- Increment the read index
            v.rdIndex(i)         := r.rdIndex(i) + 1;
         end if;

         -- Update the fill counter
         v.fillCnt(i) := r.wrIndex(i) - r.rdIndex(i);

         -- Check for the REQ and not out of buffers
         if (dmaWrDescReq(i).valid = '1') and (r.dmaWrDescAck(i).valid = '0') and (r.fillCnt(i) /= x"FF") then
            -- Send the write descriptor
            v.dmaWrDescAck(i).valid                 := '1';
            v.dmaWrDescAck(i).address(19 downto 12) := r.wrIndex(i);  -- Write index
            v.dmaWrDescAck(i).address(23 downto 20) := toSlv(i, 4);  -- DMA Channel index
            v.dmaWrDescAck(i).dropEn                := '0';
            v.dmaWrDescAck(i).maxSize               := toSlv(2**12, 32);  -- 4kB buffers
            v.dmaWrDescAck(i).contEn                := '1';
            v.dmaWrDescAck(i).buffId(7 downto 0)    := r.wrIndex(i);
            -- Increment the write index
            v.wrIndex(i)                            := r.wrIndex(i) + 1;
         end if;

         -- Check for the return descriptor   
         if (dmaWrDescRet(i).valid = '1') and (r.dmaRdDescReq(i).valid = '0') then
            -- Respond with ACK
            v.dmaWrDescRetAck(i)                    := '1';
            -- Send the read request
            v.dmaRdDescReq(i).valid                 := '1';
            v.dmaRdDescReq(i).address(19 downto 12) := dmaWrDescRet(i).buffId(7 downto 0);  -- Write index
            v.dmaRdDescReq(i).address(23 downto 20) := toSlv(i, 4);  -- DMA Channel index            
            v.dmaRdDescReq(i).buffId                := dmaWrDescRet(i).buffId;
            v.dmaRdDescReq(i).firstUser             := dmaWrDescRet(i).firstUser;
            v.dmaRdDescReq(i).lastUser              := dmaWrDescRet(i).lastUser;
            v.dmaRdDescReq(i).size                  := dmaWrDescRet(i).size;
            v.dmaRdDescReq(i).continue              := dmaWrDescRet(i).continue;
            v.dmaRdDescReq(i).id                    := dmaWrDescRet(i).id;
            v.dmaRdDescReq(i).dest                  := dmaWrDescRet(i).dest;
         end if;

      end loop;

      -- Outputs
      dmaWrDescAck    <= r.dmaWrDescAck;
      dmaWrDescRetAck <= r.dmaWrDescRetAck;
      dmaRdDescReq    <= r.dmaRdDescReq;
      dmaRdDescRetAck <= r.dmaRdDescRetAck;

      -- Reset      
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
