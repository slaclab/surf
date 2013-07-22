library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

package Pgp2AppTypesPkg is
   ------------------------------------------------------------------------
   -- PgpTxVcIn Types/Constants                             
   ------------------------------------------------------------------------
   type PgpTxVcInType is record
      frameTxValid : sl;                  -- User frame data is valid
      frameTxSOF   : sl;                  -- User frame data start of frame
      frameTxEOF   : sl;                  -- User frame data end of frame
      frameTxEOFE  : sl;                  -- User frame data error
      frameTxData  : slv16Array(0 to 3);  -- User frame data (up to 4 lanes)
      locBuffAFull : sl;                  -- Remote buffer almost full
      locBuffFull  : sl;                  -- Remote buffer full
   end record;
   type PgpTxVcInArray is array (natural range <>) of PgpTxVcInType;
   constant PGP_TX_VC_IN_INIT_C : PgpTxVcInType := (
      '0',
      '0',
      '0',
      '0',
      (others => (others => '0')),
      '0',
      '0');   

   ------------------------------------------------------------------------
   -- PgpTxVcQuadIn Types/Constants                             
   ------------------------------------------------------------------------
   type PgpTxVcQuadInType is array (0 to 3) of PgpTxVcInType;  -- 4 Virtual Channel inputs
   type PgpTxVcQuadInArray is array (natural range <>) of PgpTxVcQuadInType;
   constant PGP_TX_VC_QUAD_IN_INIT_C : PgpTxVcQuadInType := (
      (others => PGP_TX_VC_IN_INIT_C)); 

   ------------------------------------------------------------------------
   -- PgpTxVcOut Types/Constants                             
   ------------------------------------------------------------------------
   type PgpTxVcOutType is record
      frameTxReady : sl;                -- PGP is ready
   end record;
   type PgpTxVcOutArray is array (natural range <>) of PgpTxVcOutType;
   constant PGP_TX_VC_OUT_INIT_C : PgpTxVcOutType := (
      (others => '0'));                 --frameTxReady   

   ------------------------------------------------------------------------
   -- PgpTxVcQuadOut Types/Constants                             
   ------------------------------------------------------------------------
   type PgpTxVcQuadOutType is array (0 to 3) of PgpTxVcOutType;  -- 4 Virtual Channel inputs
   type PgpTxVcQuadOutArray is array (natural range <>) of PgpTxVcQuadOutType;
   constant PGP_TX_VC_QUAD_OUT_INIT_C : PgpTxVcQuadOutType := (
      (others => PGP_TX_VC_OUT_INIT_C));

   ------------------------------------------------------------------------
   -- PgpRxVcCommonOut Types/Constants                             
   ------------------------------------------------------------------------
   type PgpRxVcCommonOutType is record
      frameRxSOF  : sl;                  -- PGP frame data start of frame
      frameRxEOF  : sl;                  -- PGP frame data end of frame
      frameRxEOFE : sl;                  -- PGP frame data error
      frameRxData : slv16Array(0 to 3);  -- PGP frame data
   end record;
   type PgpRxVcCommonOutArray is array (natural range <>) of PgpRxVcCommonOutType;
   constant PGP_RX_VC_COMMON_OUT_INIT_C : PgpRxVcCommonOutType := (
      '0',
      '0',
      '0',
      (others => (others => '0')));    

   ------------------------------------------------------------------------
   -- PgpRxVcOut Types/Constants                             
   ------------------------------------------------------------------------
   type PgpRxVcOutType is record
      frameRxValid : sl;                -- PGP frame data is valid
      remBuffAFull : sl;                -- Remote buffer almost full
      remBuffFull  : sl;                -- Remote buffer full
   end record;
   type PgpRxVcOutArray is array (natural range <>) of PgpRxVcOutType;
   constant PGP_RX_VC_OUT_INIT_C : PgpRxVcOutType := (
      '0',
      '0',
      '0');       

   ------------------------------------------------------------------------
   -- PgpRxVcQuadOut Types/Constants                             
   ------------------------------------------------------------------------
   type PgpRxVcQuadOutType is array (0 to 3) of PgpRxVcOutType;  -- 4 Rx Virtual Channel outputs
   type PgpRxVcQuadOutArray is array (natural range <>) of PgpRxVcQuadOutType;
   constant PGP_RX_VC_QUAD_OUT_INIT_C : PgpRxVcQuadOutType := (
      (others => PGP_RX_VC_OUT_INIT_C));  

   ------------------------------------------------------------------------
   -- Command Types/Constants                             
   ------------------------------------------------------------------------
   type CmdSlaveOutType is record
      cmdEn     : sl;                   -- Command Enable
      cmdOpCode : slv(7 downto 0);      -- Command OpCode
      cmdCtxOut : slv(23 downto 0);     -- Command Context
   end record;
   constant CmdSlaveOutInit : CmdSlaveOutType := (
      '0',                              --cmdEn
      (others => '0'),                  --cmdOpCode
      (others => '0'));                 --cmdCtxOut 

   ------------------------------------------------------------------------
   -- Slave Register Types/Constants                       
   ------------------------------------------------------------------------
   type RegSlaveInType is record
      regAck    : sl;                   -- Register Access Acknowledge
      regFail   : sl;                   -- Register Access Fail
      regDataIn : slv(31 downto 0);     -- Register Data In
   end record;
   constant RegSlaveInInit : RegSlaveInType := (
      '0',                              --regAck
      '0',                              --regFail
      (others => '0'));                 --regDataIn 

   type RegSlaveOutType is record
      regInp     : sl;                  -- Register Access In Progress Flag
      regReq     : sl;                  -- Register Access Request  
      regOp      : sl;                  -- Register OpCode, 0=Read, 1=Write
      regAddr    : slv(23 downto 0);    -- Register Address
      regDataOut : slv(31 downto 0);    -- Register Data Out
   end record;
   constant RegSlaveOutInit : RegSlaveOutType := (
      '0',                              --regInp
      '0',                              --regReq
      '0',                              --regOp
      (others => '0'),                  --regAddr
      (others => '0'));                 --regDataOut    

   ------------------------------------------------------------------------
   -- Up Stream Buffer Types/Constants                            
   ------------------------------------------------------------------------
   type UsBuff16InType is record
      frameTxEnable : sl;
      frameTxSOF    : sl;
      frameTxEOF    : sl;
      frameTxEOFE   : sl;
      frameTxData   : slv(15 downto 0);
   end record;
   constant UsBuff16InInit : UsBuff16InType := (
      '0',                              --frameTxEnable
      '0',                              --frameTxSOF
      '0',                              --frameTxEOF
      '0',                              --frameTxEOFE
      (others => '0'));                 --frameTxData    

   type UsBuff16InArrayType is array (natural range <>) of UsBuff16InType;

   type UsBuff16OutType is record
      frameTxAfull : sl;
   end record;
   constant UsBuff16OutInit : UsBuff16OutType := (
      (others => '0'));                 --frameTxAfull  

   type UsBuff16OutArrayType is array (natural range <>) of UsBuff16OutType;

   type UsBuff32InType is record
      frameTxEnable : sl;
      frameTxSOF    : sl;
      frameTxEOF    : sl;
      frameTxEOFE   : sl;
      frameTxData   : slv(31 downto 0);
   end record;
   constant UsBuff32InInit : UsBuff32InType := (
      '0',                              --frameTxEnable
      '0',                              --frameTxSOF
      '0',                              --frameTxEOF
      '0',                              --frameTxEOFE
      (others => '0'));                 --frameTxData    

   type UsBuff32InArrayType is array (natural range <>) of UsBuff32InType;

   type UsBuff32OutType is record
      frameTxAfull : sl;
   end record;
   constant UsBuff32OutInit : UsBuff32OutType := (
      (others => '0'));                 --frameTxAfull  

   type UsBuff32OutArrayType is array (natural range <>) of UsBuff32OutType;

   type UsBuff64InType is record
      frameTxEnable : sl;
      frameTxSOF    : sl;
      frameTxEOF    : sl;
      frameTxEOFE   : sl;
      frameTxData   : slv(63 downto 0);
   end record;
   constant UsBuff64InInit : UsBuff64InType := (
      '0',                              --frameTxEnable
      '0',                              --frameTxSOF
      '0',                              --frameTxEOF
      '0',                              --frameTxEOFE
      (others => '0'));                 --frameTxData 

   type UsBuff64InArrayType is array (natural range <>) of UsBuff64InType;

   type UsBuff64OutType is record
      frameTxAfull : sl;
   end record;
   constant UsBuff64OutInit : UsBuff64OutType := (
      (others => '0'));                 --frameTxAfull  

   type UsBuff64OutArrayType is array (natural range <>) of UsBuff64OutType;

   type UsBuff128InType is record
      frameTxEnable : sl;
      frameTxSOF    : sl;
      frameTxEOF    : sl;
      frameTxEOFE   : sl;
      frameTxData   : slv(127 downto 0);
   end record;
   constant UsBuff128InInit : UsBuff128InType := (
      '0',                              --frameTxEnable
      '0',                              --frameTxSOF
      '0',                              --frameTxEOF
      '0',                              --frameTxEOFE
      (others => '0'));                 --frameTxData 

   type UsBuff128InArrayType is array (natural range <>) of UsBuff128InType;

   type UsBuff128OutType is record
      frameTxAfull : sl;
   end record;
   constant UsBuff128OutInit : UsBuff128OutType := (
      (others => '0'));                 --frameTxAfull  

   type UsBuff128OutArrayType is array (natural range <>) of UsBuff128OutType;

   ------------------------------------------------------------------------
   -- Down Stream Buffer Types/Constants                         
   ------------------------------------------------------------------------
   type DsBuff16InType is record
      frameRxReady : sl;
   end record;
   constant DsBuff16InInit : DsBuff16InType := (
      (others => '0'));                 --frameRxReady  

   type DsBuff16InArrayType is array (natural range <>) of DsBuff16InType;

   type DsBuff16OutType is record
      frameRxValid : sl;
      frameRxSOF   : sl;
      frameRxEOF   : sl;
      frameRxEOFE  : sl;
      frameRxData  : slv(15 downto 0);
   end record;
   constant DsBuff16OutInit : DsBuff16OutType := (
      '0',                              --frameRxValid
      '0',                              --frameRxSOF
      '0',                              --frameRxEOF
      '0',                              --frameRxEOFE
      (others => '0'));                 --frameRxData    

   type DsBuff16OutArrayType is array (natural range <>) of DsBuff16OutType;

   type DsBuff32InType is record
      frameRxReady : sl;
   end record;
   constant DsBuff32InInit : DsBuff32InType := (
      (others => '0'));                 --frameRxReady  

   type DsBuff32ArrayType is array (natural range <>) of DsBuff32InType;

   type DsBuff32OutType is record
      frameRxValid : sl;
      frameRxSOF   : sl;
      frameRxEOF   : sl;
      frameRxEOFE  : sl;
      frameRxData  : slv(31 downto 0);
   end record;
   constant DsBuff32OutInit : DsBuff32OutType := (
      '0',                              --frameRxValid
      '0',                              --frameRxSOF
      '0',                              --frameRxEOF
      '0',                              --frameRxEOFE
      (others => '0'));                 --frameRxData    

   type DsBuff32OutArrayType is array (natural range <>) of DsBuff32OutType;

   type DsBuff64InType is record
      frameRxReady : sl;
   end record;
   constant DsBuff64InInit : DsBuff64InType := (
      (others => '0'));                 --frameRxReady  

   type DsBuff64ArrayType is array (natural range <>) of DsBuff64InType;

   type DsBuff64OutType is record
      frameRxValid : sl;
      frameRxSOF   : sl;
      frameRxEOF   : sl;
      frameRxEOFE  : sl;
      frameRxData  : slv(63 downto 0);
   end record;
   constant DsBuff64OutInit : DsBuff64OutType := (
      '0',                              --frameRxValid
      '0',                              --frameRxSOF
      '0',                              --frameRxEOF
      '0',                              --frameRxEOFE
      (others => '0'));                 --frameRxData    

   type DsBuff64OutArrayType is array (natural range <>) of DsBuff64OutType;

   type DsBuff128InType is record
      frameRxReady : sl;
   end record;
   constant DsBuff128InInit : DsBuff128InType := (
      (others => '0'));                 --frameRxReady  

   type DsBuff128ArrayType is array (natural range <>) of DsBuff128InType;

   type DsBuff128OutType is record
      frameRxValid : sl;
      frameRxSOF   : sl;
      frameRxEOF   : sl;
      frameRxEOFE  : sl;
      frameRxData  : slv(127 downto 0);
   end record;
   constant DsBuff128OutInit : DsBuff128OutType := (
      '0',                              --frameRxValid
      '0',                              --frameRxSOF
      '0',                              --frameRxEOF
      '0',                              --frameRxEOFE
      (others => '0'));                 --frameRxData    

   type DsBuff128OutArrayType is array (natural range <>) of DsBuff128OutType;

----------------------------------------------------------------------------------------------------
end package;
