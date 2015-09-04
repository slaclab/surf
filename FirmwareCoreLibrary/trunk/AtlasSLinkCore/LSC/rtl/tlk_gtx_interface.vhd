-------------------------------------------------------------------------------
-- Title      : Interface between TLK2501 and Virtex-6 GTX
-- Project    : HOLA S-LINK
-------------------------------------------------------------------------------
-- File       : tlk_gtx_interface.vhd
-- Author     : Stefan Haas
-- Company    : CERN PH-ESE
-- Created    : 23-11-11
-- Last update: 2011-12-13
-- Platform   : Windows XP
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Based on code from B.Green written for VILAR
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN PH-ATE
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 23-11-11  1.0      haass	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tlk_gtx_interface is

  port (SYS_RST            : in  std_logic;
        -- GTX receive ports
        GTX_RXUSRCLK2      : in  std_logic;
        GTX_RXDATA         : in  std_logic_vector(15 downto 0);
        GTX_RXCHARISK      : in  std_logic_vector(1 downto 0);
        GTX_RXENCOMMAALIGN : out std_logic;
        -- GTX transmit ports
        GTX_TXUSRCLK2      : in  std_logic;
        GTX_TXCHARISK      : out std_logic_vector(1 downto 0);
        GTX_TXDATA         : out std_logic_vector(15 downto 0);
        -- TLK2501 ports
        TLK_TXD            : in  std_logic_vector(15 downto 0);
        TLK_TXEN           : in  std_logic;
        TLK_TXER           : in  std_logic;
        TLK_RXD            : out std_logic_vector(15 downto 0);
        TLK_RXDV           : out std_logic;
        TLK_RXER           : out std_logic);

end tlk_gtx_interface;

-------------------------------------------------------------------------------

