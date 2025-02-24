-------------------------------------------------------------------------------
-- Title      : SACI Protocol: https://confluence.slac.stanford.edu/x/YYcRDQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Port types for Generic Front End interface
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

package FrontEndSaciPkg is

  -- Register Interface
  type FrontEndSaciRegCntlInType is record
    regAck    : sl;
    regFail   : sl;
    regDataIn : slv(31 downto 0);
  end record;

  type FrontEndSaciRegCntlOutType is record
    regInp     : sl;                    -- Operation in progress
    regReq     : sl;                    -- Request reg transaction
    regOp      : sl;                    -- Read (0) or write (1)
    regAddr    : slv(23 downto 0);      -- Address
    regDataOut : slv(31 downto 0);      -- Write Data
  end record;

  -- Command Interface
  type FrontEndSaciCmdCntlOutType is record
    cmdEn     : sl;                     -- Command available
    cmdOpCode : slv(7 downto 0);        -- Command Op Code
    cmdCtxOut : slv(23 downto 0);       -- Command Context
  end record;

  -- Upstream Data Buffer Interface
  type FrontEndSaciUsDataOutType is record
    frameTxAfull : sl;
  end record;

  type FrontEndSaciUsDataInType is record
    frameTxEnable : sl;
    frameTxSOF    : sl;
    frameTxEOF    : sl;
    frameTxEOFE   : sl;
    frameTxData   : slv(63 downto 0);
  end record;

end package FrontEndSaciPkg;
