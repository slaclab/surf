library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

package Pgp2AppTypesPkg is
  --Recond Types
  type PgpTxVcInType is record
    vcFrameTxValid : sl;                -- User frame data is valid
    vcFrameTxSOF   : sl;                -- User frame data start of frame
    vcFrameTxEOF   : sl;                -- User frame data end of frame
    vcFrameTxEOFE  : sl;                -- User frame data error
    vcFrameTxData  : slv(15 downto 0);  -- User frame data
    vcLocBuffAFull : sl;                -- Remote buffer almost full
    vcLocBuffFull  : sl;                -- Remote buffer full
  end record;

  type PgpTxVcQuadInType is array (3 downto 0) of PgpTxVcInType;

  type PgpTxVcOutType is record
    vcFrameTxReady : sl;                -- PGP is ready
  end record;

  type PgpTxVcQuadOutType is array (3 downto 0) of PgpTxVcOutType;

  type PgpRxVcOutType is record
    vcFrameRxValid : sl;                -- PGP frame data is valid
    vcRemBuffAFull : sl;                -- Remote buffer almost full
    vcRemBuffFull  : sl;                -- Remote buffer full
  end record;

  type PgpRxVcQuadOutType is array (3 downto 0) of PgpRxVcOutType;

  type PgpRxVcCommonOutType is record
    vcFrameRxSOF  : sl;                 -- PGP frame data start of frame
    vcFrameRxEOF  : sl;                 -- PGP frame data end of frame
    vcFrameRxEOFE : sl;                 -- PGP frame data error
    vcFrameRxData : slv(15 downto 0);   -- PGP frame data  
  end record;

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

  type CmdSlaveOutType is record
    cmdEn     : sl;                     -- Command Enable
    cmdOpCode : slv(7 downto 0);        -- Command OpCode
    cmdCtxOut : slv(23 downto 0);       -- Command Context
  end record;

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

  type UsBuff32InType is record
    frameTxEnable : sl;
    frameTxSOF    : sl;
    frameTxEOF    : sl;
    frameTxEOFE   : sl;
    frameTxData   : slv(31 downto 0);
  end record;

  type UsBuff32InArray is array (natural range <>) of UsBuff32InType;

  type UsBuff64InType is record
    frameTxEnable : sl;
    frameTxSOF    : sl;
    frameTxEOF    : sl;
    frameTxEOFE   : sl;
    frameTxData   : slv(63 downto 0);
  end record;

  type UsBuff64InArray is array (natural range <>) of UsBuff64InType;

  --Initializing Constants
  constant PgpTxVcInInit : PgpTxVcInType := (
    '0',                                --vcFrameTxValid
    '0',                                --vcFrameTxSOF
    '0',                                --vcFrameTxEOF
    '0',                                --vcFrameTxEOFE
    (others => '0'),                    --vcFrameTxData
    '0',                                --vcLocBuffAFull
    '0');                               --vcLocBuffFull   

  constant PgpTxVcQuadInInit : PgpTxVcQuadInType := (others => PgpTxVcInInit);

  constant PgpTxVcOutInit : PgpTxVcOutType := (
    (others => '0'));                   --vcFrameTxReady

  constant PgpTxVcQuadOutInit : PgpTxVcQuadOutType := (others => PgpTxVcOutInit);
  
  constant PgpRxVcOutInit : PgpRxVcOutType := (
    '0',                                --vcFrameRxValid
    '0',                                --vcRemBuffAFull
    '0');                               --vcRemBuffFull  

  constant PgpRxVcQuadOutInit : PgpRxVcQuadOutType := (others => PgpRxVcOutInit);
  
  constant PgpRxVcCommonOutInit : PgpRxVcCommonOutType := (
    '0',                                --vcFrameRxSOF
    '0',                                --vcFrameRxEOF
    '0',                                --vcFrameRxEOFE
    (others => '0'));                   --vcFrameRxData 

  constant RegSlaveInInit : RegSlaveInType := (
    '0',                                --regAck
    '0',                                --regFail
    (others => '0'));                   --regDataIn 

  constant RegSlaveOutInit : RegSlaveOutType := (
    '0',                                --regInp
    '0',                                --regReq
    '0',                                --regOp
    (others => '0'),                    --regAddr
    (others => '0'));                   --regDataOut  

  constant CmdSlaveOutInit : CmdSlaveOutType := (
    '0',                                --cmdEn
    (others => '0'),                    --cmdOpCode
    (others => '0'));                   --cmdCtxOut  

  constant UsBuffOutInit : UsBuffOutType := (
    (others => '0'));                   --frameTxAfull  

  constant UsBuffInInit : UsBuffInType := (
    '0',                                --frameTxEnable
    '0',                                --frameTxSOF
    '0',                                --frameTxEOF
    '0',                                --frameTxEOFE
    (others => '0'));                   --frameTxData 

  constant UsBuff32InInit : UsBuff32InType := (
    '0',                                --frameTxEnable
    '0',                                --frameTxSOF
    '0',                                --frameTxEOF
    '0',                                --frameTxEOFE
    (others => '0'));                   --frameTxData 

  constant UsBuff64InInit : UsBuff64InType := (
    '0',                                --frameTxEnable
    '0',                                --frameTxSOF
    '0',                                --frameTxEOF
    '0',                                --frameTxEOFE
    (others => '0'));                   --frameTxData 

----------------------------------------------------------------------------------------------------
end package;
