-------------------------------------------------------------------------------
-- Title      : Sig Gen for JESD DAC
-------------------------------------------------------------------------------
-- File       : DacSignalGenerator.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-04-14
-- Last update: 2015-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--              
--              
--              
--              
--              
--              
--              
--              
--              
--              
--              
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity DacSignalGenerator is
   generic (
      TPD_G             : time                        := 1 ns;
      
      -- AXI Lite and stream generics
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
      
      ADDR_WIDTH_G : integer range 1 to (2**24) := 9;
      DATA_WIDTH_G : integer range 1 to 32      := 32;
      
     --Number of data lanes (Only valid at this point is 6)
      L_G : positive := 6
   );
   port (
     
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
     
      -- Clocks and Resets   
      devClk_i       : in    sl;    
      devRst_i       : in    sl;
          
      -- AXI-Lite Register Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      
      -- Sample data input 
      sampleDataArr_o   : out   sampleDataArray(L_G-1 downto 0)
   );
end DacSignalGenerator;

architecture rtl of DacSignalGenerator is
 
 -- Internal signals

   -- Generator signals 
   signal s_laneEn     : slv(L_G-1 downto 0);
   signal s_periodSize : slv(ADDR_WIDTH_G-1 downto 0);
   signal s_dspDiv     : slv(15 downto 0);
   
   -------------------------------------------------------------------------------------------------
   -- AXI Lite Config and Signals
   -------------------------------------------------------------------------------------------------
   
   constant NUM_AXI_MASTERS_C : natural := L_G+1;
   
   constant DAC_AXIL_INDEX_C       : natural   := 0;
   constant LANE_INDEX_C           : natural   := 1;
   
   
   constant DAC_ADDR_C     : slv(31 downto 0)   := X"0040_0000";
   constant LANE0_C        : slv(31 downto 0)   := X"0041_0000";
   constant LANE1_C        : slv(31 downto 0)   := X"0042_0000";
   constant LANE2_C        : slv(31 downto 0)   := X"0043_0000"; 
   constant LANE3_C        : slv(31 downto 0)   := X"0045_0000";
   constant LANE4_C        : slv(31 downto 0)   := X"0046_0000";
   constant LANE5_C        : slv(31 downto 0)   := X"0047_0000";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      DAC_AXIL_INDEX_C => (
         baseAddr          => DAC_ADDR_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      LANE_INDEX_C+0    => (
         baseAddr          => LANE0_C,
         addrBits          => 12,
         connectivity      => X"0001"),
      LANE_INDEX_C+1    => (
         baseAddr          => LANE1_C,
         addrBits          => 12,
         connectivity      => X"0001"));  
      -- LANE_INDEX_C+2    => (
         -- baseAddr          => LANE2_C,
         -- addrBits          => 12,
         -- connectivity      => X"0001"),
      -- LANE_INDEX_C+3 => (
         -- baseAddr          => LANE3_C,
         -- addrBits          => 12,
         -- connectivity      => X"0001"),
      -- LANE_INDEX_C+4    => (
         -- baseAddr          => LANE4_C,
         -- addrBits          => 12,
         -- connectivity      => X"0001"),
      -- LANE_INDEX_C+5    => (
         -- baseAddr          => LANE5_C,
         -- addrBits          => 12,
         -- connectivity      => X"0001"));
         
   signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

begin
   -- Check JESD generics
   assert (1 <= L_G and L_G <= 16)                          report "L_G must be between 1 and 16"   severity failure;
  
   -----------------------------------------------------------
   -- AXI lite
   ----------------------------------------------------------- 

   -- DAC Axi Crossbar
   DACAxiCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,   
         mAxiWriteMasters    => locAxilWriteMasters,
         mAxiWriteSlaves     => locAxilWriteSlaves,
         mAxiReadMasters     => locAxilReadMasters,
         mAxiReadSlaves      => locAxilReadSlaves);

   -- DAQ control register interface
   AxiLiteGenRegItf_INST: entity work.AxiLiteGenRegItf
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      ADDR_WIDTH_G     => ADDR_WIDTH_G,
      L_G              => L_G)
   port map (
      axiClk_i        => axiClk,
      axiRst_i        => axiRst,   
      devClk_i        => devClk_i,
      devRst_i        => devRst_i,
      axilReadMaster  => locAxilReadMasters(DAC_AXIL_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(DAC_AXIL_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(DAC_AXIL_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(DAC_AXIL_INDEX_C),
      enable_o        => s_laneEn,
      periodSize_o    => s_periodSize,
      dspDiv_o        => s_dspDiv);

   -----------------------------------------------------------
   -- Signal generator lanes
   ----------------------------------------------------------- 
   genTxLanes : for I in L_G-1 downto 0 generate
      SigGenLane_INST: entity work.SigGenLane
         generic map (
            TPD_G        => TPD_G,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            DATA_WIDTH_G => DATA_WIDTH_G)
         port map (
            enable_i        => s_laneEn(I),
            devClk_i        => devClk_i,
            devRst_i        => devRst_i,
            axiClk_i        => axiClk,
            axiRst_i        => axiRst,            
            axilReadMaster  => locAxilReadMasters(LANE_INDEX_C+I), 
            axilReadSlave   => locAxilReadSlaves(LANE_INDEX_C+I),  
            axilWriteMaster => locAxilWriteMasters(LANE_INDEX_C+I),
            axilWriteSlave  => locAxilWriteSlaves(LANE_INDEX_C+I), 
            periodSize_i    => s_periodSize,
            dspDiv_i        => s_dspDiv,
            sampleData_o    => sampleDataArr_o(I));
   end generate genTxLanes;
   -----------------------------------------------------
end rtl;
