-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      EthMacImportGmii.vhd - 
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 2/23/2016 9:04:26 AM
--      Last change: JO 5/2/2016 11:39:55 AM
--
-------------------------------------------------------------------------------
-- Title         : 1G MAC / Import Interface
-- Project       : RCE 1G-bit MAC
-------------------------------------------------------------------------------
-- File       : EthMacImportGmii.vhd
-- Author     : Jeff Olsen  <jjo@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-04
-- Last update: 2016-05-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PIC Import block for 1G MAC core for the RCE.
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

entity EthMacImportGmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      ethClk      : in  sl;
      ethClkRst   : in  sl;
      -- AXIS Interface   
      macIbMaster : out AxiStreamMasterType;
      -- PHY Interface
      gmiiRxDv    : in  sl;
      gmiiRxEr    : in  sl;
      gmiiRxd     : in  slv(7 downto 0);
      phyReady    : in  sl;
      -- Status
      rxCountEn   : out sl;
      rxCrcError  : out sl);
end EthMacImportGmii;

architecture rtl of EthMacImportGmii is

   constant SFD_C        : slv(7 downto 0)     := x"D5";
   constant AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1);

   type StateType is(
      WAIT_SFD_S,
      WAIT_DATA_S,
      GET_DATA_S,
      DELAY0_S,
      DELAY1_S,
      CRC_S);

   type RegType is record
      rxCountEn    : sl;
      rxCrcError   : sl;
      crcReset     : sl;
      delRxDv      : sl;
      delRxDvSr    : slv(7 downto 0);
      crcDataValid : sl;
      sof          : sl;
      state        : StateType;
      macData      : slv(63 downto 0);
      macMaster    : AxiStreamMasterType;
   end record;

   constant REG_INIT_C : RegType := (
      rxCountEn    => '0',
      rxCrcError   => '0',
      crcReset     => '0',
      delRxDv      => '0',
      delRxDvSr    => (others => '0'),
      crcDataValid => '0',
      sof          => '0',
      state        => WAIT_SFD_S,
      macData      => (others => '0'),
      macMaster    => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal crcOut    : slv(31 downto 0);
   signal crcIn     : slv(31 downto 0);
   signal macMaster : AxiStreamMasterType;

   attribute dont_touch              : string;
   attribute dont_touch of r         : signal is "TRUE";
   attribute dont_touch of crcIn     : signal is "TRUE";
   attribute dont_touch of crcOut    : signal is "TRUE";
   attribute dont_touch of macMaster : signal is "TRUE";

begin

   TX_DATA_MUX : entity work.AxiStreamFifo
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
         SLAVE_AXI_CONFIG_G  => AXI_CONFIG_C,        --  8-bit AXI stream interface  
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)  -- 64-bit AXI stream interface          
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethClkRst,
         sAxisMaster => macMaster,                   -- 8-bit AXI stream interface  
         sAxisSlave  => open,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethClkRst,
         mAxisMaster => macIbMaster,                 -- 64-bit AXI stream interface
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);  

   comb : process (crcIn, crcOut, ethClkRst, gmiiRxDv, gmiiRxEr, gmiiRxd, phyReady, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxCountEn        := '0';
      v.rxCrcError       := '0';
      v.crcDataValid     := '0';
      v.delRxDv          := '0';
      v.macMaster.tValid := '0';
      v.macMaster.tLast  := '0';
      v.macMaster.tUser  := (others => '0');
      v.macMaster.tKeep  := (others => '1');

      -- Delay data to avoid sending the CRC
      v.macData(63 downto 0) := r.macData(55 downto 0) & gmiiRxd;

      -- Delay the GMII valid for start up sequencing
      v.delRxDvSr := r.delRxDvSr(6 downto 0) & r.delRxDv;

      -- Check for CRC reset
      v.crcReset := r.delRxDvSr(2) or ethClkRst or (not phyReady);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when WAIT_SFD_S =>
            v.sof := '1';
            if ((gmiiRxd = SFD_C) and (gmiiRxDv = '1') and (gmiiRxEr = '0') and (phyReady = '1')) then
               v.delRxDv := '1';
               v.state   := WAIT_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_DATA_S =>
            if (gmiiRxDv = '0') or (gmiiRxEr = '1') or (phyReady = '0') then
               v.state := WAIT_SFD_S;
            elsif (r.delRxDvSr(3) = '1') then
               v.state := GET_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when GET_DATA_S =>
            if ((gmiiRxEr = '1') or (phyReady = '0')) then  -- Error
               v.macMaster.tvalid := '1';
               v.macMaster.tlast  := '1';
               axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, '1');
               v.state            := WAIT_SFD_S;
            else
               v.crcDataValid                := '1';
               v.macMaster.tvalid            := gmiiRxDv;
               v.macMaster.tdata(7 downto 0) := r.macData(39 downto 32);
               if (gmiiRxDv = '0') then
                  v.state := DELAY0_S;
               end if;
               if (r.sof = '1') then
                  axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, '1');
                  v.sof := '0';
               end if;
            end if;
         ----------------------------------------------------------------------
         when DELAY0_S =>
            v.state := DELAY1_S;
         ----------------------------------------------------------------------
         when DELAY1_S =>
            v.state := CRC_S;
         ----------------------------------------------------------------------
         when CRC_S =>
            v.macMaster.tvalid := '1';
            v.macMaster.tlast  := '1';
            if (crcIn /= crcOut) then
               v.rxCrcError := '1';
               axiStreamSetUserBit(AXI_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C, '1');
            else
               v.rxCountEn := '1';
            end if;
            v.state := WAIT_SFD_S;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (ethClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      macMaster  <= r.macMaster;
      rxCountEn  <= r.rxCountEn;
      rxCrcError <= r.rxCrcError;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- CRC Input
   crcIn(31 downto 0) <= r.macData(55 downto 24);

   -- CRC
   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 1)
      port map (
         crcOut       => crcOut,
         crcClk       => ethClk,
         crcDataValid => r.crcDataValid,
         crcDataWidth => "000",
         crcIn        => r.macData(47 downto 40),
         crcReset     => r.crcReset); 

end rtl;
