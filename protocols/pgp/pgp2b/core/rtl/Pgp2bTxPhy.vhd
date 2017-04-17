-------------------------------------------------------------------------------
-- File       : Pgp2bTxPhy.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Physical interface receive module for the Pretty Good Protocol version 2 core. 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bTxPhy is 
   generic (
      TPD_G         : time                 := 1 ns;
      TX_LANE_CNT_G : integer range 1 to 2 := 1  -- Number of receive lanes, 1-2
   );
   port ( 

      -- System clock, reset & control
      pgpTxClkEn        : in  sl := '1';                        -- Master clock Enable
      pgpTxClk          : in  sl;                               -- Master clock
      pgpTxClkRst       : in  sl;                               -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady    : out sl;                               -- Local side has link

      -- Opcode Transmit Interface
      pgpTxOpCodeEn     : in  sl;                               -- Opcode receive enable
      pgpTxOpCode       : in  slv(7 downto 0);                  -- Opcode receive value

      -- Sideband data
      pgpLocLinkReady   : in  sl;                               -- Far end side has link
      pgpLocData        : in  slv(7 downto 0);                  -- Far end side User Data

      -- Cell Transmit Interface
      cellTxSOC         : in  sl;                               -- Cell data start of cell
      cellTxSOF         : in  sl;                               -- Cell data start of frame
      cellTxEOC         : in  sl;                               -- Cell data end of cell
      cellTxEOF         : in  sl;                               -- Cell data end of frame
      cellTxEOFE        : in  sl;                               -- Cell data end of frame error
      cellTxData        : in  slv(TX_LANE_CNT_G*16-1 downto 0); -- Cell data data

      -- Physical Interface Signals
      phyTxData         : out slv(TX_LANE_CNT_G*16-1 downto 0); -- PHY receive data
      phyTxDataK        : out slv(TX_LANE_CNT_G*2-1  downto 0); -- PHY receive data is K character
      phyTxReady        : in  sl                                -- PHY receive interface is ready
   ); 

end Pgp2bTxPhy;


-- Define architecture
architecture Pgp2bTxPhy of Pgp2bTxPhy is

   -- Local Signals
   signal algnCnt        : slv(6 downto 0);
   signal algnCntRst     : sl;
   signal intTxLinkReady : sl;
   signal nxtTxLinkReady : sl;
   signal nxtTxData      : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal nxtTxDataK     : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal dlyTxData      : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal dlyTxDataK     : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal dlySelect      : sl;
   signal intTxData      : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal intTxDataK     : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal intTxOpCode    : slv(7 downto 0);
   signal intTxOpCodeEn  : sl;
   signal skpAData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal skpADataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal skpBData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal skpBDataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal alnAData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal alnADataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal alnBData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal alnBDataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal ltsAData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal ltsADataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal ltsBData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal ltsBDataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal cellData       : slv(TX_LANE_CNT_G*16-1 downto 0);
   signal cellDataK      : slv(TX_LANE_CNT_G*2-1  downto 0);
   signal dlyTxEOC       : sl;

   -- Physical Link State
   constant ST_LOCK_C  : slv(3 downto 0) := "0000";
   constant ST_SKP_A_C : slv(3 downto 0) := "0001";
   constant ST_SKP_B_C : slv(3 downto 0) := "0010";
   constant ST_LTS_A_C : slv(3 downto 0) := "0011";
   constant ST_LTS_B_C : slv(3 downto 0) := "0100";
   constant ST_ALN_A_C : slv(3 downto 0) := "0101";
   constant ST_ALN_B_C : slv(3 downto 0) := "0110";
   constant ST_CELL_C  : slv(3 downto 0) := "0111";
   constant ST_EMPTY_C : slv(3 downto 0) := "1000";
   signal   curState   : slv(3 downto 0);
   signal   nxtState   : slv(3 downto 0);

