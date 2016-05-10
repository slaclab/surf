-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--	EthMacImportGmii.vhd - 
--
--	Copyright(c) SLAC National Accelerator Laboratory 2000
--
--	Author: Jeff Olsen
--	Created on: 2/23/2016 9:04:26 AM
--	Last change: JO 5/2/2016 11:39:55 AM
--
-------------------------------------------------------------------------------
-- Title         : 1G MAC / Import Interface
-- Project       : RCE 1G-bit MAC
-------------------------------------------------------------------------------
-- File       : EthMacImportGmii.vhd
-- Author     : Jeff Olsen  <jjo@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-04
-- Last update: 2016-02-24
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

Constant SFD_C 		: slv(7 downto 0) := x"D5";

	type StateType is
	(
		waitSFD_s,
		waitData_s,
		getData_s,
		delA_s,
		delB_s,
		Crc_s,
		Term_s
	);


signal crcOut : slv(31 downto 0);
signal crcIn    : slv(31 downto 0);

   type RegType is record
      rxCountEn   	: sl;
      rxCrcError  	: sl;
		crcValid			: sl;
		crcReset			: sl;
		delRxDv			: sl;
		delRxDvSr		: slv(7 downto 0);
		writeFF			: sl;
		crcGood			: sl;
		crcDataValid	: sl;
		state				: StateType;
		macData			: slv(63 downto 0);
      macMaster  : AxiStreamMasterType;
   end record;

   constant REG_INIT_C : RegType := (
      rxCountEn   	=> '0',
      rxCrcError  	=> '0',
		crcValid			=> '0',
		crcReset			=> '0',
		delRxDv			=> '0',
		delRxDvSr		=> (Others => '0'),
		writeFF			=> '0',
		crcGood			=> '0',
		crcDataValid	=> '0',
		state				=> waitSFD_s,
		macData			=> (others => '0'),
      macMaster  		=> AXI_STREAM_MASTER_INIT_C
      );


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal FFData : slv(7 downto 0);
   signal macMaster : AxiStreamMasterType;
   signal macSlave  : AxiStreamSlaveType;


   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";   

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
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(1),  --  8-bit AXI stream interface  
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(8))  -- 64-bit AXI stream interface          
      port map (
         -- Slave Port
         sAxisClk    => ethClk,
         sAxisRst    => ethClkRst,
         sAxisMaster => macMaster,                      -- 8-bit AXI stream interface  
         sAxisSlave  => macSlave,
         -- Master Port
         mAxisClk    => ethClk,
         mAxisRst    => ethClkRst,
         mAxisMaster => macIbMaster,                    -- 64-bit AXI stream interface
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);  


   comb : process (ethClkRst, macSlave, r, gmiiRxDv, gmiiRxEr, gmiiRxd, phyReady, FFData, crcOut, crcIn ) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      if macSlave.tReady = '1' then
         v.macMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

--		if r.intFirstLine = '1' then
--			axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.macMaster, EMAC_SOF_BIT_C, '1', 0);
--		end if;

		if r.MacMaster.tlast = '1' then
--			axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C,  not(r.crcGood));
			axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.macMaster, EMAC_EOFE_BIT_C,  '1');
		end if;

	
		v.rxCountEn  := r.MacMaster.tlast and r.crcGood;

-- Delay data to avoid sending the crc
		v.macData(63 downto 0) := r.macData(55 downto 0) & gmiiRxd;

--

		v.delRxDvSr := r.delRxDvSr(6 downto 0) & r.delRxDv ;

		v.crcReset            := r.delRxDvSr(2) or ethClkRst or (not phyReady);
		
		case r.state is
			when waitSFD_s =>
				v.macMaster.tlast 	:= '0';
--				v.intFirstLine	:= '0';
				v.macMaster.tvalid	:= '0';
				v.crcDataValid			:= '0';
				if ((gmiiRxd = SFD_C) and (gmiiRxDv = '1') and (gmiiRxEr = '0') and (phyReady = '1')) then
					v.delRxDv			:= '1';
					v.state	:= waitData_s;
				else
					v.delRxDv			:= '0';
					v.state := waitSFD_s;
				end if;
				
			when waitData_s =>
				v.delRxDv			:= '0';
				if (r.delRxDvSr(3) = '1') then
					v.state := getData_s;
				else
					v.state := waitData_s;
				end if;

			when getData_s =>
				if ((gmiiRxEr = '1') or (phyReady = '0')) then  -- Error
					v.macMaster.tvalid 	:= '1';
					v.macMaster.tlast		:= '1';
					v.crcDataValid			:= '0';
					v.state 					:= Term_s;
				else
					v.macMaster.tdata(7 downto 0)		:= FFData;	 
					if (gmiiRxDv = '0') then
						v.macMaster.tvalid	:= '1';				-- Transmit 64bit Data
						v.macMaster.tlast		:= '1';
						v.crcDataValid			:= '1';
						v.state 				:= delA_s;
					else
						v.macMaster.tvalid	:= '1';
						v.crcDataValid			:= '1';
					end if;
				end if;

            when delA_s =>
  				v.crcDataValid			:= '0';
 				v.state 				:= delB_s;               

            when delB_s =>

 				v.state 				:= crc_s;               

			when crc_s =>
			 if (crcIn /= crcOut) then
			     rxCrcError <= '1';
			 end if;
				v.macMaster.tvalid 	:= '0';
				v.macMaster.tlast  	:= '0';
				v.crcDataValid			:= '0';		
				v.state					:= term_s;
						
			when term_s =>
				v.macMaster.tvalid 	:= '0';
				v.macMaster.tlast  	:= '0';
				v.crcDataValid			:= '0';		
				v.state					:= waitSFD_s;
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
    crcIn(31 downto 24) <= r.macData(31 downto 24);
    crcIn(23 downto 16) <= r.macData(39 downto 32);
    crcIn(15 downto  8) <= r.macData(47 downto 40);
    crcIn(7  downto  0) <= r.macData(55 downto 48);

		FFData									<= r.macData(47 downto 40);	
-- CRC
U_Crc32 : entity work.Crc32Parallel
generic map (
	BYTE_WIDTH_G => 1
)
port map (
	crcOut		  => crcOut,
	crcClk		  => ethClk,
	crcDataValid  => r.crcDataValid,
	crcDataWidth  => "000",
	crcIn			  => FFData,
	crcReset		  => r.crcReset
); 


end rtl;
