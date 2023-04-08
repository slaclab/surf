-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to extract and re-insert a destination from an interleaved stream.
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

library surf;
use surf.StdRtlPkg.all;
use surf.ArbiterPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamTap is
   generic (
      TPD_G                : time                   := 1 ns;
      RST_ASYNC_G          : boolean                := false;
      TAP_DEST_G           : natural range 0 to 255 := 0;
      PIPE_STAGES_G        : natural range 0 to 16  := 0;
      ILEAVE_ON_NOTVALID_G : boolean                := false;
      ILEAVE_REARB_G       : natural                := 0);
   port (
      -- Slave Interface
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Master Interface
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- Tap Interface
      tmAxisMaster : out AxiStreamMasterType;
      tmAxisSlave  : in  AxiStreamSlaveType;
      tsAxisMaster : in  AxiStreamMasterType;
      tsAxisSlave  : out AxiStreamSlaveType;
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl);
end AxiStreamTap;

architecture structure of AxiStreamTap is

   constant ROUTES_C : Slv8Array := (0 => toSlv(TAP_DEST_G, 8),
                                     1 => "--------");

   signal iAxisMaster : AxiStreamMasterType;
   signal iAxisSlave  : AxiStreamSlaveType;

begin

   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PIPE_STAGES_G  => PIPE_STAGES_G,
         NUM_MASTERS_G  => 2,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => ROUTES_C)
      port map (
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         mAxisMasters(0) => tmAxisMaster,
         mAxisMasters(1) => iAxisMaster,
         mAxisSlaves(0)  => tmAxisSlave,
         mAxisSlaves(1)  => iAxisSlave,
         axisClk         => axisClk,
         axisRst         => axisRst);

   U_Mux : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         RST_ASYNC_G          => RST_ASYNC_G,
         PIPE_STAGES_G        => PIPE_STAGES_G,
         NUM_SLAVES_G         => 2,
         MODE_G               => "PASSTHROUGH",
         TDEST_ROUTES_G       => ROUTES_C,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => ILEAVE_REARB_G)
      port map (
         axisClk         => axisClk,
         axisRst         => axisRst,
         sAxisMasters(0) => tsAxisMaster,
         sAxisMasters(1) => iAxisMaster,
         sAxisSlaves(0)  => tsAxisSlave,
         sAxisSlaves(1)  => iAxisSlave,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave);

end structure;

