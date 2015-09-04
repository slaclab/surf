-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmu.vhd
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
use work.AtlasTtcTxEmuPkg.all;

entity AtlasTtcTxEmu is
   generic (
      TPD_G              : time                  := 1 ns;
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
      emuBusy        : in  sl;
      emuData        : out sl);
end AtlasTtcTxEmu;

architecture mapping of AtlasTtcTxEmu is

   signal chA,
      chB,
      sync : sl;
   
   signal status : AtlasTtcTxEmuStatusType;
   signal config : AtlasTtcTxEmuConfigType;
   
begin

   SyncIn_Busy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => emuClk,
         dataIn  => emuBusy,
         dataOut => status.busy);  

   AtlasTtcTxEmuSer_Inst : entity work.AtlasTtcTxEmuSer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => emuClk,
         rst     => emuRst,
         chA     => chA,
         chB     => chB,
         sync    => sync,
         emuData => emuData);

   AtlasTtcTxEmuTrig_Inst : entity work.AtlasTtcTxEmuTrig
      generic map (
         TPD_G => TPD_G)
      port map (
         clk          => emuClk,
         rst          => emuRst,
         sync         => sync,
         busy         => status.busy,
         config       => config,
         trigBurstCnt => status.trigBurstCnt,
         chA          => chA); 

   AtlasTtcTxEmuMessage_Inst : entity work.AtlasTtcTxEmuMessage
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => emuClk,
         rst         => emuRst,
         sync        => sync,
         config      => config,
         bcrBurstCnt => status.bcrBurstCnt,
         ecrBurstCnt => status.ecrBurstCnt,
         chB         => chB);          

   AtlasTtcTxEmuReg_Inst : entity work.AtlasTtcTxEmuReg
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
