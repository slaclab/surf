-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      EthMacExportGmii.vhd - 
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 4/15/2016 3:02:34 PM
--      Last change: JO 5/2/2016 2:38:24 PM
--
-------------------------------------------------------------------------------
-- Title         : 1G MAC / Export Interface
-- Project       : RCE 1G-bit MAC
-------------------------------------------------------------------------------
-- File       : EthMacExportGmii.vhd
-- Author     : Jeff Olsen  <jjo@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-04
-- Last update: 2016-05-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PIC Export block for 1G MAC core for the RCE.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/04/2016: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity EthMacExportGmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      ethClk         : in  sl;
      ethClkRst      : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Configuration
      interFrameGap  : in  slv(3 downto 0);
      macAddress     : in  slv(47 downto 0);
      -- Status
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacExportGmii;

architecture rtl of EthMacExportGmii is

   constant AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1);

   type StateType is(
      IDLE_S,
      TX_PREAMBLE_S,
      TX_DATA_S,
      PAD_S,
      TX_CRC_S,
      TX_CRC0_S,
      TX_CRC1_S,
      TX_CRC2_S,
      TX_CRC3_S,
      DUMP_S,
      INTERGAP_S);

   type RegType is record
      gmiiTxEn       : sl;
      gmiiTxEr       : sl;
      gmiiTxd        : slv(7 downto 0);
      txCount        : slv(7 downto 0);
      txData_d       : slv(7 downto 0);
      txCountEn      : sl;
      txUnderRun     : sl;
      txLinkNotReady : sl;
      crcReset       : sl;
      crcDataValid   : sl;
      crcIn          : slv(7 downto 0);
      state          : StateType;
      macSlave       : AxiStreamSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      gmiiTxEn       => '0',
      gmiiTxEr       => '0',
      gmiiTxd        => (others => '0'),
      txCount        => (others => '0'),
      txData_d       => (others => '0'),
      txCountEn      => '0',
      txUnderRun     => '0',
      txLinkNotReady => '0',
      crcReset       => '0',
      crcDataValid   => '0',
      crcIn          => (others => '0'),
      state          => IDLE_S,
      macSlave       => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal macMaster    : AxiStreamMasterType;
   signal macSlave     : AxiStreamSlaveType;
   signal crcOut       : slv(31 downto 0);
   signal crcDataValid : sl;
   signal crcIn        : slv(7 downto 0);

   attribute dont_touch                 : string;
   attribute dont_touch of r            : signal is "TRUE";
   attribute dont_touch of macMaster    : signal is "TRUE";
   attribute dont_touch of macSlave     : signal is "TRUE";
   attribute dont_touch of crcOut       : signal is "TRUE";
   attribute dont_touch of crcDataValid : signal is "TRUE";
   attribute dont_touch of crcIn        : signal is "TRUE";

