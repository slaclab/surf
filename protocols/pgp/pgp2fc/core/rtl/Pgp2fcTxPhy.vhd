-------------------------------------------------------------------------------
-- Title      : PGPv2fc: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Physical interface receive module for the Pretty Good Protocol version 2 core
-- (fast control implementation). Module has no buffering, input data ignored if
-- pgpBusy is asserted.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcTxPhy is
   generic (
      TPD_G      : time                 := 1 ns;
      FC_WORDS_G : integer range 1 to 8 := 1  -- Number of 16-bit words for fast control, max is packet size minus 1
      );
   port (

      -- System clock, reset & control
      pgpTxClkEn  : in sl := '1';       -- Master clock Enable
      pgpTxClk    : in sl;              -- Master clock
      pgpTxClkRst : in sl;              -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady : out sl;          -- Local side has link

      -- Phy is busy
      pgpBusy : out sl;                 -- Pause incoming PGP datastream

      -- Fast control interface
      fcValid : in  sl;  -- Latch fcWord and send it out, will cause pgpBusy to assert
      fcWord  : in  slv(16*FC_WORDS_G-1 downto 0);  -- Control word to send
      fcSent  : out sl := '0';          -- Asserted when a fast control word is sent out

      -- Sideband data
      pgpLocLinkReady : in sl;               -- Far end side has link
      pgpLocData      : in slv(7 downto 0);  -- Far end side User Data

      -- Cell Transmit Interface
      cellTxSOC  : in sl;                -- Cell data start of cell
      cellTxSOF  : in sl;                -- Cell data start of frame
      cellTxEOC  : in sl;                -- Cell data end of cell
      cellTxEOF  : in sl;                -- Cell data end of frame
      cellTxEOFE : in sl;                -- Cell data end of frame error
      cellTxData : in slv(15 downto 0);  -- Cell data data

      -- Physical Interface Signals
      phyTxData  : out slv(15 downto 0);  -- PHY receive data
      phyTxDataK : out slv(1 downto 0);   -- PHY receive data is K character
      phyTxReady : in  sl                 -- PHY receive interface is ready
      );

end Pgp2fcTxPhy;


-- Define architecture
architecture Pgp2fcTxPhy of Pgp2fcTxPhy is

   -- Local Signals
   signal intTxLinkReady : sl               := '0';
   signal nxtTxLinkReady : sl;
   signal nxtTxData      : slv(15 downto 0);
   signal nxtTxDataK     : slv(1 downto 0);
   signal intTxData      : slv(15 downto 0) := (others => '0');
   signal intTxDataK     : slv(1 downto 0)  := (others => '0');
   signal ltsAData       : slv(15 downto 0);
   signal ltsADataK      : slv(1 downto 0);
   signal ltsBData       : slv(15 downto 0);
   signal ltsBDataK      : slv(1 downto 0);
   signal cellData       : slv(15 downto 0);
   signal cellDataK      : slv(1 downto 0);
   signal fcData         : slv(15 downto 0);
   signal fcDataK        : slv(1 downto 0);

   signal fcWordLatch : slv(16*FC_WORDS_G-1 downto 0) := (others => '0');
   signal fcWordCount : integer range 0 to FC_WORDS_G := 0;

   signal crcRst    : sl;
   signal crcEn     : sl;
   signal crcDataIn : slv(15 downto 0);
   signal crcOut    : slv(7 downto 0);

   -- Physical Link State
   type fsm_states is (
      ST_LOCK_C,
      ST_LTS_A_C,
      ST_LTS_B_C,
      ST_FC_C,
      ST_CELL_C,
      ST_EMPTY_C);

   signal curState  : fsm_states := ST_LOCK_C;
   signal nxtState  : fsm_states;
   signal pendState : fsm_states;       -- Next state if FC wasn't triggered
   signal holdState : fsm_states;

