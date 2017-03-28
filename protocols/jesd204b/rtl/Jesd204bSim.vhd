-------------------------------------------------------------------------------
-- File       : Jesd204bSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-------------------------------------------------------------------------------
-- Description: JESD204b module for simulation
--              Module supports a subset of features from JESD204b standard.
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
--use work.AxiLitePkg.all;
use work.Jesd204bPkg.all;
--use work.Version.all;

entity Jesd204bSim is
   generic (
      TPD_G            : time                := 1 ns;
      
   -- AXI Lite and stream generics
   --   MEM_ADDR_MASK_G  : slv(31 downto 0)    := x"00000000";
   --   AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
   --   AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
   --   AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);
      
   -- JESD generics
   
      -- Number of bytes in a frame
      F_G : positive := 2;
      
      -- Number of frames in a multi frame
      K_G : positive := 32;
      
      --Number of lanes (1 to 8)
      L_G : positive := 2;
           
      --JESD204B class (0 and 1 supported)
      SUB_CLASS_G : positive := 1
   );  
   
   port (
   -- AXI interface      
      -- Clocks and Resets
    --  axiClk         : in    sl;
    --  axiRst         : in    sl;
      -- AXI-Lite Register Interface
    --  axiReadMaster  : in    AxiLiteReadMasterType;
    --  axiReadSlave   : out   AxiLiteReadSlaveType;
    --  axiWriteMaster : in    AxiLiteWriteMasterType;
    --  axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- AXI Streaming Interface
    --  mAxisMaster    : out   AxiStreamMasterType;
    --  mAxisSlave     : in    AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
    --  sAxisMaster    : in    AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   --   sAxisSlave     : out   AxiStreamSlaveType;
      
   -- JESD
      -- Clocks and Resets   
      devClk_i       : in    sl;    
      devRst_i       : in    sl;
      
      -- SYSREF for subcalss 1 fixed latency
      sysRef_i       : in    sl;

      -- Data and character inputs from GT (transceivers)
      r_jesdGtRxArr  : in   jesdGtRxLaneTypeArray(0 to L_G-1);
      gt_reset_o     : out  slv(L_G-1 downto 0); 

      -- Synchronisation output combined from all receivers 
      nSync_o        : out   sl;

      -- Simulation signals TODO remove or rename file as sim
      sysrefDlyRx_i  : in   slv(4 downto 0); 
      enableRx_i     : in   slv(L_G-1 downto 0);
      statusRxArr_o  : out  Slv8Array(0 to L_G-1);
      dataValid_o    : out  sl;
      sampleData_o   : out  Slv32Array(0 to L_G-1)
   );
end Jesd204bSim;

architecture rtl of Jesd204bSim is

-- Register
   type RegType is record
      nSyncAllD1 : sl;
      nSyncAnyD1 : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      nSyncAllD1  => '0',
      nSyncAnyD1  => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


-- Internal signals

-- Local Multi Frame Clock 
signal s_lmfc   : sl;

-- Synchronisation output generation
signal s_nSyncVec       : slv(L_G-1 downto 0);
signal s_dataValidVec   : slv(L_G-1 downto 0);

signal s_nSyncAll   : sl;
signal s_nSyncAny   : sl;

-- Sysref input delayed
signal  s_sysref  : sl;

begin

   -- Delay SYSREF input (for 1 to 32 c-c)
   SysrefDly_INST: entity work.SysrefDly
   generic map (
      TPD_G       => TPD_G,
      DLY_WIDTH_G => sysrefDlyRx_i'high + 1 
   )
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      dly_i    => sysrefDlyRx_i,
      sysref_i => sysref_i,
      sysref_o => s_sysref
   );

   -- LMFC period generator aligned to SYSREF input
   LmfcGen_INST: entity work.LmfcGen
   generic map (
      TPD_G          => TPD_G,
      K_G            => K_G,
      F_G            => F_G)
   port map (
      clk      => devClk_i,
      rst      => devRst_i,
      nSync_i  => r.nSyncAllD1,
      sysref_i => s_sysref,
      lmfc_o   => s_lmfc 
   );
    
   -- JESD Receiver modules (one module per Lane)
   
   generateRxLanes : for I in 0 to L_G-1 generate    
      JesdRx_INST: entity work.JesdRx
      generic map (
         TPD_G          => TPD_G,
         F_G            => F_G,
         K_G            => K_G,
         SUB_CLASS_G    => SUB_CLASS_G)
      port map (
         devClk_i     => devClk_i,
         devRst_i     => devRst_i,
         sysRef_i     => s_sysref,
         enable_i     => enableRx_i(I),
         status_o     => statusRxArr_o(I),
         r_jesdGtRx   => r_jesdGtRxArr(I),
         lmfc_i       => s_lmfc,
         nSyncAll_i   => r.nSyncAllD1,
         nSyncAny_i   => r.nSyncAnyD1,
         nSync_o      => s_nSyncVec(I),
         dataValid_o  => s_dataValidVec(I),
         sampleData_o => sampleData_o(I)
      );
   end generate;
   
   -- Combine nSync signals from all receivers
   s_nSyncAll <= uOr(s_nSyncVec);
   s_nSyncAny <= uAnd(s_nSyncVec);
   
   -- DFF
   comb : process (r, devRst_i, s_nSyncAll, s_nSyncAny) is
      variable v : RegType;
   begin
      v.nSyncAllD1 := s_nSyncAll;
      v.nSyncAnyD1 := s_nSyncAny;
      
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (devClk_i) is
   begin
      if (rising_edge(devClk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Output assignment
   nSync_o     <= r.nSyncAllD1;
   dataValid_o <= uAnd(s_dataValidVec); --just for sim
   gt_reset_o  <= not enableRx_i;
   -----------------------------------------------------
end rtl;
