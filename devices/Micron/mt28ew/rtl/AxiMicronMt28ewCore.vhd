-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to Micron MT28EW FLASH IC
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiMicronMt28ewPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiMicronMt28ewCore is
   generic (
      TPD_G              : time             := 1 ns;
      EN_PASSWORD_LOCK_G : boolean          := false;
      PASSWORD_LOCK_G    : slv(31 downto 0) := x"DEADBEEF";
      MEM_ADDR_MASK_G    : slv(31 downto 0) := x"00000000";
      AXI_CLK_FREQ_G     : real             := 200.0E+6);  -- units of Hz
   port (
      -- FLASH Interface
      flashInOut     : inout AxiMicronMt28ewInOutType;
      flashOut       : out   AxiMicronMt28ewOutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiMicronMt28ewCore;

architecture mapping of AxiMicronMt28ewCore is

   signal flashDin  : slv(15 downto 0);
   signal flashDout : slv(15 downto 0);
   signal flashTri  : sl;

begin

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : entity surf.IoBufWrapper
         port map (
            O  => flashDout(i),         -- Buffer output
            IO => flashInOut.dq(i),  -- Buffer inout port (connect directly to top-level port)
            I  => flashDin(i),          -- Buffer input
            T  => flashTri);  -- 3-state enable input, high=input, low=output
   end generate GEN_IOBUF;

   U_CTRL : entity surf.AxiMicronMt28ewReg
      generic map (
         TPD_G              => TPD_G,
         EN_PASSWORD_LOCK_G => EN_PASSWORD_LOCK_G,
         PASSWORD_LOCK_G    => PASSWORD_LOCK_G,
         MEM_ADDR_MASK_G    => MEM_ADDR_MASK_G,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G)
      port map (
         -- FLASH Interface
         flashAddr      => flashOut.addr,
         flashRstL      => flashOut.rstL,
         flashCeL       => flashOut.ceL,
         flashOeL       => flashOut.oeL,
         flashWeL       => flashOut.weL,
         flashDin       => flashDin,
         flashDout      => flashDout,
         flashTri       => flashTri,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);

end mapping;