begin

   -- Link status
   pgpTxLinkReady <= intTxLinkReady;
   pgpBusy        <= '1' when curState = ST_FC_C else '0';

   -- State transition sync logic.
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            curState       <= ST_LOCK_C after TPD_G;
            intTxLinkReady <= '0'       after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- Status signal
            intTxLinkReady <= nxtTxLinkReady after TPD_G;

            -- PLL Lock is lost
            if phyTxReady = '0' then
               curState <= ST_LOCK_C after TPD_G;
            else
               curState <= nxtState after TPD_G;
            end if;

            holdState <= pendState after TPD_G;
         end if;
      end if;
   end process;

   -- Fast Control register logic
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         fcSent <= '0';

         if fcValid = '1' then
            fcWordLatch <= fcWord;
         end if;

         if (curState = ST_FC_C) then
            if (fcWordCount = FC_WORDS_G) then
               fcWordCount <= 0;
               fcSent      <= '1';
            else
               fcWordCount <= fcWordCount + 1;
            end if;
         else
            fcWordCount <= 0;
         end if;
      end if;
   end process;


   -- Link control state machine
   process (curState, holdState, fcValid, fcWordCount, fcData, fcDataK, intTxLinkReady, cellTxEOC,
            ltsAData, ltsADataK, ltsBData, ltsBDataK, cellData, cellDataK)
   begin

      case curState is

         -- Wait for lock state
         when ST_LOCK_C =>
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others => '0');
            nxtTxDataK     <= (others => '0');
            nxtState       <= ST_LTS_A_C;
            pendState      <= ST_LTS_A_C;

         -- Transmit Link Training word A
         when ST_LTS_A_C =>
            nxtTxData      <= ltsAData;
            nxtTxDataK     <= ltsADataK;
            nxtTxLinkReady <= intTxLinkReady;
            if fcValid = '1' then
               nxtState <= ST_FC_C;
            else
               nxtState <= ST_LTS_B_C;
            end if;
            pendState <= ST_LTS_B_C;

         -- Transmit Link Training word B
         when ST_LTS_B_C =>
            nxtTxData      <= ltsBData;
            nxtTxDataK     <= ltsBDataK;
            nxtTxLinkReady <= '1';
            if fcValid = '1' then
               nxtState <= ST_FC_C;
            else
               nxtState <= ST_CELL_C;
            end if;
            pendState <= ST_CELL_C;

         -- Transmit Cell Data
         when ST_CELL_C =>
            nxtTxLinkReady <= '1';
            nxtTxData      <= cellData;
            nxtTxDataK     <= cellDataK;

            -- State transition
            if fcValid = '1' then
               nxtState <= ST_FC_C;
            else
               if cellTxEOC = '1' then
                  nxtState <= ST_EMPTY_C;
               else
                  nxtState <= curState;
               end if;
            end if;

            if cellTxEOC = '1' then
               pendState <= ST_EMPTY_C;
            else
               pendState <= curState;
            end if;

         -- Empty location, used to re-adjust delay pipeline
         when ST_EMPTY_C =>
            nxtTxLinkReady <= '1';
            nxtTxData      <= (others => '0');
            nxtTxDataK     <= (others => '0');
            if fcValid = '1' then
               nxtState <= ST_FC_C;
            else
               nxtState <= ST_LTS_A_C;
            end if;
            pendState <= ST_LTS_A_C;

         -- Transmit Control Word Data
         when ST_FC_C =>
            nxtTxLinkReady <= '1';
            nxtTxData      <= fcData;
            nxtTxDataK     <= fcDataK;

            if fcWordCount = FC_WORDS_G then
               if fcValid = '1' then
                  nxtState <= ST_FC_C;
               else
                  nxtState <= holdState;
               end if;
            else
               nxtState <= curState;
            end if;
            pendState <= holdState;

         -- Default state
         when others =>
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others => '0');
            nxtTxDataK     <= (others => '0');
            nxtState       <= ST_LOCK_C;
            pendState      <= ST_LOCK_C;
      end case;
   end process;

   -- Link Training Word A
   ltsAData(7 downto 0)  <= K_LTS_C;
   ltsADataK(0)          <= '1';
   ltsAData(15 downto 8) <= D_102_C;
   ltsADataK(1)          <= '0';

   -- Link Training Word B
   ltsBData(7 downto 0)   <= pgpLocData;
   ltsBDataK(0)           <= '0';
   ltsBData(14 downto 12) <= conv_std_logic_vector(FC_WORDS_G-1, 3);  -- Fast control word count minus 1
   ltsBData(11 downto 8)  <= PGP2FC_ID_C;
   ltsBData(15)           <= pgpLocLinkReady;
   ltsBDataK(1)           <= '0';

   -- Cell Data, lower byte
   cellData(7 downto 0) <= K_SOF_C when cellTxSOF = '1' else
                           K_SOC_C  when cellTxSOC = '1' else
                           K_EOFE_C when cellTxEOFE = '1' else
                           K_EOF_C  when cellTxEOF = '1' else
                           K_EOC_C  when cellTxEOC = '1' else
                           cellTxData(7 downto 0);

   -- Cell Data, upper byte
   cellData(15 downto 8) <= cellTxData(15 downto 8);

   -- Cell Data, lower control
   cellDataK(0) <= '1' when cellTxSOF = '1' or cellTxSOC = '1' or cellTxEOFE = '1' or
                   cellTxEOF = '1' or cellTxEOC = '1' else '0';

   -- Cell Data, upper control
   cellDataK(1) <= '0';

   -- Fast Control data packaging
   fcComb : process(fcWord, fcWordLatch, fcWordCount, crcOut)
   begin
      if (fcWordCount = 0) then
         -- First word
         fcData(7 downto 0)  <= K_FCD_C;
         fcDataK(0)          <= '1';
         fcData(15 downto 8) <= fcWordLatch(7 downto 0);
         fcDataK(1)          <= '0';
         crcDataIn           <= fcWordLatch(7 downto 0) & K_FCD_C;
      elsif (fcWordCount = FC_WORDS_G) then
         -- Last word
         fcData(7 downto 0)  <= fcWordLatch(FC_WORDS_G*16-1 downto (FC_WORDS_G-1)*16+8);
         fcData(15 downto 8) <= crcOut;  -- CRC (unregistered, could cause timing issues)
         fcDataK             <= "00";
         crcDataIn           <= x"00" & fcWordLatch(FC_WORDS_G*16-1 downto (FC_WORDS_G-1)*16+8);
      else
         -- Other words
         fcData    <= fcWordLatch(fcWordCount*16+7 downto (fcWordCount-1)*16+8);
         fcDataK   <= "00";
         crcDataIn <= fcWordLatch(fcWordCount*16+7 downto (fcWordCount-1)*16+8);
      end if;
   end process;

   crcRst <= '1' when fcWordCount = FC_WORDS_G else '0';
   crcEn  <= '1' when curState = ST_FC_C       else '0';

   U_Crc7 : entity surf.CRC7Rtl
      port map (
         rst     => crcRst,
         clk     => pgpTxClk,
         data_in => crcDataIn,
         crc_en  => crcEn,
         crc_out => crcOut
         );

   -- Outgoing data (1-cycle delay)
   -- TODO: Could a cycle be saved here?
   process (pgpTxClk)
   begin
      if rising_edge(pgpTxClk) then
         if pgpTxClkRst = '1' then
            intTxData(15 downto 0) <= (others => '0') after TPD_G;
            intTxDataK(1 downto 0) <= (others => '0') after TPD_G;
         elsif pgpTxClkEn = '1' then
            -- PLL Lock is lost, zero data out
            if phyTxReady = '0' then
               intTxData(15 downto 0) <= (others => '0') after TPD_G;
               intTxDataK(1 downto 0) <= (others => '0') after TPD_G;
            else
               intTxData(15 downto 0) <= nxtTxData(15 downto 0) after TPD_G;
               intTxDataK(1 downto 0) <= nxtTxDataK(1 downto 0) after TPD_G;
            end if;
         end if;
      end if;
   end process;

   phyTxData  <= intTxData;
   phyTxDataK <= intTxDataK;

end Pgp2fcTxPhy;

