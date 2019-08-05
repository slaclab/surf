-------------------------------------------------------------------------------
-- File       : EthMacTxExportGmii.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1GbE Export MAC core with GMII interface
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
use work.EthMacPkg.all;

entity EthMacTxExportGmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      ethClkEn       : in  sl;
      ethClk         : in  sl;
      ethRst         : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- GMII PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Status
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacTxExportGmii;

architecture rtl of EthMacTxExportGmii is

   constant AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => EMAC_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => 1,               -- 8-bit AXI stream interface
      TDEST_BITS_C  => EMAC_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => EMAC_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => EMAC_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => EMAC_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => EMAC_AXIS_CONFIG_C.TUSER_MODE_C);

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
      txData         : slv(7 downto 0);
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
      txData         => (others => '0'),
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

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "TRUE";
   -- attribute dont_touch of macMaster    : signal is "TRUE";
   -- attribute dont_touch of macSlave     : signal is "TRUE";
   -- attribute dont_touch of crcOut       : signal is "TRUE";
   -- attribute dont_touch of crcDataValid : signal is "TRUE";
   -- attribute dont_touch of crcIn        : signal is "TRUE";

begin

   U_Resize : entity work.AxiStreamResize
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,  -- 128-bit AXI stream interface  
         MASTER_AXI_CONFIG_G => AXI_CONFIG_C)  -- 8-bit AXI stream interface  
      port map (
         -- Clock and reset
         axisClk     => ethClk,
         axisRst     => ethRst,
         -- Slave Port
         sAxisMaster => macObMaster,    -- 128-bit AXI stream interface 
         sAxisSlave  => macObSlave,
         -- Master Port
         mAxisMaster => macMaster,      -- 8-bit AXI stream interface 
         mAxisSlave  => macSlave);

   comb : process (crcOut, ethClkEn, ethRst, macMaster, phyReady, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.macSlave       := AXI_STREAM_SLAVE_INIT_C;
      v.crcDataValid   := '0';
      v.txCountEn      := '0';
      v.txUnderRun     := '0';
      v.txLinkNotReady := '0';

      -- Check for clock enable
      if (ethClkEn = '1') then

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------      
            when IDLE_S =>
               -- Reset the flags
               v.crcReset := '1';
               v.txCount  := x"00";
               v.txData   := x"55";     -- Preset to PREAMBLE CHAR
               v.gmiiTxd  := x"00";
               v.gmiiTxEn := '0';
               v.gmiiTxEr := '0';
               -- Wait for start flag
               if ((macMaster.tValid = '1') and (ethRst = '0')) then
                  -- Phy is ready
                  if phyReady = '1' then
                     v.state := TX_PREAMBLE_S;
                  -- Phy is not ready dump data
                  else
                     v.txLinkNotReady := '1';
                     v.state          := DUMP_S;
                  end if;
               end if;
            ----------------------------------------------------------------------      
            when TX_PREAMBLE_S =>
               v.crcReset := '0';
               v.gmiiTxEn := '1';
               v.gmiiTxd  := r.txData;
               if (r.txCount = x"06") then
                  v.txCount := x"00";
                  v.txData  := x"D5";   -- Set to SFD char
                  v.state   := TX_DATA_S;
               else
                  v.txCount := r.txCount +1;
                  v.txData  := x"55";   -- Set to PREAMBLE char
               end if;
            ----------------------------------------------------------------------      
            when TX_DATA_S =>
               v.macSlave.tReady := '1';
               v.crcDataValid    := '1';
               v.crcIn           := macMaster.tdata(7 downto 0);
               v.txData          := macMaster.tdata(7 downto 0);
               v.gmiiTxd         := r.txData;
               if (r.txCount < x"3C") then  -- Minimum frame of 60B (= 84B - 8B Preamble - 4B CRC - 12B intergap)
                  v.txCount := r.txCount + 1;
               end if;
               if (macMaster.tValid = '1') then
                  if (macMaster.tlast = '1') then
                     if (v.txCount = x"3C") then
                        v.state := TX_CRC_S;
                     else
                        v.state := PAD_S;
                     end if;
                  end if;
               else
                  v.gmiiTxEr   := '1';
                  v.txUnderRun := '1';
                  v.state      := DUMP_S;
               end if;
            ----------------------------------------------------------------------      
            when PAD_S =>
               v.crcDataValid := '1';
               v.crcIn        := x"00";
               v.txData       := x"00";
               v.gmiiTxd      := r.txData;
               if (r.txCount < x"3C") then
                  v.txCount := v.txCount + 1;
               else
                  v.state := TX_CRC_S;
               end if;
            ----------------------------------------------------------------------      
            when TX_CRC_S =>
               v.gmiiTxd := r.txData;
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
               v.txCountEn := '1';
               v.gmiitxd   := crcOut(7 downto 0);
               v.txCount   := x"00";
               v.state     := INTERGAP_S;
            ----------------------------------------------------------------------      
            when DUMP_S =>
               v.gmiiTxEn        := '0';
               v.gmiiTxd         := x"00";
               v.macSlave.tReady := '1';
               v.txCount         := x"00";
               if ((macMaster.tValid = '1') and (macMaster.tlast = '1')) then
                  v.state := INTERGAP_S;
               end if;
            ----------------------------------------------------------------------      
            when INTERGAP_S =>
               v.gmiiTxEn := '0';
               v.gmiiTxd  := x"00";
               v.txCount  := r.txCount +1;
               if r.txCount = x"0A" then  -- 12 Octels (11 in INTERGAP_S + 1 in IDLE_S)
                  v.txCount := x"00";
                  v.state   := IDLE_S;
               end if;
         ----------------------------------------------------------------------      
         end case;

      end if;

      -- Combinatorial outputs before the reset
      macSlave     <= v.macSlave;
      crcDataValid <= v.crcDataValid;
      crcIn        <= v.crcIn;

      -- Reset
      if (ethRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs 
      txCountEn      <= r.txCountEn;
      txUnderRun     <= r.txUnderRun;
      txLinkNotReady <= r.txLinkNotReady;
      gmiiTxEn       <= r.gmiiTxEn;
      gmiiTxEr       <= r.gmiiTxEr;
      gmiiTxd        <= r.gmiiTxd;

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
