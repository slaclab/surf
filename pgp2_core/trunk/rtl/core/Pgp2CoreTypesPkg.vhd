-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2CoreTypesPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-02
-- Last update: 2012-11-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package Pgp2CoreTypesPkg is

  --------------------------------------------------------------------------------------------------
  -- These types might be useful
  --------------------------------------------------------------------------------------------------
  type slv16Array is array (integer range <>) of std_logic_vector(15 downto 0);

    --------------------------------------------------------------------------------------------------
  -- Virtural Channel IO
  -- Always 4 VCs per lane
  -- Configurable number of lanes
  --------------------------------------------------------------------------------------------------
  type PgpTxVcInType is record
    frameTxValid : std_logic;           -- User frame data is valid
    frameTxSOF   : std_logic;           -- User frame data start of frame
    frameTxEOF   : std_logic;           -- User frame data end of frame
    frameTxEOFE  : std_logic;           -- User frame data error
    frameTxData  : slv16Array(0 to 3);  -- User frame data (up to 4 lanes)
    locBuffAFull : std_logic;           -- Remote buffer almost full
    locBuffFull  : std_logic;           -- Remote buffer full
  end record;

  type PgpTxVcQuadInType is array (0 to 3) of PgpTxVcInType;  -- 4 Virtual Channel inputs
  type PgpTxVcQuadInArray is array (natural range <>) of PgpTxVcQuadInType;

  type PgpTxVcOutType is record
    frameTxReady : std_logic;           -- PGP is ready
  end record PgpTxVcOutType;

  type PgpTxVcQuadOutType is array (0 to 3) of PgpTxVcOutType;
  type PgpTxVcQuadOutArray is array (natural range <>) of PgpTxVcQuadOutType;

  -- Signals common to all Rx Virtual Channels
  type PgpRxVcCommonOutType is record
    frameRxSOF  : std_logic;            -- PGP frame data start of frame
    frameRxEOF  : std_logic;            -- PGP frame data end of frame
    frameRxEOFE : std_logic;            -- PGP frame data error
    frameRxData : slv16Array(0 to 3);   -- PGP frame data
  end record PgpRxVcCommonOutType;

  type PgpRxVcCommonOutArray is array (natural range <>) of PgpRxVcCommonOutType;

  -- One Rx Virtual Channel output
  type PgpRxVcOutType is record
    frameRxValid : std_logic;           -- PGP frame data is valid
    remBuffAFull : std_logic;           -- Remote buffer almost full
    remBuffFull  : std_logic;           -- Remote buffer full
  end record PgpRxVcOutType;

  type PgpRxVcQuadOutType is array (0 to 3) of PgpRxVcOutType;  -- 4 Rx Virtual Channel outputs
  type PgpRxVcQuadOutArray is array (natural range <>) of PgpRxVcQuadOutType;

  --------------------------------------------------------------------------------------------------
  -- PGP Rx and Tx (inclides VC IO)
  --------------------------------------------------------------------------------------------------
  type PgpRxInType is record
    flush : std_logic;                  -- Flush the link
    resetRx : std_logic;
  end record PgpRxInType;

  type PgpRxOutType is record
    linkReady    : std_logic;                     -- Local side has link
    cellError    : std_logic;                     -- A cell error has occured
    linkDown     : std_logic;                     -- A link down event has occured
    linkError    : std_logic;                     -- A link error has occured
    opCodeEn     : std_logic;                     -- Opcode receive enable
    opCode       : std_logic_vector(7 downto 0);  -- Opcode receive value
    remLinkReady : std_logic;                     -- Far end side has link
    remLinkData  : std_logic_vector(7 downto 0);  -- Far end side User Data