begin

   RX_DATA_MUX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,  -- 64-bit AXI stream interface  
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)        -- 8-bit AXI stream interface          
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethClkRst,
         sAxisMaster => macObMaster,                 -- 64-bit AXI stream interface 
         sAxisSlave  => macObSlave,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethClkRst,
         mAxisMaster => macMaster,                   -- 8-bit AXI stream interface 
         mAxisSlave  => macSlave);  

   comb : process (crcOut, ethClkRst, macMaster, phyReady, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.macSlave     := AXI_STREAM_SLAVE_INIT_C;
      v.crcDataValid := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------      
         when IDLE_S =>
            v.crcReset := '1';
            v.TxCount  := x"00";
            v.txData_d := x"77";
            v.gmiiTxd  := x"77";
            v.gmiiTxEn := '0';
            v.gmiiTxEr := '0';
            -- Wait for start flag
            if ((macMaster.tValid = '1') and (ethClkRst = '0')) then
               -- Phy is ready
               if phyReady = '1' then
                  v.state := TX_PREAMBLE_S;
               -- Phy is not ready dump data
               else
                  v.state          := DUMP_S;
                  v.txLinkNotReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------      
         when TX_PREAMBLE_S =>
            v.gmiiTxEn := '1';
            if (r.TxCount = x"07") then
               v.CrcReset := '0';
               v.txData_d := x"D5";
               v.gmiiTxd  := r.txData_d;
               v.TxCount  := x"00";
               v.state    := TX_DATA_S;
            else
               v.TxCount  := r.TxCount +1;
               v.txData_d := x"55";
               v.gmiiTxd  := r.txData_d;
               v.state    := TX_PREAMBLE_S;
            end if;
         ----------------------------------------------------------------------      
         when TX_DATA_S =>
            v.macSlave.tReady := '1';
            v.crcDataValid    := '1';
            v.crcIn           := macMaster.tdata(7 downto 0);
            v.txData_d        := macMaster.tdata(7 downto 0);
            v.gmiiTxd         := r.txData_d;
            if (r.TxCount < x"3C") then  -- Minimum frame of 64 includes 4byte FCS
               v.TxCount := r.TxCount + 1;
            end if;
            if (macMaster.tValid = '1') then
               if (macMaster.tlast = '1') then
                  if (v.TxCount = x"3C") then
                     v.state := TX_CRC_S;
                  else
                     v.state := PAD_S;
                  end if;
               end if;
            else
               v.gmiiTxEr := '1';
               v.state    := DUMP_S;
            end if;
         ----------------------------------------------------------------------      
         when PAD_S =>
            v.crcDataValid := '1';
            v.crcIn        := x"00";
            v.txData_d     := x"00";
            v.gmiiTxd      := r.txData_d;
            if (r.TxCount < x"3C") then
               v.TxCount := v.TxCount + 1;
            else
               v.state := TX_CRC_S;
            end if;
         ----------------------------------------------------------------------      
         when TX_CRC_S =>
            v.gmiiTxd := r.txData_d;
            v.state   := TX_CRC0_S;
         ----------------------------------------------------------------------      
         when TX_CRC0_S =>
            v.gmiitxd := crcOut(31 downto 24);
            v.state   := TX_CRC1_S;
         ----------------------------------------------------------------------      
         when TX_CRC1_S =>
            v.gmiitxd := crcOut(23 downto 16);
            v.state   := TX_CRC2_S;
         ----------------------------------------------------------------------      
         when TX_CRC2_S =>
            v.gmiitxd := crcOut(15 downto 8);
            v.state   := TX_CRC3_S;
         ----------------------------------------------------------------------      
         when TX_CRC3_S =>
            v.gmiitxd := crcOut(7 downto 0);
            v.TxCount := x"00";
            v.state   := INTERGAP_S;
         ----------------------------------------------------------------------      
         when DUMP_S =>
            v.gmiiTxEn        := '0';
            v.macSlave.tReady := '1';
            v.TxCount         := x"00";
            if ((macMaster.tValid = '1') and (macMaster.tlast = '1')) then
               v.state := INTERGAP_S;
            end if;
         ----------------------------------------------------------------------      
         when INTERGAP_S =>
            v.gmiiTxEn := '0';
            v.TxCount  := r.TxCount +1;
            if r.TxCount = x"5E" then    -- 12 Octels - IDLE state
               v.TxCount := x"00";
               v.state   := IDLE_S;
            end if;
      ----------------------------------------------------------------------      
      end case;

      -- Reset
      if (ethClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      macSlave       <= v.macSlave;     -- Flow control with non-registered signal
      txCountEn      <= r.txCountEn;
      txUnderRun     <= r.txUnderRun;
      txLinkNotReady <= r.txLinkNotReady;
      gmiiTxEn       <= r.gmiiTxEn;
      gmiiTxEr       <= r.gmiiTxEr;
      gmiiTxd        <= r.gmiiTxd;
      crcDataValid   <= v.crcDataValid;
      crcIn          <= v.crcIn;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- CRC
   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 1)
      port map (
         crcOut       => crcOut,
         crcClk       => ethClk,
         crcDataValid => crcDataValid,
         crcDataWidth => "000",
         crcIn        => crcIn,
         crcReset     => r.crcReset); 

end rtl;
