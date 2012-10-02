LIBRARY ieee;
LIBRARY unisim;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use unisim.vcomponents.all;

entity EthFrontEnd is 
   port ( 
     
      -- System clock, reset & control
      gtpClk           : in  std_logic;
      gtpClkRst        : in  std_logic;
      gtpRefClk        : in  std_logic;
      gtpRefClkOut     : out std_logic;

      -- Local command signal
      cmdEn            : out std_logic;
      cmdOpCode        : out std_logic_vector(7  downto 0);
      cmdCtxOut        : out std_logic_vector(23 downto 0);

      -- Local register control signals
      regReq           : out std_logic;
      regOp            : out std_logic;
      regInp           : out std_logic;
      regAck           : in  std_logic;
      regFail          : in  std_logic;
      regAddr          : out std_logic_vector(23 downto 0);
      regDataOut       : out std_logic_vector(31 downto 0);
      regDataIn        : in  std_logic_vector(31 downto 0);

      -- Local data transfer signals
      frameTxEnable    : in  std_logic;
      frameTxSOF       : in  std_logic;
      frameTxEOF       : in  std_logic;
      frameTxAfull     : out std_logic;
      frameTxData      : in  std_logic_vector(63 downto 0);

      -- GTP Signals
      gtpRxN           : in  std_logic;
      gtpRxP           : in  std_logic;
      gtpTxN           : out std_logic;
      gtpTxP           : out std_logic
   );
end EthFrontEnd;