architecture behaviour of tlk_gtx_interface is

  -----------------------------------------------------------------------------
  -- 8B10B characters
  -----------------------------------------------------------------------------
  constant K28_5 : std_logic_vector(7 downto 0) := "10111100";  -- BC
  constant D5_6  : std_logic_vector(7 downto 0) := "11000101";  -- C5
  constant D16_2 : std_logic_vector(7 downto 0) := "01010000";  -- 50
  constant K23_7 : std_logic_vector(7 downto 0) := "11110111";  -- F7
  constant K30_7 : std_logic_vector(7 downto 0) := "11111110";  -- FE

  constant IDLE_Data1 : std_logic_vector(15 downto 0) := D5_6 & K28_5;
  constant IDLE_Data2 : std_logic_vector(15 downto 0) := D16_2 & K28_5;
  constant IDLE_isK   : std_logic_vector(1 downto 0)  := "01";

  constant CarrierExtend_Data : std_logic_vector(15 downto 0) := K23_7 & K23_7;
  constant CarrierExtend_isK  : std_logic_vector(1 downto 0)  := "11";
  constant NormalData_isK     : std_logic_vector(1 downto 0)  := "00";
  constant Error_Data         : std_logic_vector(15 downto 0) := K30_7 & K30_7;
  constant Error_isK          : std_logic_vector(1 downto 0)  := "11";

  -----------------------------------------------------------------------------
  -- FSM states
  -----------------------------------------------------------------------------
  type InitAndSync_t is (ACQ,
                         ACQ1,
                         ACQ2,
                         Sync,
                         Check,
                         CheckInvalid1,
                         CheckInvalid2,
                         CheckValid1,
                         CheckValid2,
                         CheckValid3);

  constant ACQ_c           : std_logic_vector(9 downto 0) := b"0000000001";
  constant ACQ1_c          : std_logic_vector(9 downto 0) := b"0000000010";
  constant ACQ2_c          : std_logic_vector(9 downto 0) := b"0000000100";
  constant Sync_c          : std_logic_vector(9 downto 0) := b"0000001000";
  constant Check_c         : std_logic_vector(9 downto 0) := b"0000010000";
  constant CheckInvalid1_c : std_logic_vector(9 downto 0) := b"0000100000";
  constant CheckInvalid2_c : std_logic_vector(9 downto 0) := b"0001000000";
  constant CheckValid1_c   : std_logic_vector(9 downto 0) := b"0010000000";
  constant CheckValid2_c   : std_logic_vector(9 downto 0) := b"0100000000";
  constant CheckValid3_c   : std_logic_vector(9 downto 0) := b"1000000000";

  -----------------------------------------------------------------------------
  -- Internal signals
  -----------------------------------------------------------------------------
  type RXStatus_t is (IDLE, CarrierExtend, NormalData, ReceiveError, OtherData);
  type TXControl_t is (IDLE, CarrierExtend, NormalData, TransmitError);

  signal TxControl               : TXControl_t;
  signal RxStatus                : RXStatus_t;
  signal RxValid                 : std_logic;  -- Valid character received
  signal RxComma                 : std_logic;  -- Comma received
  signal InitAndSyncMachine      : InitAndSync_t;
  signal next_InitAndSyncMachine : InitAndSync_t;
  signal GTX_RXDATA_REG          : std_logic_vector(GTX_RXDATA'range);
  signal TLK_TXD_REG             : std_logic_vector(TLK_TXD'range);

begin

  -----------------------------------------------------------------------------
  -- TLK receiver synchronization state machine
  -----------------------------------------------------------------------------
  RXInitAndSyncClocking : process (GTX_RXUSRCLK2, SYS_RST) is
  begin
    if SYS_RST = '1' then
      InitAndSyncMachine <= ACQ;
    elsif rising_edge(GTX_RXUSRCLK2) then
      InitAndSyncMachine <= next_InitAndSyncMachine;
    end if;
  end process RXInitAndSyncClocking;

  RxValid <= '1' when ((RXStatus = NormalData) or
                       (RXStatus = ReceiveError) or
                       (RXStatus = IDLE) or
                       (RXStatus = CarrierExtend)) else '0';

  RxComma <= '1' when ((RXStatus = IDLE) or
                       (RXStatus = CarrierExtend)) else '0';

  RXInitAndSync : process (InitAndSyncMachine, RxComma, RxValid) is
  begin
    case InitAndSyncMachine is

      when ACQ =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxComma = '1') then
          next_InitAndSyncMachine <= ACQ1;
--        elsif (RxValid = '1') then 
--          next_InitAndSyncMachine <= Sync;
        else
          next_InitAndSyncMachine <= ACQ;
        end if;

      when ACQ1 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxComma = '1') then
          next_InitAndSyncMachine <= ACQ2;
--        elsif (RxValid = '1') then
--          next_InitAndSyncMachine <= Sync;
        else
          next_InitAndSyncMachine <= ACQ;
        end if;

      when ACQ2 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxComma = '1') then
          next_InitAndSyncMachine <= Sync;
--        elsif (RxValid = '1') then
--          next_InitAndSyncMachine <= Sync;
        else
          next_InitAndSyncMachine <= ACQ;
        end if;

      when Sync =>
        GTX_RXENCOMMAALIGN <= '0';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= Sync;
        else
          next_InitAndSyncMachine <= check;
        end if;

      when check =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= CheckValid1;
        else
          next_InitAndSyncMachine <= CheckInvalid1;
        end if;

      when CheckValid1 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= CheckValid2;
        else
          next_InitAndSyncMachine <= CheckInvalid1;
        end if;

      when CheckValid2 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= CheckValid3;
        else
          next_InitAndSyncMachine <= CheckInvalid1;
        end if;

      when CheckValid3 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= Sync;
        else
          next_InitAndSyncMachine <= CheckInvalid1;
        end if;

      when CheckInvalid1 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= CheckValid1;
        else
          next_InitAndSyncMachine <= CheckInvalid2;
        end if;

      when CheckInvalid2 =>
        GTX_RXENCOMMAALIGN <= '1';
        if (RxValid = '1') then
          next_InitAndSyncMachine <= CheckValid1;
        else
          next_InitAndSyncMachine <= ACQ;
        end if;

      when others =>
        GTX_RXENCOMMAALIGN      <= '1';
        next_InitAndSyncMachine <= ACQ;

    end case;

  end process RXInitAndSync;

