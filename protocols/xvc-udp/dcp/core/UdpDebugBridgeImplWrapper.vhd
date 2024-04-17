-------------------------------------------------------------------------------
-- Title      : XVC Debug Bridge Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UDP Debug Bridge
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.UdpDebugBridgePkg.all;

entity UdpDebugBridge is
   generic (
      AXIS_CLK_FREQ_G : real := 156.25e6);
   port (
      axisClk          : in sl;
      axisRst          : in sl;

      mAxisReq         : in  AxiStreamMasterType;
      sAxisReq         : out AxiStreamSlaveType;

      mAxisTdo         : out AxiStreamMasterType;
      sAxisTdo         : in  AxiStreamSlaveType
   );
end entity UdpDebugBridge;

architecture UdpDebugBridgeImpl of UdpDebugBridge is

   constant XVC_TCLK_DIV2_C   : positive := positive( ieee.math_real.round( AXIS_CLK_FREQ_G/XVC_TCLK_FREQ_C/2.0 ) );

begin

   U_AxisJtagDebugBridge : entity surf.AxisJtagDebugBridge(AxisJtagDebugBridgeImpl)
      generic map (
         AXIS_FREQ_G         => AXIS_CLK_FREQ_G,
         CLK_DIV2_G          => XVC_TCLK_DIV2_C,
         AXIS_WIDTH_G        => XVC_AXIS_WIDTH_C,
         MEM_DEPTH_G         => XVC_MEM_DEPTH_C,
         MEM_STYLE_G         => XVC_MEM_STYLE_C
      )
      port map (
         axisClk             => axisClk,
         axisRst             => axisRst,

         mAxisReq            => mAxisReq,
         sAxisReq            => sAxisReq,

         mAxisTdo            => mAxisTdo,
         sAxisTdo            => sAxisTdo
      );

end architecture UdpDebugBridgeImpl;
