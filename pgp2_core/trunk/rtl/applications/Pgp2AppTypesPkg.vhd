library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.Pgp2CoreTypesPkg.all;

package Pgp2AppTypesPkg is
	------------------------------------------------------------------------
	-- Command Types/Constants										 
	------------------------------------------------------------------------
	type CmdSlaveOutType is record
		cmdEn		 : sl;						 -- Command Enable
		cmdOpCode : slv(7 downto 0);		 -- Command OpCode
		cmdCtxOut : slv(23 downto 0);		 -- Command Context
	end record;
	constant CmdSlaveOutInit : CmdSlaveOutType := (
		'0',										 --cmdEn
		(others => '0'),						 --cmdOpCode
		(others => '0'));						 --cmdCtxOut 

	------------------------------------------------------------------------
	-- Slave Register Types/Constants							  
	------------------------------------------------------------------------
	type RegSlaveInType is record
		regAck	 : sl;						 -- Register Access Acknowledge
		regFail	 : sl;						 -- Register Access Fail
		regDataIn : slv(31 downto 0);		 -- Register Data In
	end record;
	constant RegSlaveInInit : RegSlaveInType := (
		'0',										 --regAck
		'0',										 --regFail
		(others => '0'));						 --regDataIn 

	type RegSlaveOutType is record
		regInp	  : sl;						 -- Register Access In Progress Flag
		regReq	  : sl;						 -- Register Access Request  
		regOp		  : sl;						 -- Register OpCode, 0=Read, 1=Write
		regAddr	  : slv(23 downto 0);	 -- Register Address
		regDataOut : slv(31 downto 0);	 -- Register Data Out
	end record;
	constant RegSlaveOutInit : RegSlaveOutType := (
		'0',										 --regInp
		'0',										 --regReq
		'0',										 --regOp
		(others => '0'),						 --regAddr
		(others => '0'));						 --regDataOut	  

	------------------------------------------------------------------------
	-- Up Stream Buffer Types/Constants										
	------------------------------------------------------------------------
	type UsBuff16InType is record
		frameTxEnable : sl;
		frameTxSOF	  : sl;
		frameTxEOF	  : sl;
		frameTxEOFE	  : sl;
		frameTxData	  : slv(15 downto 0);
	end record;
	constant UsBuff16InInit : UsBuff16InType := (
		'0',										 --frameTxEnable
		'0',										 --frameTxSOF
		'0',										 --frameTxEOF
		'0',										 --frameTxEOFE
		(others => '0'));						 --frameTxData		

	type UsBuff16InArrayType is array (natural range <>) of UsBuff16InType;

	type UsBuff16OutType is record
		frameTxAfull : sl;
	end record;
	constant UsBuff16OutInit : UsBuff16OutType := (
		(others => '0'));						 --frameTxAfull  

	type UsBuff16OutArrayType is array (natural range <>) of UsBuff16OutType;

	type UsBuff32InType is record
		frameTxEnable : sl;
		frameTxSOF	  : sl;
		frameTxEOF	  : sl;
		frameTxEOFE	  : sl;
		frameTxData	  : slv(31 downto 0);
	end record;
	constant UsBuff32InInit : UsBuff32InType := (
		'0',										 --frameTxEnable
		'0',										 --frameTxSOF
		'0',										 --frameTxEOF
		'0',										 --frameTxEOFE
		(others => '0'));						 --frameTxData		

	type UsBuff32InArrayType is array (natural range <>) of UsBuff32InType;

	type UsBuff32OutType is record
		frameTxAfull : sl;
	end record;
	constant UsBuff32OutInit : UsBuff32OutType := (
		(others => '0'));						 --frameTxAfull  

	type UsBuff32OutArrayType is array (natural range <>) of UsBuff32OutType;

	type UsBuff64InType is record
		frameTxEnable : sl;
		frameTxSOF	  : sl;
		frameTxEOF	  : sl;
		frameTxEOFE	  : sl;
		frameTxData	  : slv(63 downto 0);
	end record;
	constant UsBuff64InInit : UsBuff64InType := (
		'0',										 --frameTxEnable
		'0',										 --frameTxSOF
		'0',										 --frameTxEOF
		'0',										 --frameTxEOFE
		(others => '0'));						 --frameTxData 

	type UsBuff64InArrayType is array (natural range <>) of UsBuff64InType;

	type UsBuff64OutType is record
		frameTxAfull : sl;
	end record;
	constant UsBuff64OutInit : UsBuff64OutType := (
		(others => '0'));						 --frameTxAfull  

	type UsBuff64OutArrayType is array (natural range <>) of UsBuff64OutType;

	type UsBuff128InType is record
		frameTxEnable : sl;
		frameTxSOF	  : sl;
		frameTxEOF	  : sl;
		frameTxEOFE	  : sl;
		frameTxData	  : slv(127 downto 0);
	end record;
	constant UsBuff128InInit : UsBuff128InType := (
		'0',										 --frameTxEnable
		'0',										 --frameTxSOF
		'0',										 --frameTxEOF
		'0',										 --frameTxEOFE
		(others => '0'));						 --frameTxData 

	type UsBuff128InArrayType is array (natural range <>) of UsBuff128InType;

	type UsBuff128OutType is record
		frameTxAfull : sl;
	end record;
	constant UsBuff128OutInit : UsBuff128OutType := (
		(others => '0'));						 --frameTxAfull  

	type UsBuff128OutArrayType is array (natural range <>) of UsBuff128OutType;

	------------------------------------------------------------------------
	-- Down Stream Buffer Types/Constants								  
	------------------------------------------------------------------------
	type DsBuff16InType is record
		frameRxReady : sl;
	end record;
	constant DsBuff16InInit : DsBuff16InType := (
		(others => '0'));						 --frameRxReady  

	type DsBuff16InArrayType is array (natural range <>) of DsBuff16InType;

	type DsBuff16OutType is record
		frameRxValid : sl;
		frameRxSOF	 : sl;
		frameRxEOF	 : sl;
		frameRxEOFE	 : sl;
		frameRxData	 : slv(15 downto 0);
	end record;
	constant DsBuff16OutInit : DsBuff16OutType := (
		'0',										 --frameRxValid
		'0',										 --frameRxSOF
		'0',										 --frameRxEOF
		'0',										 --frameRxEOFE
		(others => '0'));						 --frameRxData		

	type DsBuff16OutArrayType is array (natural range <>) of DsBuff16OutType;

	type DsBuff32InType is record
		frameRxReady : sl;
	end record;
	constant DsBuff32InInit : DsBuff32InType := (
		(others => '0'));						 --frameRxReady  

	type DsBuff32ArrayType is array (natural range <>) of DsBuff32InType;

	type DsBuff32OutType is record
		frameRxValid : sl;
		frameRxSOF	 : sl;
		frameRxEOF	 : sl;
		frameRxEOFE	 : sl;
		frameRxData	 : slv(31 downto 0);
	end record;
	constant DsBuff32OutInit : DsBuff32OutType := (
		'0',										 --frameRxValid
		'0',										 --frameRxSOF
		'0',										 --frameRxEOF
		'0',										 --frameRxEOFE
		(others => '0'));						 --frameRxData		

	type DsBuff32OutArrayType is array (natural range <>) of DsBuff32OutType;

	type DsBuff64InType is record
		frameRxReady : sl;
	end record;
	constant DsBuff64InInit : DsBuff64InType := (
		(others => '0'));						 --frameRxReady  

	type DsBuff64ArrayType is array (natural range <>) of DsBuff64InType;

	type DsBuff64OutType is record
		frameRxValid : sl;
		frameRxSOF	 : sl;
		frameRxEOF	 : sl;
		frameRxEOFE	 : sl;
		frameRxData	 : slv(63 downto 0);
	end record;
	constant DsBuff64OutInit : DsBuff64OutType := (
		'0',										 --frameRxValid
		'0',										 --frameRxSOF
		'0',										 --frameRxEOF
		'0',										 --frameRxEOFE
		(others => '0'));						 --frameRxData		

	type DsBuff64OutArrayType is array (natural range <>) of DsBuff64OutType;

	type DsBuff128InType is record
		frameRxReady : sl;
	end record;
	constant DsBuff128InInit : DsBuff128InType := (
		(others => '0'));						 --frameRxReady  

	type DsBuff128ArrayType is array (natural range <>) of DsBuff128InType;

	type DsBuff128OutType is record
		frameRxValid : sl;
		frameRxSOF	 : sl;
		frameRxEOF	 : sl;
		frameRxEOFE	 : sl;
		frameRxData	 : slv(127 downto 0);
	end record;
	constant DsBuff128OutInit : DsBuff128OutType := (
		'0',										 --frameRxValid
		'0',										 --frameRxSOF
		'0',										 --frameRxEOF
		'0',										 --frameRxEOFE
		(others => '0'));						 --frameRxData		

	type DsBuff128OutArrayType is array (natural range <>) of DsBuff128OutType;

	------------------------------------------------------------------------
	-- Some useful initialization constants								
	------------------------------------------------------------------------
	constant PgpTxVcInInit : PgpTxVcInType := (
		'0',										 --frameTxValid
		'0',										 --frameTxSOF
		'0',										 --frameTxEOF
		'0',										 --frameTxEOFE
		(others => (others => '0')),		 --frameTxData
		'0',										 --locBuffAFull
		'0');										 --locBuffFull			

	constant PgpTxVcQuadInInit : PgpTxVcQuadInType := (
		(others => PgpTxVcInInit));

	constant PgpTxVcOutInit : PgpTxVcOutType := (
		(others => '0'));						 --frameTxReady

	constant PgpTxVcQuadOutInit : PgpTxVcQuadOutType := (
		(others => PgpTxVcOutInit));		

	constant PgpRxVcCommonOutInit : PgpRxVcCommonOutType := (
		'0',										 --frameRxSOF
		'0',										 --frameRxEOF
		'0',										 --frameRxEOFE
		(others => (others => '0')));		 --frameRxData


	constant PgpRxVcOutInit : PgpRxVcOutType := (
		'0',										 --frameRxValid
		'0',										 --remBuffAFull
		'0');										 --remBuffFull

	constant PgpRxVcQuadOutInit : PgpRxVcQuadOutType := (
		(others => PgpRxVcOutInit)); 


	constant PgpRxInInit : PgpRxInType := (
		'0',										 --flush
		'0');										 --resetRx			 

	constant PgpRxOutInit : PgpRxOutType := (
		'0',										 --linkReady
		'0',										 --cellError
		'0',	--linkDown
		'0',										 --linkError
		'0',										 --opCodeEn
		(others => '0'),						 --opCode
		'0',										 --remLinkReady
		(others => '0'));						 --remLinkData			  

	constant PgpTxInInit : PgpTxInType := (
		'0',										 --flush
		'0',										 --opCodeEn
		(others => '0'),						 --opCode
		'0',										 --locLinkReady
		(others => '0'));						 --locData						  

	constant PgpTxOutInit : PgpTxOutType := (
		(others => '0'));						 --linkReady  

----------------------------------------------------------------------------------------------------
end package;
