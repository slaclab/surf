-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- File       : AxisDebugBridge.vhd
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
      MEM_DEPTH_G      : natural  range 0 to 65535  := 4;     -- size of buffer memory (0 for none)
      MEM_STYLE_G      : string                     := "auto" -- 'auto', 'block' or 'distributed'
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
