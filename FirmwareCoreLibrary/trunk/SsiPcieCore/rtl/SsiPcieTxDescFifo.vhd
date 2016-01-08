-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTxDescFifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Transmit Descriptor FIFO
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

entity SsiPcieTxDescFifo is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input Data
      tFifoWr    : in  sl;
      tFifoDin   : in  slv(63 downto 0);
      tFifoAFull : out sl;
      tFifoCnt   : out slv(4 downto 0);
      -- DMA Controller Interface
      newReq     : in  sl;
      newAck     : out sl;
      newAddr    : out slv(31 downto 2);
      newLength  : out slv(23 downto 0);
      newDmaCh   : out slv(3 downto 0);
      newSubCh   : out slv(3 downto 0);
      -- Global Signals
      pciClk     : in  sl;
      pciRst     : in  sl); 
end SsiPcieTxDescFifo;

architecture rtl of SsiPcieTxDescFifo is

   type StateType is (
      IDLE_S,
      ACK_S);    

   type RegType is record
      newAck    : sl;
      newAddr   : slv(31 downto 2);
      newLength : slv(23 downto 0);
      newDmaCh  : slv(3 downto 0);
      newSubCh  : slv(3 downto 0);
      state     : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      newAck    => '0',
      newAddr   => (others => '0'),
      newLength => (others => '0'),
      newDmaCh  => (others => '0'),
      newSubCh  => (others => '0'),
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tFifoValid : sl;
   signal tFifoDout  : slv(63 downto 0);

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   -- FIFO for Transmit descriptors
   -- Bits[63:32] = Tx Address
   -- Bits[31:24] = Tx Control
   -- Bits[23:00] = Tx Length in words, 1 based
   U_RxFifo : entity work.FifoSync
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         FWFT_EN_G    => true,
         FULL_THRES_G => 500,
         DATA_WIDTH_G => 64,
         ADDR_WIDTH_G => 5)             
      port map (
         rst        => pciRst,
         clk        => pciClk,
         din        => tFifoDin,
         wr_en      => tFifoWr,
         rd_en      => r.newAck,
         dout       => tFifoDout,
         valid      => tFifoValid,
         data_count => tFifoCnt,
         prog_full  => tFifoAFull);

   comb : process (newReq, pciRst, r, tFifoDout, tFifoValid) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.newAck := '0';

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (newReq = '1') and (tFifoValid = '1') then
               v.newAck    := '1';
               v.newAddr   := tFifoDout(63 downto 34);
               v.newDmaCh  := tFifoDout(31 downto 28);
               v.newSubCh  := tFifoDout(27 downto 24);
               v.newLength := tFifoDout(23 downto 0);
               -- Next state
               v.state     := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            if newReq = '0'then
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      newAck    <= r.newAck;
      newAddr   <= r.newAddr;
      newDmaCh  <= r.newDmaCh;
      newSubCh  <= r.newSubCh;
      newLength <= r.newLength;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