-----------------------------------------------------------------------------
-- GTX receive decoder
-----------------------------------------------------------------------------
-- These sections are combinatorial, hopefully most of the logic is simplified
-- This decodes the MGT RX signals
-- Here we assume K characters are marked as commas but we need to ensure characters
-- not marked as Ks are not commas
  RXDecoder : process (GTX_RXUSRCLK2) is
  begin
    if (rising_edge(GTX_RXUSRCLK2)) then
      if ((GTX_RXCHARISK = CarrierExtend_isK) and (GTX_RXDATA = CarrierExtend_Data)) then
        RXStatus <= CarrierExtend;
      elsif ((GTX_RXCHARISK = IDLE_isK) and (GTX_RXDATA(7 downto 0)  = K28_5)) then
        RXStatus <= IDLE;
      elsif ((GTX_RXCHARISK = Error_isK) and (GTX_RXDATA = Error_Data))then
        RXStatus <= ReceiveError;
      elsif (GTX_RXCHARISK = NormalData_isK) then
        RXStatus <= NormalData;
      else
        RXStatus <= OtherData;
      end if;
    end if;
  end process RXDecoder;

  -----------------------------------------------------------------------------
  -- TLK RXDV & RXER encoder
  -----------------------------------------------------------------------------
  RXEncoder : process (GTX_RXUSRCLK2) is
  begin
    if (rising_edge(GTX_RXUSRCLK2)) then
      TLK_RXDV <= '1';                  -- set default
      TLK_RXER <= '1';                  -- set default
      if InitAndSyncMachine = sync then
        case RXStatus is
          when IDLE =>
            TLK_RXDV <= '0';
            TLK_RXER <= '0';
          when CarrierExtend =>
            TLK_RXDV <= '0';
            TLK_RXER <= '1';
          when ReceiveError =>
            TLK_RXDV <= '1';
            TLK_RXER <= '1';
          when NormalData =>
            TLK_RXDV <= '1';
            TLK_RXER <= '0';
          when others => null;
        end case;
      end if;
      -- Data is simply passed on unmodified
      GTX_RXDATA_REG <= GTX_RXDATA;
      TLK_RXD        <= GTX_RXDATA_REG;
    end if;
  end process RXEncoder;

  -----------------------------------------------------------------------------
  -- TLK transmit interface decoder
  -----------------------------------------------------------------------------
  TXDecoder : process (GTX_TXUSRCLK2) is
  begin
    if (rising_edge(GTX_TXUSRCLK2)) then
      if TLK_TXEN = '0' then
        if TLK_TXER = '0' then
          TXControl <= IDLE;
        else
          TXControl <= CarrierExtend;
        end if;
      else
        if TLK_TXER = '0' then
          TXControl <= NormalData;
        else
          TXControl <= TransmitError;
        end if;
      end if;
    end if;
  end process TXDecoder;

  -----------------------------------------------------------------------------
  -- GTX transmit interface encoder
  -----------------------------------------------------------------------------
  TXMux : process (GTX_TXUSRCLK2) is
  begin
    if (rising_edge(GTX_TXUSRCLK2)) then
      TLK_TXD_REG <= TLK_TXD;
      case TXControl is
        when IDLE =>
          GTX_TXCHARISK <= IDLE_isK;
          GTX_TXDATA    <= IDLE_Data1; --IDLE_Data2;
        when CarrierExtend =>
          GTX_TXCHARISK <= CarrierExtend_isK;
          GTX_TXDATA    <= CarrierExtend_Data;
        when NormalData =>
          GTX_TXCHARISK <= NormalData_isK;
          GTX_TXDATA    <= TLK_TXD_REG;
        when TransmitError =>
          GTX_TXCHARISK <= Error_isK;
          GTX_TXDATA    <= Error_Data;
      end case;
    end if;
  end process TXMux;

end behaviour;