--    vcCommon     : PgpRxVcCommonOutType;
--    vcQuad       : PgpRxVcQuadOutType;
  end record PgpRxOutType;

  type PgpTxInType is record
    flush        : std_logic;                     -- Flush the link
    opCodeEn     : std_logic;                     -- Opcode receive enable
    opCode       : std_logic_vector(7 downto 0);  -- Opcode receive value
    locLinkReady : std_logic;                     -- Far end side has link
    locData      : std_logic_vector(7 downto 0);  -- Far end side User Data
--    vcQuad       : PgpTxVcQuadInType;
  end record PgpTxInType;

  type PgpTxOutType is record
    linkReady : std_logic;              -- Local side has link
--    vcQuad    : PgpRxVcQuadOutType;
  end record PgpTxOutType;



  --------------------------------------------------------------------------------------------------
  -- Pgp PHY IO
  --------------------------------------------------------------------------------------------------
  type PgpRxPhyLaneOutType is record
    polarity : std_logic;               -- PHY receive signal polarity
  end record PgpRxPhyLaneOutType;
  type PgpRxPhyLaneOutArray is array (natural range <>) of PgpRxPhyLaneOutType;

  type PgpRxPhyLaneInType is record
    data    : std_logic_vector(15 downto 0);  -- PHY receive data
    dataK   : std_logic_vector(1 downto 0);   -- PHY receive data is K character
    dispErr : std_logic_vector(1 downto 0);   -- PHY receive data has disparity error
    decErr  : std_logic_vector(1 downto 0);   -- PHY receive data not in table
  end record PgpRxPhyLaneInType;
  type PgpRxPhyLaneInArray is array (natural range <>) of PgpRxPhyLaneInType;

  type PgpTxPhyLaneOutType is record
    data  : std_logic_vector(15 downto 0);  -- PHY transmit data
    dataK : std_logic_vector(1 downto 0);   -- PHY transmit data is K character
  end record PgpTxPhyLaneOutType;
  type PgpTxPhyLaneOutArray is array (natural range <>) of PgpTxPhyLaneOutType;

  --------------------------------------------------------------------------------------------------
  -- PGP Cell IO
  --------------------------------------------------------------------------------------------------
  -- Used by both RxCell and TxCell (in opposite directions)
  type PgpCellCtrlType is record
    pause : std_logic;                  -- Cell data pause (Not used by Tx)
    soc   : std_logic;                  -- Cell data start of cell
    sof   : std_logic;                  -- Cell data start of frame
    eoc   : std_logic;                  -- Cell data end of cell
    eof   : std_logic;                  -- Cell data end of frame
    eofe  : std_logic;                  -- Cell data end of frame error
  end record PgpCellCtrlType;

  subtype PgpCellDataType is slv16Array;  -- Cell Data (16 bits per lane)

  --------------------------------------------------------------------------------------------------
  -- PGP Sched IO
  --------------------------------------------------------------------------------------------------
  type PgpTxSchedInType is record
    sof : std_logic;                    -- Cell contained SOF
    eof : std_logic;                    -- Cell contained EOF
    ack : std_logic;                    -- Cell transmit acknowledge
  end record PgpTxSchedInType;

  type PgpTxSchedOutType is record
    idle    : std_logic;                     -- Force IDLE transmit
    req     : std_logic;                     -- Cell transmit request
    timeout : std_logic;                     -- Cell transmit timeout
    dataVc  : std_logic_vector(1 downto 0);  -- Cell transmit virtual channel
  end record PgpTxSchedOutType;


  --------------------------------------------------------------------------------------------------
  -- CRC Type
  --------------------------------------------------------------------------------------------------
  type PgpCrcInType is record
    crcIn : std_logic_vector(63 downto 0);  -- Receive data for CRC
    valid : std_logic;                      -- Receive CRC width, 1=full, 0=32-bit
    width : std_logic;                      -- Receive CRC value init
    init  : std_logic;                      -- Receive data for CRC is valid
  end record PgpCrcInType;

  -- Out type is 32 bit slv

  --------------------------------------------------------------------------------------------------

end package Pgp2CoreTypesPkg;
