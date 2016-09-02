------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
LIBRARY ieee;
LIBRARY unisim;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use unisim.vcomponents.all;

entity Pgp2FrontEnd is 
   port ( 
      
      -- Reference Clock, PGP Clock & Reset Signals
      pgpRefClk        : in  std_logic;
      pgpRefClkOut     : out std_logic;
      pgpClk           : in  std_logic;
      pgpClk2x         : in  std_logic;
      pgpReset         : in  std_logic;

      -- Local clock and reset - 125Mhz
      locClk           : in  std_logic;
      locReset         : in  std_logic;

      -- Local command signal
--      cmdEn            : out std_logic;
--      cmdOpCode        : out std_logic_vector(7  downto 0);
--      cmdCtxOut        : out std_logic_vector(23 downto 0);

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
--      frameTxEnable   : in  std_logic;
--      frameTxSOF      : in  std_logic;
--      frameTxEOF      : in  std_logic;
--      frameTxEOFE     : in  std_logic;
--      frameTxData     : in  std_logic_vector(63 downto 0);
--      frameTxAFull    : out std_logic;

      -- MGT Serial Pins
      pgpRxN          : in  std_logic;
      pgpRxP          : in  std_logic;
      pgpTxN          : out std_logic;
      pgpTxP          : out std_logic
   );
end Pgp2FrontEnd;


-- Define architecture
architecture PgpFrontEnd of Pgp2FrontEnd is
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

   -- Local Signals
   signal vc00FrameTxValid   : std_logic;
   signal vc00FrameTxReady   : std_logic;
   signal vc00FrameTxSOF     : std_logic;
   signal vc00FrameTxEOF     : std_logic;
   signal vc00FrameTxEOFE    : std_logic;
   signal vc00FrameTxData    : std_logic_vector(15 downto 0);
   signal vc00RemBuffAFull   : std_logic;
   signal vc00RemBuffFull    : std_logic;
   signal vc01FrameTxValid   : std_logic;
   signal vc01FrameTxReady   : std_logic;
   signal vc01FrameTxSOF     : std_logic;
   signal vc01FrameTxEOF     : std_logic;
   signal vc01FrameTxEOFE    : std_logic;
   signal vc01FrameTxData    : std_logic_vector(15 downto 0);
   signal vc01RemBuffAFull   : std_logic;
   signal vc01RemBuffFull    : std_logic;
   signal vc0FrameRxSOF      : std_logic;
   signal vc0FrameRxEOF      : std_logic;
   signal vc0FrameRxEOFE     : std_logic;
   signal vc0FrameRxData     : std_logic_vector(15 downto 0);
   signal vc00FrameRxValid   : std_logic;
   signal vc00LocBuffAFull   : std_logic;
   signal vc00LocBuffFull    : std_logic;
   signal vc01FrameRxValid   : std_logic;
   signal vc01LocBuffAFull   : std_logic;
   signal vc01LocBuffFull    : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   pgpRefClkOut <= pgpRefClk;
   pgpTxP       <= '0';
   pgpTxN       <= '1';

   -- Receiver
   U_SimLinkRx: SimLinkRx port map ( 
      rxClk            => pgpClk,
      rxReset          => pgpReset,
      vcFrameRxSOF     => vc0FrameRxSOF,
      vcFrameRxEOF     => vc0FrameRxEOF,
      vcFrameRxEOFE    => vc0FrameRxEOFE,
      vcFrameRxData    => vc0FrameRxData,
      vc0FrameRxValid  => vc00FrameRxValid,
      vc0LocBuffAFull  => vc00LocBuffAFull,
      vc1FrameRxValid  => vc01FrameRxValid,
      vc1LocBuffAFull  => vc01LocBuffAFull,
      vc2FrameRxValid  => open,
      vc2LocBuffAFull  => '0',
      vc3FrameRxValid  => open,
      vc3LocBuffAFull  => '0',
      ethMode          => '0'
   );

   -- Transmitter
   U_SimLinkTx: SimLinkTx port map ( 
      txClk            => pgpClk,
      txReset          => pgpReset,
      vc0FrameTxValid  => '0',
      vc0FrameTxReady  => open,
      vc0FrameTxSOF    => '0',
      vc0FrameTxEOF    => '0',
      vc0FrameTxEOFE   => '0',
      vc0FrameTxData   => (others => '0'),
      vc1FrameTxValid  => vc01FrameTxValid,
      vc1FrameTxReady  => vc01FrameTxReady,
      vc1FrameTxSOF    => vc01FrameTxSOF,
      vc1FrameTxEOF    => vc01FrameTxEOF,
      vc1FrameTxEOFE   => '0',
      vc1FrameTxData   => vc01FrameTxData,
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
      ethMode          => '0'
      );


   -- Lane 0, VC0, External command processor