-- Define architecture
architecture EthFrontEnd of EthFrontEnd is

   -- Receiver
   component SimLinkRx port ( 
      rxClk            : in    std_logic;
      rxReset          : in    std_logic;
      vcFrameRxSOF     : out   std_logic;
      vcFrameRxEOF     : out   std_logic;
      vcFrameRxEOFE    : out   std_logic;
      vcFrameRxData    : out   std_logic_vector(15 downto 0);
      vc0FrameRxValid  : out   std_logic;
      vc0LocBuffAFull  : in    std_logic;
      vc1FrameRxValid  : out   std_logic;
      vc1LocBuffAFull  : in    std_logic;
      vc2FrameRxValid  : out   std_logic;
      vc2LocBuffAFull  : in    std_logic;
      vc3FrameRxValid  : out   std_logic;
      vc3LocBuffAFull  : in    std_logic;
      ethMode          : in    std_logic
   ); end component;

   -- Transmitter
   component SimLinkTx port ( 
      txClk            : in    std_logic;
      txReset          : in    std_logic;
      vc0FrameTxValid  : in    std_logic;
      vc0FrameTxReady  : out   std_logic;
      vc0FrameTxSOF    : in    std_logic;
      vc0FrameTxEOF    : in    std_logic;
      vc0FrameTxEOFE   : in    std_logic;
      vc0FrameTxData   : in    std_logic_vector(15 downto 0);
      vc1FrameTxValid  : in    std_logic;
      vc1FrameTxReady  : out   std_logic;
      vc1FrameTxSOF    : in    std_logic;
      vc1FrameTxEOF    : in    std_logic;
      vc1FrameTxEOFE   : in    std_logic;
      vc1FrameTxData   : in    std_logic_vector(15 downto 0);
      vc2FrameTxValid  : in    std_logic;
      vc2FrameTxReady  : out   std_logic;
      vc2FrameTxSOF    : in    std_logic;
      vc2FrameTxEOF    : in    std_logic;
      vc2FrameTxEOFE   : in    std_logic;
      vc2FrameTxData   : in    std_logic_vector(15 downto 0);
      vc3FrameTxValid  : in    std_logic;
      vc3FrameTxReady  : out   std_logic;
      vc3FrameTxSOF    : in    std_logic;
      vc3FrameTxEOF    : in    std_logic;
      vc3FrameTxEOFE   : in    std_logic;
      vc3FrameTxData   : in    std_logic_vector(15 downto 0);
      ethMode          : in    std_logic
   ); end component;

   -- Buffer
   component UsBuff 
      port ( 
         sysClk           : in  std_logic;
         sysClkRst        : in  std_logic;
         frameTxValid     : in  std_logic;
         frameTxSOF       : in  std_logic;
         frameTxEOF       : in  std_logic;
         frameTxEOFE      : in  std_logic;
         frameTxData      : in  std_logic_vector(63 downto 0);
         frameTxAFull     : out std_logic;
         vcFrameTxValid   : out std_logic;
         vcFrameTxReady   : in  std_logic;
         vcFrameTxSOF     : out std_logic;
         vcFrameTxEOF     : out std_logic;
         vcFrameTxEOFE    : out std_logic;
         vcFrameTxData    : out std_logic_vector(15 downto 0);
         vcRemBuffAFull   : in  std_logic;
         vcRemBuffFull    : in  std_logic
      );
   end component;

   -- Local Signals
   signal vc0FrameTxValid   : std_logic;
   signal vc0FrameTxReady   : std_logic;
   signal vc0FrameTxSOF     : std_logic;
   signal vc0FrameTxEOF     : std_logic;
   signal vc0FrameTxData    : std_logic_vector(15 downto 0);
   signal vc1FrameTxValid   : std_logic;
   signal vc1FrameTxReady   : std_logic;
   signal vc1FrameTxSOF     : std_logic;
   signal vc1FrameTxEOF     : std_logic;
   signal vc1FrameTxData    : std_logic_vector(15 downto 0);
   signal vcFrameRxSOF      : std_logic;
   signal vcFrameRxEOF      : std_logic;
   signal vcFrameRxEOFE     : std_logic;
   signal vcFrameRxData     : std_logic_vector(15 downto 0);
   signal vc0FrameRxValid   : std_logic;
   signal vc1FrameRxValid   : std_logic;
   signal swapRegDataIn     : std_logic_vector(31 downto 0);
   signal vc0LocBuffAFull   : std_logic;
   signal vc1LocBuffAFull   : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   gtpRefClkOut <= gtpRefClk;
   gtpTxP       <= '0';
   gtpTxN       <= '1';

   -- Receiver
   U_SimLinkRx: SimLinkRx port map ( 
      rxClk            => gtpClk,
      rxReset          => gtpClkRst,
      vcFrameRxSOF     => vcFrameRxSOF,
      vcFrameRxEOF     => vcFrameRxEOF,
      vcFrameRxEOFE    => vcFrameRxEOFE,
      vcFrameRxData    => vcFrameRxData,
      vc0FrameRxValid  => vc0FrameRxValid,
      vc0LocBuffAFull  => vc0LocBuffAFull,
      vc1FrameRxValid  => vc1FrameRxValid,
      vc1LocBuffAFull  => vc1LocBuffAFull,
      vc2FrameRxValid  => open,
      vc2LocBuffAFull  => '0',
      vc3FrameRxValid  => open,
      vc3LocBuffAFull  => '0',
      ethMode          => '1'
   );

   -- Transmitter
   U_SimLinkTx: SimLinkTx port map ( 
      txClk            => gtpClk,
      txReset          => gtpClkRst,
      vc0FrameTxValid  => vc0FrameTxValid,
      vc0FrameTxReady  => vc0FrameTxReady,
      vc0FrameTxSOF    => vc0FrameTxSOF,
      vc0FrameTxEOF    => vc0FrameTxEOF,
      vc0FrameTxEOFE   => '0',
      vc0FrameTxData   => vc0FrameTxData,
      vc1FrameTxValid  => vc1FrameTxValid,
      vc1FrameTxReady  => vc1FrameTxReady,
      vc1FrameTxSOF    => vc1FrameTxSOF,
      vc1FrameTxEOF    => vc1FrameTxEOF,
      vc1FrameTxEOFE   => '0',
      vc1FrameTxData   => vc1FrameTxData,
      vc2FrameTxValid  => '0',
      vc2FrameTxReady  => open,
      vc2FrameTxSOF    => '0',
      vc2FrameTxEOF    => '0',
      vc2FrameTxEOFE   => '0',
      vc2FrameTxData   => (others=>'0'),
      vc3FrameTxValid  => '0',
      vc3FrameTxReady  => open,
      vc3FrameTxSOF    => '0',
      vc3FrameTxEOF    => '0',
      vc3FrameTxEOFE   => '0',
      vc3FrameTxData   => (others=>'0'),
      ethMode          => '1'
   );


   -- Lane 0, VC0, External command processor
   U_ExtCmd: entity EthCmdSlave 
      generic map ( 
         DestId    => 0,
         DestMask  => 1,
         FifoType  => "V5"
      ) port map ( 
         pgpRxClk       => gtpClk,           pgpRxReset     => gtpClkRst,
         locClk         => gtpClk,           locReset       => gtpClkRst,
         vcFrameRxValid => vc0FrameRxValid,  vcFrameRxSOF   => vcFrameRxSOF,
         vcFrameRxEOF   => vcFrameRxEOF,     vcFrameRxEOFE  => vcFrameRxEOFE,
         vcFrameRxData  => vcFrameRxData,    vcLocBuffAFull => vc0LocBuffAFull,
         vcLocBuffFull  => open,             cmdEn          => cmdEn,
         cmdOpCode      => cmdOpCode,        cmdCtxOut      => cmdCtxOut
      );

   -- Return data, Lane 0, VC0
   U_DataBuff0: UsBuff port map ( 
      sysClk           => gtpClk,
      sysClkRst        => gtpClkRst,
      frameTxValid     => frameTxEnable,
      frameTxSOF       => frameTxSOF,
      frameTxEOF       => frameTxEOF,
      frameTxEOFE      => '0',
      frameTxData      => frameTxData,
      frameTxAFull     => frameTxAFull,
      vcFrameTxValid   => vc0FrameTxValid,
      vcFrameTxReady   => vc0FrameTxReady,
      vcFrameTxSOF     => vc0FrameTxSOF,
      vcFrameTxEOF     => vc0FrameTxEOF,
      vcFrameTxEOFE    => open,
      vcFrameTxData    => vc0FrameTxData,
      vcRemBuffAFull   => '0',
      vcRemBuffFull    => '0'
   );

   -- Lane 0, VC1, External register access control
   U_ExtReg: entity EthRegSlave generic map ( FifoType => "V5" ) port map (
      pgpRxClk        => gtpClk,           pgpRxReset      => gtpClkRst,
      pgpTxClk        => gtpClk,           pgpTxReset      => gtpClkRst,
      locClk          => gtpClk,           locReset        => gtpClkRst,
      vcFrameRxValid  => vc1FrameRxValid,  vcFrameRxSOF    => vcFrameRxSOF,
      vcFrameRxEOF    => vcFrameRxEOF,     vcFrameRxEOFE   => vcFrameRxEOFE,
      vcFrameRxData   => vcFrameRxData,    vcLocBuffAFull  => vc1LocBuffAFull,
      vcLocBuffFull   => open,             vcFrameTxValid  => vc1FrameTxValid,
      vcFrameTxReady  => vc1FrameTxReady,  vcFrameTxSOF    => vc1FrameTxSOF,
      vcFrameTxEOF    => vc1FrameTxEOF,    vcFrameTxEOFE   => open,
      vcFrameTxData   => vc1FrameTxData,   vcRemBuffAFull  => '0',
      vcRemBuffFull   => '0',              regInp          => regInp,
      regReq          => regReq,           regOp           => regOp,
      regAck          => regAck,           regFail         => regFail,
      regAddr         => regAddr,          regDataOut      => regDataOut,
      regDataIn       => swapRegDataIn
   );

   swapRegDataIn(15 downto  0) <= regDataIn(31 downto 16);
   swapRegDataIn(31 downto 16) <= regDataIn(15 downto  0);

end EthFrontEnd;

