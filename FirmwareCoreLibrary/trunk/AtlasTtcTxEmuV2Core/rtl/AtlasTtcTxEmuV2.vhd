-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuV2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-05
-- Last update: 2015-02-27
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AtlasTtcTxEmuV2Pkg.all;

entity AtlasTtcTxEmuV2 is
   generic (
      TPD_G              : time                  := 1 ns;
      CLK_SELECT_G       : boolean               := false;
      CASCADE_SIZE_G     : positive              := 1;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32);      
   port (
      -- AXI-Lite Register and Status Bus Interface (axiClk domain)
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      statusWords    : out Slv64Array(0 to 0);
      statusSend     : out sl;
      -- Emulation Trigger Signals
      emuClk         : in  sl;
      emuRst         : in  sl;
      emuClkOut      : out sl;
      emuBusy        : in  sl;
      emuData        : out sl);
end AtlasTtcTxEmuV2;

architecture mapping of AtlasTtcTxEmuV2 is

   signal reset,
      chA,
      chB,
      sync : sl;
   
   signal status : AtlasTtcTxEmuV2StatusType;
   signal config : AtlasTtcTxEmuV2ConfigType;
   
begin

   ----------------------
   -- Synchronizer Inputs
   ----------------------   
   SyncIn_Busy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => emuClk,
         dataIn  => emuBusy,
         dataOut => status.busy);

   SyncIn_reset : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => emuClk,
         asyncRst => config.reset,
         syncRst  => reset);          

   -------------------
   -- Time Multiplexer
   -------------------
   AtlasTtcTxEmuV2TimeMux_Inst : entity work.AtlasTtcTxEmuV2TimeMux
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => emuClk,
         rst     => reset,
         chA     => chA,
         chB     => chB,
         sync    => sync,
         emuData => emuData);

   ------------------------
   -- EngineA = L1-Triggers
   ------------------------
   AtlasTtcTxEmuV2EngineA_Inst : entity work.AtlasTtcTxEmuV2EngineA
      generic map (
         TPD_G          => TPD_G,
         CASCADE_SIZE_G => CASCADE_SIZE_G)
      port map (
         -- Channel A Interface
         busy   => status.busy,
         sync   => sync,
         chA    => chA,
         -- Control interface
         config => config.engineA,
         status => status.engineA,
         -- Clock and Reset
         clk    => emuClk,
         rst    => reset);

   -------------------------------         
   -- EngineB = Broadcast Messages
   -------------------------------         
   AtlasTtcTxEmuV2EngineB_Inst : entity work.AtlasTtcTxEmuV2EngineB
      generic map (
         TPD_G          => TPD_G,
         CASCADE_SIZE_G => CASCADE_SIZE_G)
      port map (
         -- Channel B Interface
         sync   => sync,
         chB    => chB,
         -- Control interface
         config => config.engineB,
         status => status.engineB,
         -- Clock and Reset
         clk    => emuClk,
         rst    => reset);         

   ------------------
   -- Register Module
   ------------------
   AtlasTtcTxEmuV2Reg_Inst : entity work.AtlasTtcTxEmuV2Reg
      generic map (
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map (
         -- AXI-Lite Register and Status Bus Interface (sAxiClk domain)
         sAxiClk         => axiClk,
         sAxiRst         => axiRst,
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         statusWords     => statusWords,
         statusSend      => statusSend,
         -- Local Interface (clk domain)
         clk             => emuClk,
         rst             => emuRst,
         status          => status,
         config          => config);   

end mapping;