--   U_ExtCmd: entity work.Pgp2CmdSlave 
--      generic map ( 
--         DestId    => 0,
--         DestMask  => 1,
--         FifoType  => "V5"
--      ) port map ( 
--         pgpRxClk       => pgpClk,           pgpRxReset     => pgpReset,
--         locClk         => locClk,           locReset       => locReset,
--         vcFrameRxValid => vc00FrameRxValid, vcFrameRxSOF   => vc0FrameRxSOF,
--         vcFrameRxEOF   => vc0FrameRxEOF,    vcFrameRxEOFE  => vc0FrameRxEOFE,
--         vcFrameRxData  => vc0FrameRxData,   vcLocBuffAFull => vc00LocBuffAFull,
--         vcLocBuffFull  => vc00LocBuffFull,  cmdEn          => cmdEn,
--         cmdOpCode      => cmdOpCode,        cmdCtxOut      => cmdCtxOut
--      );


   -- Return data, Lane 0, VC0
--   U_DataBuff0: entity work.Pgp2UsBuff64
--     port map ( 
--      pgpClk           => pgpClk,
--      pgpReset         => pgpReset,
--      locClk           => locClk,
--      locReset         => locReset,
--      frameTxValid     => frameTxEnable,
--      frameTxSOF       => frameTxSOF,
--      frameTxEOF       => frameTxEOF,
--      frameTxEOFE      => frameTxEOFE,
--      frameTxData      => frameTxData,
--      frameTxAFull     => frameTxAFull,
--      vcFrameTxValid   => vc00FrameTxValid,
--      vcFrameTxReady   => vc00FrameTxReady,
--      vcFrameTxSOF     => vc00FrameTxSOF,
--      vcFrameTxEOF     => vc00FrameTxEOF,
--      vcFrameTxEOFE    => vc00FrameTxEOFE,
--      vcFrameTxData    => vc00FrameTxData,
--      vcRemBuffAFull   => vc00RemBuffAFull,
--      vcRemBuffFull    => vc00RemBuffFull
--   );


   -- Lane 0, VC1, External register access control
   U_ExtReg: entity work.Pgp2RegSlave generic map ( FifoType => "V5" ) port map (
      pgpRxClk        => pgpClk,           pgpRxReset      => pgpReset,
      pgpTxClk        => pgpClk,           pgpTxReset      => pgpReset,
      locClk          => locClk,           locReset        => locReset,
      vcFrameRxValid  => vc01FrameRxValid, vcFrameRxSOF    => vc0FrameRxSOF,
      vcFrameRxEOF    => vc0FrameRxEOF,    vcFrameRxEOFE   => vc0FrameRxEOFE,
      vcFrameRxData   => vc0FrameRxData,   vcLocBuffAFull  => vc01LocBuffAFull,
      vcLocBuffFull   => vc01LocBuffFull,  vcFrameTxValid  => vc01FrameTxValid,
      vcFrameTxReady  => vc01FrameTxReady, vcFrameTxSOF    => vc01FrameTxSOF,
      vcFrameTxEOF    => vc01FrameTxEOF,   vcFrameTxEOFE   => vc01FrameTxEOFE,
      vcFrameTxData   => vc01FrameTxData,  vcRemBuffAFull  => '0',
      vcRemBuffFull   => '0',              regInp          => regInp,
      regReq          => regReq,           regOp           => regOp,
      regAck          => regAck,           regFail         => regFail,
      regAddr         => regAddr,          regDataOut      => regDataOut,
      regDataIn       => regDataIn
   );

end PgpFrontEnd;

