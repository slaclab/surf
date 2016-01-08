-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTxDmaMemReq.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe TX DMA Engine's Memory Requester
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieTxDmaMemReq is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- DMA Interface
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPcieType;
      dmaDescToPci   : out DescToPcieType;
      dmaTranFromPci : in  TranFromPcieType;
      -- Transaction Interface
      start          : out sl;
      done           : in  sl;
      pause          : in  sl;
      remLength      : in  slv(23 downto 0);
      newDmaCh       : out slv(3 downto 0);
      newSubCh       : out slv(3 downto 0);
      newLength      : out slv(23 downto 0);
      -- Clock and reset     
      pciClk         : in  sl;
      pciRst         : in  sl);      
end SsiPcieTxDmaMemReq;

architecture rtl of SsiPcieTxDmaMemReq is

   type StateType is (
      IDLE_S,
      CHECK_THRESH_S,
      SEND_IO_REQ_HDR_S,
      CALC_PIPELINE_DLY_S,
      CHECK_LENGTH_S,
      TR_DONE_S);    

   type RegType is record
      start        : sl;
      cnt          : slv(3 downto 0);
      newDmaCh     : slv(3 downto 0);
      newSubCh     : slv(3 downto 0);
      tranLength   : slv(8 downto 0);
      newLength    : slv(23 downto 0);
      pendLength   : slv(23 downto 0);
      reqLength    : slv(23 downto 0);
      newAddr      : slv(29 downto 0);
      dmaDescToPci : DescToPcieType;
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      start        => '0',
      cnt          => (others => '0'),
      newDmaCh     => (others => '0'),
      newSubCh     => (others => '0'),
      tranLength   => (others => '0'),
      newLength    => (others => '0'),
      pendLength   => (others => '0'),
      reqLength    => (others => '0'),
      newAddr      => (others => '0'),
      dmaDescToPci => DESC_TO_PCIE_INIT_C,
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (dmaDescFromPci, dmaIbSlave, dmaTranFromPci, done, pause, pciRst, r, remLength) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.start := '0';

      -- Update tValid register
      if dmaIbSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- Calculate the length difference
      v.pendLength := remLength - r.reqLength;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Ready to send request memory headers
            v.dmaDescToPci.newReq := '1';
            -- Wait for descriptor to ACK
            if dmaDescFromPci.newAck = '1' then
               -- De-assert request to descriptor
               v.dmaDescToPci.newReq   := '0';
               -- Start the completion process
               v.start                 := '1';
               -- Latch the descriptor values
               v.dmaDescToPci.doneAddr := dmaDescFromPci.newAddr;
               v.newLength             := dmaDescFromPci.newLength;
               v.newDmaCh              := dmaDescFromPci.newDmaCh;
               v.newSubCh              := dmaDescFromPci.newSubCh;
               v.newAddr               := dmaDescFromPci.newAddr;
               v.reqLength             := dmaDescFromPci.newLength;
               -- Reset the pending length for next state (won't be updated yet) 
               v.pendLength            := (others => '0');
               -- Reset the counter
               v.cnt                   := x"0";
               -- Next state
               v.state                 := CHECK_THRESH_S;
            end if;
         ----------------------------------------------------------------------
         when CHECK_THRESH_S =>
            -- Check pending threshold
            if (r.pendLength < (PCIE_MAX_TX_TRANS_LENGTH_C/2)) then
               -- Calculate the transaction length
               if r.reqLength < PCIE_MAX_TX_TRANS_LENGTH_C then
                  v.tranLength := r.reqLength(8 downto 0);
               else
                  v.tranLength := toSlv(PCIE_MAX_TX_TRANS_LENGTH_C, 9);
               end if;
               -- Next state
               v.state := SEND_IO_REQ_HDR_S;
            end if;
         ----------------------------------------------------------------------
         when SEND_IO_REQ_HDR_S =>
            -- Check if the FIFO is ready
            if (v.txMaster.tValid = '0') then
               ------------------------------------------------------
               -- generated a TLP 3-DW data transfer without payload 
               --
               -- data(127:96) = Ignored  
               -- data(095:64) = H2  
               -- data(063:32) = H1
               -- data(031:00) = H0                 
               ------------------------------------------------------                                      
               -- Empty field
               v.txMaster.tData(127 downto 96) := (others => '0');
               --H2
               v.txMaster.tData(95 downto 66)  := r.newAddr;
               v.txMaster.tData(65 downto 64)  := "00";                  --PCIe reserved
               --H1
               v.txMaster.tData(63 downto 48)  := dmaTranFromPci.locId;  -- Requester ID
               v.txMaster.tData(47 downto 40)  := dmaTranFromPci.tag;    -- Tag

               -- Last DW byte enable must be zero if the transaction is a single DWORD transfer
               if r.tranLength = 1 then
                  v.txMaster.tData(39 downto 36) := "0000";  -- Last DW Byte Enable
               else
                  v.txMaster.tData(39 downto 36) := "1111";  -- Last DW Byte Enable
               end if;

               v.txMaster.tData(35 downto 32) := "1111";              -- First DW Byte Enable
               --H0
               v.txMaster.tData(31)           := '0';   --PCIe reserved
               v.txMaster.tData(30 downto 29) := "00";  -- FMT = Memory read, 3-DW header w/out payload
               v.txMaster.tData(28 downto 24) := "00000";             -- Type = Memory read or write
               v.txMaster.tData(23)           := '0';   --PCIe reserved
               v.txMaster.tData(22 downto 20) := "000";               -- TC = 0
               v.txMaster.tData(19 downto 16) := "0000";              --PCIe reserved
               v.txMaster.tData(15)           := '0';   -- TD = 0
               v.txMaster.tData(14)           := '0';   -- EP = 0
               v.txMaster.tData(13 downto 12) := "00";  -- Attr = 0
               v.txMaster.tData(11 downto 10) := "00";  --PCIe reserved
               v.txMaster.tData(9 downto 0)   := '0' & r.tranLength;  -- Transaction length
               -- Write the header to FIFO
               v.txMaster.tValid              := '1';
               -- Set the EOF bit
               v.txMaster.tLast               := '1';
               -- Set AXIS tKeep
               v.txMaster.tKeep               := x"0FFF";
               -- Calculate next transmit address
               v.newAddr                      := r.newAddr + r.tranLength;
               -- Calculate remaining request length
               v.reqLength                    := r.reqLength - r.tranLength;
               -- Next state
               v.state                        := CALC_PIPELINE_DLY_S;
            end if;
         ----------------------------------------------------------------------
         when CALC_PIPELINE_DLY_S =>
            v.cnt := r.cnt + 1;
            if r.cnt = x"F" then
               v.cnt   := x"0";
               -- Next state
               v.state := CHECK_LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when CHECK_LENGTH_S =>
            -- Check if we are done requesting memory
            if (r.reqLength /= 0) and (pause = '0') then
               -- Next state
               v.state := CHECK_THRESH_S;
            end if;
         ----------------------------------------------------------------------
         when TR_DONE_S =>
            -- Let the descriptor know that we are done
            v.dmaDescToPci.doneReq := '1';
            -- Wait for descriptor to ACK
            if dmaDescFromPci.doneAck = '1' then
               -- Reset flag
               v.dmaDescToPci.doneReq := '0';
               -- Next state
               v.state                := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Wait for the completion state machine to complete
      if done = '1' then
         -- Let the descriptor know that we are done
         v.dmaDescToPci.doneReq := '1';
         -- Next state
         v.state                := TR_DONE_S;
      end if;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      start        <= r.start;
      newDmaCh     <= r.newDmaCh;
      newSubCh     <= r.newSubCh;
      newLength    <= r.newLength;
      dmaDescToPci <= r.dmaDescToPci;
      dmaIbMaster  <= r.txMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
