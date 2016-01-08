-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTxDesc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Transmit Descriptor Controller
-------------------------------------------------------------------------------
-- This file is part of 'SLAC SSI PCI-E Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC SSI PCI-E Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.SsiPciePkg.all;

entity SsiPcieTxDesc is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_SLVERR_C);      
   port (
      -- DMA Descriptor Interface 
      dmaDescToPci   : in  DescToPcieArray(DMA_SIZE_G-1 downto 0);
      dmaDescFromPci : out DescFromPcieArray(DMA_SIZE_G-1 downto 0);
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- IRQ Request
      irqReq         : out sl;
      -- Counter reset
      cntRst         : in  sl;
      -- Global Signals
      pciClk         : in  sl;
      pciRst         : in  sl); 
end SsiPcieTxDesc;

architecture rtl of SsiPcieTxDesc is

   type RegType is record
      wrDone        : sl;
      rdDone        : sl;
      reqIrq        : sl;
      txCount       : slv(31 downto 0);
      -- Transmit descriptor write
      tFifoDin      : slv(63 downto 0);
      tFifoWr       : slv(DMA_SIZE_G-1 downto 0);
      -- Done Descriptor Signals
      doneCnt       : natural range 0 to DMA_SIZE_G-1;
      doneAck       : slv(DMA_SIZE_G-1 downto 0);
      dFifoDin      : slv(31 downto 0);
      dFifoWr       : sl;
      dFifoRd       : sl;
      -- AXI-Lite
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      wrDone        => '0',
      rdDone        => '0',
      reqIrq        => '0',
      txCount       => (others => '0'),
      -- Transmit descriptor write
      tFifoDin      => (others => '0'),
      tFifoWr       => (others => '0'),
      -- Done Descriptor Signals
      doneCnt       => 0,
      doneAck       => (others => '0'),
      dFifoDin      => (others => '0'),
      dFifoWr       => '0',
      dFifoRd       => '0',
      -- AXI-Lite
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tFifoCnt     : Slv5Array(DMA_SIZE_G-1 downto 0);
   signal dmaDescAFull : slv(DMA_SIZE_G-1 downto 0);
   signal dFifoAFull   : sl;
   signal dFifoDout    : slv(31 downto 0);
   signal dFifoCnt     : slv(9 downto 0);
   signal dFifoValid   : sl;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   -- Assert IRQ when transmit desc is ready
   irqReq <= dFifoValid;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, cntRst, dFifoAFull, dFifoCnt, dFifoDout,
                   dFifoValid, dmaDescAFull, dmaDescToPci, pciRst, r, tFifoCnt) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable rdPntr       : natural;
      variable wrPntr       : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Calculate the address pointers
      wrPntr := conv_integer(axiWriteMaster.awaddr(5 downto 2));
      rdPntr := conv_integer(axiReadMaster.araddr(5 downto 2));

      -- Reset strobe signals
      v.tFifoWr := (others => '0');
      v.dFifoWr := '0';
      v.doneAck := (others => '0');
      v.dFifoRd := '0';

      -----------------------------
      -- AXI-Lite Write Logic
      -----------------------------      
      if (axiStatus.writeEnable = '1') then
         v.wrDone := '1';
         -- Check for alignment
         if axiWriteMaster.awaddr(1 downto 0) = "00" then
            -- Address is aligned
            axiWriteResp := AXI_RESP_OK_C;
            -- Decode address and perform write
            if (axiWriteMaster.awaddr(9 downto 6) = x"0") and (wrPntr < DMA_SIZE_G) then
               v.tFifoDin(31 downto 0) := axiWriteMaster.wdata;
            elsif (axiWriteMaster.awaddr(9 downto 6) = x"1") and (wrPntr < DMA_SIZE_G) then
               v.tFifoDin(63 downto 32) := axiWriteMaster.wdata;
               v.tFifoWr(wrPntr)        := not(r.wrDone);
            else
               axiWriteResp := AXI_ERROR_RESP_G;
            end if;
         else
            axiWriteResp := AXI_ERROR_RESP_G;
         end if;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      else
         v.wrDone := '0';
      end if;

      -----------------------------
      -- AXI-Lite Read Logic
      -----------------------------      
      if (axiStatus.readEnable = '1') then
         v.rdDone             := '1';
         -- Reset the bus
         v.axiReadSlave.rdata := (others => '0');
         -- Check for alignment
         if axiReadMaster.araddr(1 downto 0) = "00" then
            -- Address is aligned
            axiReadResp := AXI_RESP_OK_C;
            -- Decode address and perform write
            if (axiReadMaster.araddr(9 downto 6) = x"2") and (rdPntr < DMA_SIZE_G) then
               v.axiReadSlave.rdata(4 downto 0) := tFifoCnt(rdPntr);
            else
               case (axiReadMaster.araddr(9 downto 2)) is
                  when x"40" =>
                     v.axiReadSlave.rdata(DMA_SIZE_G-1 downto 0) := dmaDescAFull;
                  when x"41" =>
                     v.axiReadSlave.rdata(31)         := dFifoValid;
                     v.axiReadSlave.rdata(9 downto 0) := dFifoCnt;
                  when x"42" =>
                     v.axiReadSlave.rdata := r.txCount;
                  when x"43" =>
                     if r.rdDone = '0' then
                        -- Check if we need to read the FIFO
                        if dFifoValid = '1' then
                           v.axiReadSlave.rdata(31 downto 2) := dFifoDout(31 downto 2);
                           v.axiReadSlave.rdata(1)           := '0';
                           v.axiReadSlave.rdata(0)           := '1';
                           -- Reset the flag
                           v.reqIrq                          := '0';
                           -- Read the FIFO
                           v.dFifoRd                         := '1';
                        end if;
                     else
                        v.axiReadSlave.rdata := r.axiReadSlave.rdata;
                     end if;
                  when x"44" =>
                     v.axiReadSlave.rdata := r.tFifoDin(31 downto 0);
                  when x"45" =>
                     v.axiReadSlave.rdata := r.tFifoDin(63 downto 32);
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
            end if;
         end if;
         -- Send AXI response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      else
         v.rdDone := '0';
      end if;

      -----------------------------
      -- Done Descriptor Logic
      -----------------------------
      if (dFifoAFull = '0') and (r.dFifoWr = '0') then
         -- Poll the doneReq
         if dmaDescToPci(r.doneCnt).doneReq = '1' then
            v.doneAck(r.doneCnt)    := '1';
            v.txCount               := r.txCount + 1;
            v.dFifoWr               := '1';
            v.dFifoDin(31 downto 0) := dmaDescToPci(r.doneCnt).doneAddr & "00";
         end if;
         -- Increment DMA channel pointer counter
         if r.doneCnt = (DMA_SIZE_G-1) then
            v.doneCnt := 0;
         else
            v.doneCnt := r.doneCnt + 1;
         end if;
      end if;

      -----------------------------
      -- Generate interrupt
      -----------------------------
      if (r.reqIrq = '0') and (dFifoValid = '1') and (r.dFifoRd = '0') then
         v.reqIrq := '1';
      end if;

      -----------------------------
      -- Reset RX counter
      -----------------------------
      if cntRst = '1' then
         v.txCount := (others => '0');
      end if;

      -- Synchronous Reset
      if pciRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_FIFO :
   for i in 0 to (DMA_SIZE_G-1) generate
      SsiPcieTxDescFifo_Inst : entity work.SsiPcieTxDescFifo
         generic map(
            TPD_G => TPD_G)
         port map (
            pciClk     => pciClk,
            pciRst     => pciRst,
            tFifoWr    => r.tFifoWr(i),
            tFifoDin   => r.tFifoDin,
            tFifoCnt   => tFifoCnt(i),
            tFifoAFull => dmaDescAFull(i),
            newReq     => dmaDescToPci(i).newReq,
            newAck     => dmaDescFromPci(i).newAck,
            newAddr    => dmaDescFromPci(i).newAddr,
            newLength  => dmaDescFromPci(i).newLength,
            newDmaCh   => dmaDescFromPci(i).newDmaCh,
            newSubCh   => dmaDescFromPci(i).newSubCh);

      -- Done Ack
      dmaDescFromPci(i).doneAck  <= r.doneAck(i);
      -- Unused Fields
      dmaDescFromPci(i).maxFrame <= (others => '0');
   end generate GEN_FIFO;

   -- FIFO for done descriptors
   -- 31:0  = Addr
   U_RxFifo : entity work.FifoSync
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => true,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 32,
         FULL_THRES_G => 1020,
         ADDR_WIDTH_G => 10)    
      port map (
         rst        => pciRst,
         clk        => pciClk,
         din        => r.dFifoDin,
         wr_en      => r.dFifoWr,
         rd_en      => r.dFifoRd,
         dout       => dFifoDout,
         prog_full  => dFifoAFull,
         valid      => dFifoValid,
         data_count => dFifoCnt);

end rtl;
