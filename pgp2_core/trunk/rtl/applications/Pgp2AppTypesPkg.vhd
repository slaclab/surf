library ieee;
use ieee.std_logic_1164.all;

package Pgp2AppPackage is

  --------------------------------------------------------------------------------------------------
  -- These might be useful
  --------------------------------------------------------------------------------------------------
  -- Register Interface
  type RegSlaveInType is record
    regAck    : sl;                     -- Register Access Acknowledge
    regFail   : sl;                     -- Register Access Fail
    regDataIn : slv(31 downto 0);       -- Register Data In
  end record;

  type RegSlaveOutType is record
    regInp     : sl;                    -- Register Access In Progress Flag
    regReq     : sl;                    -- Register Access Request  
    regOp      : sl;                    -- Register OpCode, 0=Read, 1=Write
    regAddr    : slv(23 downto 0);      -- Register Address
    regDataOut : slv(31 downto 0);      -- Register Data Out
  end record;

  -- Command Interface
  type CmdSlaveOutType is record
    cmdEn     : sl;                     -- Command Enable
    cmdOpCode : slv(7 downto 0);        -- Command OpCode
    cmdCtxOut : slv(23 downto 0);       -- Command Context
  end record;

  -- Upstream Data Buffer Interface
  type UsBuffOutType is record
    frameTxAfull : sl;
  end record;

  type UsBuffOutArray is array (natural range <>) of UsBuffOutType;

  type UsBuffInType is record
    frameTxEnable : sl;
    frameTxSOF    : sl;
    frameTxEOF    : sl;
    frameTxEOFE   : sl;
    frameTxData   : slv(15 downto 0);
  end record;

  type UsBuffInArray is array (natural range <>) of UsBuffInType;

  type UsBuff64InType is record
    frameTxEnable : sl;
    frameTxSOF    : sl;
    frameTxEOF    : sl;
    frameTxEOFE   : sl;
    frameTxData   : slv(63 downto 0);
  end record;

  type UsBuff64InArray is array (natural range <>) of UsBuffInType;
  ----------------------------------------------------------------------------------------------------

end package;
