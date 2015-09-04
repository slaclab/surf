-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV1Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-11
-- Last update: 2015-06-12
-- Platform   : 
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
use work.EvrV1Pkg.all;

entity EvrV1Core is
   generic (
      TPD_G           : time    := 1 ns;
      SYNC_POLARITY_G : sl      := '1';     -- '1' = active HIGH logic
      USE_WSTRB_G     : boolean := false;
      ENDIAN_G        : boolean := false);  -- true = big endian, false = little endian
   port (
      -- AXI-Lite and IRQ Interface
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      irqActive      : in  sl;
      irqEnable      : out sl;
      irqReq         : out sl;
      -- Trigger and Sync Port
      sync           : in  sl;
      trigOut        : out slv(11 downto 0);
      -- EVR Interface
      evrClk         : in  sl;
      evrRst         : in  sl;
      rxLinkUp       : in  sl;
      rxError        : in  sl;
      rxData         : in  slv(15 downto 0);
      rxDataK        : in  slv(1 downto 0));
end EvrV1Core;

architecture mapping of EvrV1Core is

   signal status : EvrV1StatusType;
   signal config : EvrV1ConfigType;

begin

   GEN_LITTLE_ENDIAN : if (ENDIAN_G = false) generate
      EvrV1Reg_Inst : entity work.EvrV1Reg
         generic map (
            TPD_G            => TPD_G,
            USE_WSTRB_G      => USE_WSTRB_G,
            AXI_ERROR_RESP_G => AXI_RESP_OK_C)
         port map (
            -- PCIe Interface
            irqActive      => irqActive,
            irqEnable      => irqEnable,
            irqReq         => irqReq,
            -- AXI-Lite Interface
            axiReadMaster  => axiReadMaster,
            axiReadSlave   => axiReadSlave,
            axiWriteMaster => axiWriteMaster,
            axiWriteSlave  => axiWriteSlave,
            -- EVR Interface      
            status         => status,
            config         => config,
            -- Clock and Reset
            axiClk         => axiClk,
            axiRst         => axiRst);         
   end generate;

   GEN_BIG_ENDIAN : if (ENDIAN_G = true) generate
      EvrV1Reg_Inst : entity work.EvrV1Reg
         generic map (
            TPD_G            => TPD_G,
            USE_WSTRB_G      => USE_WSTRB_G,
            AXI_ERROR_RESP_G => AXI_RESP_OK_C)
         port map (
            -- PCIe Interface
            irqActive                          => irqActive,
            irqEnable                          => irqEnable,
            irqReq                             => irqReq,
            -- AXI-Lite Interface
            axiReadMaster                      => axiReadMaster,
            axiReadSlave.arready               => axiReadSlave.arready,
            axiReadSlave.rdata(31 downto 24)   => axiReadSlave.rdata(7 downto 0),
            axiReadSlave.rdata(23 downto 16)   => axiReadSlave.rdata(15 downto 8),
            axiReadSlave.rdata(15 downto 8)    => axiReadSlave.rdata(23 downto 16),
            axiReadSlave.rdata(7 downto 0)     => axiReadSlave.rdata(31 downto 24),
            axiReadSlave.rresp                 => axiReadSlave.rresp,
            axiReadSlave.rvalid                => axiReadSlave.rvalid,
            axiWriteMaster.awaddr              => axiWriteMaster.awaddr,
            axiWriteMaster.awprot              => axiWriteMaster.awprot,
            axiWriteMaster.awvalid             => axiWriteMaster.awvalid,
            axiWriteMaster.wdata(31 downto 24) => axiWriteMaster.wdata(7 downto 0),
            axiWriteMaster.wdata(23 downto 16) => axiWriteMaster.wdata(15 downto 8),
            axiWriteMaster.wdata(15 downto 8)  => axiWriteMaster.wdata(23 downto 16),
            axiWriteMaster.wdata(7 downto 0)   => axiWriteMaster.wdata(31 downto 24),
            axiWriteMaster.wstrb(3)            => axiWriteMaster.wstrb(0),
            axiWriteMaster.wstrb(2)            => axiWriteMaster.wstrb(1),
            axiWriteMaster.wstrb(1)            => axiWriteMaster.wstrb(2),
            axiWriteMaster.wstrb(0)            => axiWriteMaster.wstrb(3),
            axiWriteMaster.wvalid              => axiWriteMaster.wvalid,
            axiWriteMaster.bready              => axiWriteMaster.bready,
            axiWriteSlave                      => axiWriteSlave,
            -- EVR Interface      
            status                             => status,
            config                             => config,
            -- Clock and Reset
            axiClk                             => axiClk,
            axiRst                             => axiRst);         
   end generate;

   EvrV1EventReceiver_Inst : entity work.EvrV1EventReceiver
      generic map (
         TPD_G           => TPD_G,
         SYNC_POLARITY_G => SYNC_POLARITY_G)
      port map (
         -- Register Interface
         axiClk   => axiClk,
         axiRst   => axiRst,
         status   => status,
         config   => config,
         -- Trigger and Sync Port
         sync     => sync,
         trigOut  => trigOut,
         -- EVR Interface
         evrClk   => evrClk,
         evrRst   => evrRst,
         rxLinkUp => rxLinkUp,
         rxError  => rxError,
         rxData   => rxData,
         rxDataK  => rxDataK);        

end mapping;
