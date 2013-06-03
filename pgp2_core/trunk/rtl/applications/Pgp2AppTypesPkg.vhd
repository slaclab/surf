library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

package Pgp2AppTypesPkg is

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
  
 	--Initializing Constants
  constant RegSlaveInInit	: RegSlaveInType := (
    '0',--regAck
    '0',--regFail
    (others=>'0'));-- regDataIn 
		
  constant RegSlaveOutInit	: RegSlaveOutType := (
    '0',--regInp
    '0',--regReq
    '0',--regOp
    (others=>'0'),--regAddr
    (others=>'0'));-- regDataOut  
	 
  constant CmdSlaveOutInit	: CmdSlaveOutType := (
    '0',--cmdEn
    (others=>'0'),--cmdOpCode
    (others=>'0'));-- cmdCtxOut  
  ----------------------------------------------------------------------------------------------------
end package;
