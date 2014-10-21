-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMicronP30Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-23
-- Last update: 2014-10-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to FLASH Memory
--
--    Note: Set the addrBits on the crossbar for this module to 12 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiMicronP30Pkg.all;

entity AxiMicronP30Core is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_CLK_FREQ_G   : real            := 200.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
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
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiMicronP30Core;

architecture mapping of AxiMicronP30Core is

begin

   AxiMicronP30Reg_Inst : entity work.AxiMicronP30Reg
      generic map (
         TPD_G            => TPD_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G) 
      port map (
         -- FLASH Interface 
         flashAddr      => flashOut.addr,
         flashData      => flashInOut.data,
         flashCe        => flashOut.ce,
         flashOe        => flashOut.oe,
         flashWe        => flashOut.we,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst); 

   flashOut.adv <= '0';
   flashOut.clk <= '1';
   flashOut.rst <= not(axiRst);
   
end mapping;