begin

   -- Link status
   pgpTxLinkReady <= intTxLinkReady;

   -- State transition sync logic. 
   process ( pgpTxClk ) begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            curState         <= ST_LOCK_C     after TPD_G;
            algnCnt          <= (others=>'0') after TPD_G;
            intTxLinkReady   <= '0'           after TPD_G;
            intTxOpCode      <= (others=>'0') after TPD_G;
            intTxOpCodeEn    <= '0'           after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- Opcode Transmit
            if pgpTxOpCodeEn = '1' then
               intTxOpCode <= pgpTxOpCode after TPD_G;
            end if;
            intTxOpCodeEn <= pgpTxOpCodeEn after TPD_G;

            -- Status signal
            intTxLinkReady <= nxtTxLinkReady after TPD_G;

            -- PLL Lock is lost
            if phyTxReady = '0' then
               curState   <= ST_LOCK_C after TPD_G;
            else
               curState <= nxtState after TPD_G;
            end if;

            -- Cell Counter
            if algnCntRst = '1' then
               algnCnt <= (others=>'1') after TPD_G;
            elsif algnCnt /= 0 and cellTxEOC = '1' then
               algnCnt <= algnCnt - 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;


   -- Link control state machine
   process ( curState, intTxLinkReady, cellTxEOC, algnCnt,
             skpAData, skpADataK, skpBData, skpBDataK, alnAData, alnADataK, alnBData,
             alnBDataK, ltsAData, ltsADataK, ltsBData, ltsBDataK, cellData, cellDataK ) begin
      case curState is 

         -- Wait for lock state
         when ST_LOCK_C =>
            algnCntRst     <= '1';
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');
            nxtState       <= ST_SKP_A_C;

         -- Transmit SKIP word A
         when ST_SKP_A_C => 
            nxtTxData      <= skpAData;
            nxtTxDataK     <= skpADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_SKP_B_C;

         -- Transmit SKIP word B
         when ST_SKP_B_C => 
            nxtTxData      <= skpBData;
            nxtTxDataK     <= skpBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_A_C;

         -- Transmit Align word A
         when ST_ALN_A_C => 
            nxtTxData      <= alnAData;
            nxtTxDataK     <= alnADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_ALN_B_C;

         -- Transmit Align word B
         when ST_ALN_B_C => 
            nxtTxData      <= alnBData;
            nxtTxDataK     <= alnBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_A_C;

         -- Transmit Link Training word A
         when ST_LTS_A_C => 
            nxtTxData      <= ltsAData;
            nxtTxDataK     <= ltsADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_B_C;

         -- Transmit Link Training word B
         when ST_LTS_B_C => 
            nxtTxData      <= ltsBData;
            nxtTxDataK     <= ltsBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= '1';
            nxtState       <= ST_CELL_C;

         -- Transmit Cell Data
         when ST_CELL_C => 
            nxtTxLinkReady <= '1';
            nxtTxData      <= cellData;
            nxtTxDataK     <= cellDataK;
            algnCntRst     <= '0';

            -- State transition
            if cellTxEOC = '1' then
               nxtState   <= ST_EMPTY_C;
            else
               nxtState   <= curState;
            end if;

         -- Empty location, used to re-adjust delay pipeline
         when ST_EMPTY_C => 
            nxtTxLinkReady <= '1';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');

            -- After enough cells send alignment word
            if algnCnt = 0 then
               algnCntRst <= '1';
               nxtState   <= ST_ALN_A_C;
            else
               algnCntRst <= '0';
               nxtState   <= ST_SKP_A_C;
            end if;

         -- Default state
         when others =>
            algnCntRst     <= '0';
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');
            nxtState       <= ST_LOCK_C;
      end case;
   end process;


   -- Generate Data
   GEN_DATA: for i in 0 to (TX_LANE_CNT_G-1) generate

      -- Skip word A
      skpAData(i*16+7  downto i*16)   <= K_COM_C;
      skpADataK(i*2)                  <= '1';
      skpAData(i*16+15 downto i*16+8) <= K_SKP_C;
      skpADataK(i*2+1)                <= '1';

      -- Skip word B
      skpBData(i*16+7  downto i*16)   <= K_SKP_C;
      skpBDataK(i*2)                  <= '1';
      skpBData(i*16+15 downto i*16+8) <= K_SKP_C;
      skpBDataK(i*2+1)                <= '1';

      -- Alignment Word A
      alnAData(i*16+7  downto i*16)   <= K_COM_C;
      alnADataK(i*2)                  <= '1';
      alnAData(i*16+15 downto i*16+8) <= K_ALN_C;
      alnADataK(i*2+1)                <= '1';

      -- Alignment Word B
      alnBData(i*16+7  downto i*16)   <= K_ALN_C;
      alnBDataK(i*2)                  <= '1';
      alnBData(i*16+15 downto i*16+8) <= K_ALN_C;
      alnBDataK(i*2+1)                <= '1';

      -- Link Training Word A
      ltsAData(i*16+7  downto i*16)   <= K_LTS_C;
      ltsADataK(i*2)                  <= '1';
      ltsAData(i*16+15 downto i*16+8) <= D_102_C;
      ltsADataK(i*2+1)                <= '0';

      -- Link Training Word B
      ltsBData(i*16+7  downto i*16)    <= pgpLocData;
      ltsBDataK(i*2)                   <= '0';
      ltsBData(i*16+14)                <= '0'; -- Spare
      ltsBData(i*16+13 downto i*16+12) <= conv_std_logic_vector(TX_LANE_CNT_G-1,2);
      ltsBData(i*16+11 downto i*16+8)  <= PGP2B_ID_C;
      ltsBData(i*16+15)                <= pgpLocLinkReady;
      ltsBDataK(i*2+1)                 <= '0';

      -- Cell Data, lower byte
      cellData(i*16+7  downto i*16) <= K_SOF_C  when cellTxSOF  = '1' else
                                       K_SOC_C  when cellTxSOC  = '1' else
                                       K_EOFE_C when cellTxEOFE = '1' else
                                       K_EOF_C  when cellTxEOF  = '1' else
                                       K_EOC_C  when cellTxEOC  = '1' else
                                       cellTxData(i*16+7 downto i*16);

      -- Cell Data, upper byte
      cellData(i*16+15 downto i*16+8) <= cellTxData(i*16+15 downto i*16+8);

      -- Cell Data, lower control
      cellDataK(i*2) <= '1' when cellTxSOF = '1' or cellTxSOC = '1' or cellTxEOFE = '1' or 
                                 cellTxEOF = '1' or cellTxEOC = '1' else '0'; 

      -- Cell Data, upper control
      cellDataK(i*2+1) <= '0';
   end generate;


   -- Delay chain select, used when an opcode is transmitted.
   -- opcode will overwrite current position and delay chain will
   -- be selected until an EOC is transmitted. At that time the
   -- non-delayed chain will be select. An empty position is inserted
   -- after EOC so that valid opcodes are not lost.
   process ( pgpTxClk ) begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            dlySelect <= '0' after TPD_G;
            dlyTxEOC  <= '0' after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- Choose delay chain when opcode is transmitted
            if intTxOpCodeEn = '1' then
               dlySelect <= '1' after TPD_G;
           
            -- Reset delay chain when delayed EOC is transmitted
            elsif dlyTxEOC = '1' then
               dlySelect <= '0' after TPD_G;
            end if;

            -- Delayed copy of EOC
            dlyTxEOC <= cellTxEOC after TPD_G;

         end if;
      end if;
   end process;


   -- Outgoing data
   GEN_OUT: for i in 0 to (TX_LANE_CNT_G-1) generate
      process ( pgpTxClk ) begin
         if rising_edge(pgpTxClk) then
            if pgpTxClkRst = '1' then
               intTxData(i*16+15 downto i*16) <= (others=>'0') after TPD_G;
               intTxDataK(i*2+1  downto i*2)  <= (others=>'0') after TPD_G;
               dlyTxData(i*16+15 downto i*16) <= (others=>'0') after TPD_G;
               dlyTxDataK(i*2+1  downto i*2)  <= (others=>'0') after TPD_G;
            elsif pgpTxClkEn = '1' then
               -- Delayed copy of data
               dlyTxData(i*16+15 downto i*16) <= nxtTxData(i*16+15 downto i*16) after TPD_G;
               dlyTxDataK(i*2+1  downto i*2)  <= nxtTxDataK(i*2+1  downto i*2)  after TPD_G;

               -- PLL Lock is lost
               if phyTxReady = '0' then
                  intTxData(i*16+15 downto i*16) <= (others=>'0') after TPD_G;
                  intTxDataK(i*2+1  downto i*2)  <= (others=>'0') after TPD_G;
               else

                  -- Delayed data, opcode transmission is not allowed until delay line resets
                  if dlySelect = '1' then
                     intTxData(i*16+15 downto i*16) <= dlyTxData(i*16+15 downto i*16) after TPD_G;
                     intTxDataK(i*2+1  downto i*2)  <= dlyTxDataK(i*2+1  downto i*2)  after TPD_G;

                  -- Transmit opcode
                  elsif intTxOpCodeEn = '1' then
                     intTxData(i*16+7  downto i*16)   <= K_OTS_C     after TPD_G;
                     intTxDataK(i*2)                  <= '1'         after TPD_G;
                     intTxData(i*16+15 downto i*16+8) <= intTxOpCode after TPD_G;
                     intTxDataK(i*2+1)                <= '0'         after TPD_G;

                  -- Nornal Data
                  else 
                     intTxData(i*16+15 downto i*16) <= nxtTxData(i*16+15 downto i*16) after TPD_G;
                     intTxDataK(i*2+1  downto i*2)  <= nxtTxDataK(i*2+1  downto i*2)  after TPD_G;
                  end if;
               end if;
            end if;
         end if;
      end process;
   end generate;

   -- Outgoing data
   phyTxData  <= intTxData;
   phyTxDataK <= intTxDataK;

end Pgp2bTxPhy;

