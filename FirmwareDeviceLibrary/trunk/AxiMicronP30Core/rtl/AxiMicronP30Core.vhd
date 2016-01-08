-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMicronP30Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-23
-- Last update: 2015-03-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to FLASH Memory
--
--    Note: Set the addrBits on the crossbar for this module to 12 bits wide
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Micron P30 Support Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Micron P30 Support Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiMicronP30Pkg.all;

entity AxiMicronP30Core is
   generic (
      TPD_G            : time                := 1 ns;
      MEM_ADDR_MASK_G  : slv(31 downto 0)    := x"00000000";
      AXI_CLK_FREQ_G   : real                := 200.0E+6;  -- units of Hz
      AXI_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(4);
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C);
   port (
      -- FLASH Interface 
      flashIn        : in    AxiMicronP30InType;
      flashInOut     : inout AxiMicronP30InOutType;
      flashOut       : out   AxiMicronP30OutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- AXI Streaming Interface (Optional)
      mAxisMaster    : out   AxiStreamMasterType;
      mAxisSlave     : in    AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
      sAxisMaster    : in    AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisSlave     : out   AxiStreamSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiMicronP30Core;

architecture mapping of AxiMicronP30Core is

begin

   AxiMicronP30Reg_Inst : entity work.AxiMicronP30Reg
      generic map (
         TPD_G            => TPD_G,
         MEM_ADDR_MASK_G  => MEM_ADDR_MASK_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         AXI_CONFIG_G     => AXI_CONFIG_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G) 
      port map (
         -- FLASH Interface 
         flashAddr      => flashOut.addr,
         flashDq        => flashInOut.dq,
         flashCeL       => flashOut.ceL,
         flashOeL       => flashOut.oeL,
         flashWeL       => flashOut.weL,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- AXI Streaming Interface (Optional)
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => mAxisSlave,
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst); 

   flashOut.adv  <= '0';
   flashOut.clk  <= '1';
   flashOut.rstL <= not(axiRst);
   
end mapping;
