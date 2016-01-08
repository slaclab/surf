-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieRxDmaTransFifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe RX DMA Engine's Transaction FIFO
-- Note: Only support 32-bit words (up to 4 words per AXIS transaction)
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

entity SsiPcieRxDmaTransFifo is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Transaction Control Interface
      tranRd      : in  sl;
      tranValid   : out sl;
      tranSubId   : out slv(3 downto 0);
      tranEofe    : out sl;
      tranLength  : out slv(8 downto 0);
      tranCnt     : out slv(8 downto 0);
      -- Streaming Interfaces
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk      : in  sl;
      pciRst      : in  sl);
end SsiPcieRxDmaTransFifo;

architecture rtl of SsiPcieRxDmaTransFifo is

   type StateType is (
      IDLE_S,
      SEND_S);  

   type RegType is record
      tranWr     : sl;
      tranSubId  : slv(3 downto 0);
      tranCnt    : slv(8 downto 0);
      tranLength : slv(8 downto 0);
      tranEofe   : sl;
      wordCnt    : slv(8 downto 0);
      cnt        : slv(8 downto 0);
      sAxisSlave : AxiStreamSlaveType;
      axisMaster : AxiStreamMasterType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      tranWr     => '0',
      tranSubId  => (others => '0'),
      tranCnt    => (others => '0'),
      tranLength => (others => '0'),
      tranEofe   => '0',
      wordCnt    => (others => '0'),
      cnt        => (others => '0'),
      sAxisSlave => AXI_STREAM_SLAVE_INIT_C,
      axisMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tranAFull  : sl;
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (axisSlave, pciRst, r, sAxisMaster, tranAFull) is
      variable v         : RegType;
      variable i         : natural;
      variable increment : slv(8 downto 0);
      variable maxCntDet : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset signals
      v.tranWr            := '0';
      v.sAxisSlave.tReady := '0';
      increment           := (others => '0');
      maxCntDet           := '0';

      -- Update tValid register
      if axisSlave.tReady = '1' then
         v.axisMaster.tValid   := '0';
         v.axisMaster.tUser(0) := '0';
      end if;

      -- Check if ready to move data
      if (sAxisMaster.tValid = '1') and (v.axisMaster.tValid = '0') and (tranAFull = '0') and (r.tranWr = '0') then
         -- Ready for data
         v.sAxisSlave.tReady := '1';
         -- Latch the FIFO data
         v.axisMaster        := sAxisMaster;
         -- Check tKeep
         for i in 0 to 3 loop
            if sAxisMaster.tKeep((i*4)+3 downto (i*4)) = x"F" then
               increment := increment+1;
            end if;
         end loop;
         -- Increment the counters
         v.wordCnt := r.wordCnt + increment;
         v.cnt     := r.cnt + 1;
         -- Check for max. size
         for i in 0 to 3 loop
            if v.wordCnt = (PCIE_MAX_RX_TRANS_LENGTH_C-i) then
               maxCntDet := '1';
            end if;
         end loop;
         -- Check for max. counter detected or tLast
         if (maxCntDet = '1') or (sAxisMaster.tLast = '1') then
            -- Write to the transaction FIFO
            v.tranWr              := '1';
            -- Latch the transaction data
            v.tranSubId           := sAxisMaster.tDest(3 downto 0);
            v.tranEofe            := ssiGetUserEofe(PCIE_AXIS_CONFIG_C, sAxisMaster);
            v.tranLength          := v.wordCnt;
            v.tranCnt             := v.cnt;
            -- Set the end of TLP flag
            v.axisMaster.tUser(0) := '1';
            -- Reset the counter
            v.wordCnt             := (others => '0');
            v.cnt                 := (others => '0');
         end if;
      end if;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave <= v.sAxisSlave;
      axisMaster <= reverseOrderPcie(r.axisMaster);
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_DATA : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,      -- Use 36Kb with 72 inputs
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PCIE_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PCIE_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);   

   FIFO_TRANS : entity work.FifoSync
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 23,
         FULL_THRES_G => 60,
         ADDR_WIDTH_G => 6)             -- Use RAM64 
      port map (
         clk                => pciClk,
         rst                => pciRst,
         --Write Ports (wr_clk domain)
         wr_en              => r.tranWr,
         din(22 downto 19)  => r.tranSubId,
         din(18)            => r.tranEofe,
         din(17 downto 9)   => r.tranLength,
         din(8 downto 0)    => r.tranCnt,
         prog_full          => tranAFull,
         --Read Ports (rd_clk domain)
         rd_en              => tranRd,
         dout(22 downto 19) => tranSubId,
         dout(18)           => tranEofe,
         dout(17 downto 9)  => tranLength,
         dout(8 downto 0)   => tranCnt,
         valid              => tranValid);

end rtl;
