-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- File       : AxisToJtagWrapper.vhd
-- Author     : Till Straumann <strauman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-12-05
-- Last update: 2017-12-05
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- Axi Stream to JTAG Protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

-- Connect AxisToJtag to a debug bridge IP (convenience wrapper)
entity AxisDebugBridge is
   generic (
      TPD_G            : time                       := 1 ns;
      AXIS_FREQ_G      : real                       := 0.0;   -- Hz (for computing TCK period)
      AXIS_WIDTH_G     : positive range 4 to 16     := 4;     -- bytes
      CLK_DIV2_G       : positive                   := 4;     -- half-period of TCK in axisClk cycles
      MEM_DEPTH_G      : natural  range 0 to 65535  := 4      -- size of buffer memory (0 for none)
   );
   port (
      axisClk          : in sl;
      axisRst          : in sl;

      mAxisReq         : in  AxiStreamMasterType;
      sAxisReq         : out AxiStreamSlaveType;

      mAxisTdo         : out AxiStreamMasterType;
      sAxisTdo         : in  AxiStreamSlaveType
   );
end entity AxisDebugBridge;

architecture AxisDebugBridgeImpl of AxisDebugBridge is

   -- IP
   -- Must be generated and named DebugBridgeJtag, e.g., with TCL commands:
   --
   --    create_ip -name debug_bridge -vendor xilinx.com -library ip -module_name DebugBridgeJtag
   --    # C_DEBUG_MODE selects JTAG <-> BSCAN mode
   --    set_property -dict [list CONFIG.C_DEBUG_MODE {4}] [get_ips DebugBridgeJtag]
   --

   component DebugBridgeJtag is
     port (
       jtag_tdi : in  std_logic;
       jtag_tdo : out std_logic;
       jtag_tms : in  std_logic;
       jtag_tck : in  std_logic
     );
   end component DebugBridgeJtag;

   signal tck, tdi, tms, tdo : sl;

begin
   
   U_AXIS_JTAG : entity work.AxisToJtag
      generic map (
         TPD_G        => TPD_G,
         AXIS_WIDTH_G => AXIS_WIDTH_G,
         AXIS_FREQ_G  => AXIS_FREQ_G,
         CLK_DIV2_G   => CLK_DIV2_G,
         MEM_DEPTH_G  => MEM_DEPTH_G
      )
      port map (
         axisClk      => axisClk,
         axisRst      => axisRst,

         mAxisReq     => mAxisReq,
         sAxisReq     => sAxisReq,

         mAxisTdo     => mAxisTdo,
         sAxisTdo     => sAxisTdo,

         tck          => tck,
         tms          => tms,
         tdi          => tdi,
         tdo          => tdo
      );

   U_JTAG_BSCAN : DebugBridgeJtag
      port map (
         jtag_tdi     => tdi,
         jtag_tdo     => tdo,
         jtag_tms     => tms,
         jtag_tck     => tck
      );

end architecture AxisDebugBridgeImpl;
