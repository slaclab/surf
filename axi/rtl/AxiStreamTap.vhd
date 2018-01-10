-------------------------------------------------------------------------------
-- File       : AxiStreamTap.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description:
-- Block to extract and re-isnert a destination from an interleaved stream.
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
use ieee.NUMERIC_STD.all;
use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamTap is
   generic (
      TPD_G         : time                   := 1 ns;
      PIPE_STAGES_G : integer range 0 to 16  := 0;
      TAP_DEST_G    : integer range 0 to 255 := 0);
   port (
      -- Slave
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Masters
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- Tap 
      tmAxisMaster : out AxiStreamMasterType;
      tmAxisSlave  : in  AxiStreamSlaveType;
      tsAxisMaster : in  AxiStreamMasterType;
      tsAxisSlave  : out AxiStreamSlaveType;
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl);
end AxiStreamTap;

architecture structure of AxiStreamTap is

   constant ROUTES_C : Slv8Array := (0 => "--------", 
                                     1 => toSlv(TAP_DEST_G,8));

   signal iAxisMaster  : AxiStreamMasterType;
   signal iAxisSlave   : AxiStreamSlaveType;

begin

   U_DeMux: entity work.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         PIPE_STAGES_G  => PIPE_STAGES_G,
         NUM_MASTERS_G  => 2,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => ROUTES_C)
      port map (
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         mAxisMasters(0) => iAxisMaster,
         mAxisMasters(1) => tmAxisMaster,
         mAxisSlaves(0)  => iAxisSlave,
         mAxisSlaves(1)  => tmAxisSlave,
         axisClk         => axisClk,
         axisRst         => axisRst);

   U_Mux: entity work.AxiStreamMux
      generic map (
         TPD_G          => TPD_G,
         PIPE_STAGES_G  => PIPE_STAGES_G,
         NUM_SLAVES_G   => 2,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => ROUTES_C,
         ILEAVE_EN_G    => true,
         ILEAVE_REARB_G => 0)
      port map (
         axisClk         => axisClk,
         axisRst         => axisRst,
         sAxisMasters(0) => iAxisMaster,
         sAxisMasters(1) => tsAxisMaster,
         sAxisSlaves(0)  => iAxisSlave,
         sAxisSlaves(1)  => tsAxisSlave,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave);

end structure;

