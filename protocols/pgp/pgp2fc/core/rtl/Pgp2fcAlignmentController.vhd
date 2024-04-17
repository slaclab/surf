-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: GTH RX Byte Alignment Controller
-------------------------------------------------------------------------------
-- This file is part of 'LCLS Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS Timing Core', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp2fcPkg.all;

entity Pgp2fcAlignmentController is
   generic (
      TPD_G          : time   := 1 ns;
      GT_TYPE_G      : string := "GTHE3";   -- or GTYE3, GTHE4, GTYE4
      DRP_ADDR_G     : slv(31 downto 0) := x"00000000";
      TARGET_PHASE_G : sl := '0');
   port (
      -- Control
      stableClk : in sl;
      stableRst : in sl;

      -- Link stability interface
      linkAligned         : out sl;
      linkAlignOverride   : in sl := '0';
      linkAlignSlide      : in sl := '0';
      linkAlignSlideDone  : out sl;
      linkAlignPhaseReq   : in sl := '0';
      linkAlignPhase      : out sl;
      linkAlignPhaseValid : out sl;

      -- Link alignment block interface
      protocolError       : in sl;

      -- GT interface
      rxClk   : in  sl;
      rxReset : out sl;
      rxSlide : out sl;
      rxReady : in  sl;

      -- DRP AXI interface
      axilClk          : in  sl := '0';
      axilRst          : in  sl := '0';
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C);
end entity Pgp2fcAlignmentController;

architecture rtl of Pgp2fcAlignmentController is

   ----------------------------------------------------------------------
   -- GTHE3 = x"0000_0540" (DRP_ADDR=0x150, see UG576 (v1.5) on page 508)
   -- GTYE3 = x"0000_0940" (DRP_ADDR=0x250, see UG578 (v1.3) on page 396)
   -- GTHE4 = x"0000_0940" (DRP_ADDR=0x250, see UG576 (v1.5) on page 421)
   -- GTYE4 = x"0000_0940" (DRP_ADDR=0x250, see UG578 (v1.3) on page 443)
   ----------------------------------------------------------------------
   constant COMMA_ALIGN_LATENCY_OFFSET_C : slv(31 downto 0) := ite((GT_TYPE_G = "GTHE3"), x"0000_0540", x"0000_0940");
   constant COMMA_ALIGN_LATENCY_ADDR_C   : slv(31 downto 0) := (DRP_ADDR_G + COMMA_ALIGN_LATENCY_OFFSET_C);

   signal axiReq : AxiLiteReqType := ('0', '1', COMMA_ALIGN_LATENCY_ADDR_C, (others=>'0'));
   signal axiAck : AxiLiteAckType;

   signal intSlide, intSlideR : sl;
   signal intPhaseReq : sl;

   signal stabWindow : slv(7 downto 0);
   signal stabWindowGood : sl;
   signal stabCounter : slv(7 downto 0);
   constant stabSensitivity : slv(7 downto 0) := x"F0";
   signal stabGood, stabGoodX : sl;

   signal intCommaLat : slv(15 downto 0);
   signal intCommaLatDone : sl;

   type COMMALAT_FSM is (ST_REQ, ST_ACK);
   signal commaLatState : COMMALAT_FSM := ST_REQ;

   signal intReset : sl;
   signal intAlignSlide, intAlignSlidePrev : sl;
   signal intRxSlide : sl;
   signal intRxSlideDone, intRxSlideDoneX : sl;

   type RXSLIDE_FSM is (ST_WAIT, ST_SLIDE);
   signal slideFsmState : RXSLIDE_FSM := ST_WAIT;

   signal slideFsmCounter : integer range 0 to 63 := 63;

   type AUTOALIGN_FSM is (ST_LOCKED, ST_SLIDE, ST_WAIT_SLIDE, ST_PHASE, ST_WAIT_PHASE, ST_RESET, ST_WAIT_READY);
   signal autoAlignState : AUTOALIGN_FSM := ST_WAIT_READY;
   signal autoAlignTimeout : slv(9 downto 0);
   constant TIMEOUT_MAX : slv(9 downto 0) := (others => '1');
   signal autoAlignRetryCount : slv(4 downto 0);
   constant RETRY_MAX : slv(4 downto 0) := toSlv(20, 5); -- 20

   signal autoAlignSlide : sl;
   signal autoAlignPhaseReq : sl;

   signal intReadyX : sl;

--   attribute keep : string;
--   attribute mark_debug : string;

--   attribute keep of autoAlignState, autoAlignTimeout, autoAlignRetryCount, autoAlignSlide, autoAlignPhaseReq, intReadyX, intCommaLatDone, stabGoodX : signal is "TRUE";
--   attribute mark_debug of autoAlignState, autoAlignTimeout, autoAlignRetryCount, autoAlignSlide, autoAlignPhaseReq, intReadyX, intCommaLatDone, stabGoodX : signal is "TRUE";

begin

   -- Wiring for when overriding takes place
   intSlide <= linkAlignSlide when linkAlignOverride = '1' else autoAlignSlide;
   intPhaseReq <= linkAlignPhaseReq when linkAlignOverride = '1' else autoAlignPhaseReq;

   intSlideR <= intSlide when rising_edge(axilClk);

   linkAligned <= stabGoodX;
   linkAlignSlideDone <= intRxSlideDoneX;
   linkAlignPhase <= intCommaLat(0);
   linkAlignPhaseValid <= intCommaLatDone;

   -- RX Slide logic, runs in rxClk domain, needs clock crossing
   U_Reset_Sync : entity surf.RstSync
   generic map (
      RELEASE_DELAY_G => 5)
   port map (
      clk => rxClk,
      asyncRst => stableRst,
      syncRst => intReset);

   U_linkAlignSlide_Sync : entity surf.Synchronizer
   port map (
      clk => rxClk,
      dataIn => intSlideR,
      dataOut => intAlignSlide);

   -- RX Slide State machine
   process (rxClk) begin
      if (rising_edge(rxClk)) then
         if (intReset = '1') then
            intRxSlide <= '0';
            intRxSlideDone <= '0';
            slideFsmState <= ST_WAIT;
            slideFsmCounter <= 63;
         else
            intRxSlide <= '0';
            intRxSlideDone <= '0';

            intAlignSlidePrev <= intAlignSlide;

            case slideFsmState is
               when ST_WAIT =>
                  if (slideFsmCounter = 0) then
                     intRxSlideDone <= '1';
                     if (intAlignSlide = '1' and intAlignSlidePrev = '0') then
                        slideFsmState <= ST_SLIDE;
                        slideFsmCounter <= 63;
                     end if;
                  else
                     if (slideFsmCounter /= 0) then
                        slideFsmCounter <= slideFsmCounter - 1;
                     end if;
                  end if;

               when ST_SLIDE =>
                  intRxSlide <= '1';
                  slideFsmCounter <= slideFsmCounter - 1;
                  if (slideFsmCounter = 62) then
                     slideFsmState <= ST_WAIT;
                     slideFsmCounter <= 63;
                  end if;

               when others =>
                  slideFsmState <= ST_WAIT;
                  slideFsmCounter <= 63;
            end case;
         end if;
      end if;
   end process;

   rxSlide <= intRxSlide;

   U_linkAlignSlideDone_Sync : entity surf.Synchronizer
   port map (
      clk => stableClk,
      dataIn => intRxSlideDone,
      dataOut => intRxSlideDoneX);

   -- Phase detection using the DRP interface (axilClk domain)
   process (axilClk) begin
      if (rising_edge(axilClk)) then
         if (stableRst = '1') then
            intCommaLatDone <= '0';
            axiReq.request  <= '0';
            intCommaLat  <= (others => '0');
            commaLatState   <= ST_REQ;
         else
            case commaLatState is
               when ST_REQ =>
                  if (intPhaseReq = '1') then
                     intCommaLatDone <= '0';
                     axiReq.request  <= '1';
                     intCommaLat  <= (others => '0');
                     commaLatState   <= ST_ACK;
                  end if;

               when ST_ACK =>
                  if (axiAck.done = '1') then
                     intCommaLatDone <= '1';
                     axiReq.request  <= '0';
                     intCommaLat  <= axiAck.rdData(15 downto 0);
                     commaLatState   <= ST_REQ;
                  end if;

               when others =>
                  intCommaLatDone <= '0';
                  axiReq.request  <= '0';
                  intCommaLat  <= (others => '0');
                  commaLatState   <= ST_REQ;
            end case;
         end if;
      end if;
   end process;

   U_AxiLiteMaster : entity surf.AxiLiteMaster
   generic map (
      TPD_G => TPD_G)
   port map (
      req             => axiReq,
      ack             => axiAck,
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilWriteMaster => mAxilWriteMaster,
      axilWriteSlave  => mAxilWriteSlave,
      axilReadMaster  => mAxilReadMaster,
      axilReadSlave   => mAxilReadSlave);

   -- Protocol link stability checker (rxClk domain)
   process (rxClk) begin
      if (rising_edge(rxClk)) then
         if (intReset = '1') then
            stabWindow <= (others => '0');
            stabWindowGood <= '0';
            stabCounter <= (others => '1'); -- Start in bad stability state
            stabGood <= '0';
         else
            stabWindowGood <= '0';

            -- Stability window, 256 consecutive good alignments required
            if (protocolError = '1') then
               stabWindow <= (others => '0');
            elsif (stabWindow /= x"FF") then
               stabWindow <= stabWindow + 1;
            else
               stabWindowGood <= '1';
            end if;

            if (stabWindowGood = '1') then
               stabCounter <= (others => '0');
            else
               if (protocolError = '1' and stabCounter /= x"FF") then
                  stabCounter <= stabCounter + 1;
               end if;
            end if;

            if (stabCounter >= stabSensitivity) then
               stabGood <= '0';
            else
               stabGood <= '1';
            end if;
         end if;
      end if;
   end process;

   U_stabGood_Sync : entity surf.Synchronizer
   port map (
      clk => stableClk,
      dataIn => stabGood,
      dataOut => stabGoodX);

   U_rxReady_Sync : entity surf.Synchronizer
   port map (
      clk => stableClk,
      dataIn => rxReady,
      dataOut => intReadyX);

   -- Automatic alignment state-machine (axilClk domain)
   process (axilClk) begin
      if (rising_edge(axilClk)) then
         if (stableRst = '1' or linkAlignOverride = '1') then
            autoAlignState <= ST_WAIT_READY;
            autoAlignTimeout <= (others => '0');
            autoAlignRetryCount <= (others => '0');
            autoAlignSlide <= '0';
            autoAlignPhaseReq <= '0';
            rxReset <= '0';
         else
            -- Defaults
            autoAlignTimeout <= (others => '0');
            autoAlignRetryCount <= (others => '0');
            autoAlignSlide <= '0';
            autoAlignPhaseReq <= '0';
            rxReset <= '0';

            case autoAlignState is
               when ST_LOCKED =>
                  if (intReadyX = '0') then
                     autoAlignState <= ST_WAIT_READY;
                  elsif (stabGoodX = '0') then
                     autoAlignState <= ST_SLIDE;
                  end if;

               when ST_SLIDE =>
                  autoAlignSlide <= '1';
                  autoAlignRetryCount <= autoAlignRetryCount + 1;
                  autoAlignState <= ST_WAIT_SLIDE;

               when ST_WAIT_SLIDE =>
                  -- This assumes slide will work and we
                  -- are waiting for protocol to be stable
                  autoAlignTimeout <= autoAlignTimeout + 1;

                  if (autoAlignTimeout = TIMEOUT_MAX) then
                     -- Retry to slide
                     if (autoAlignRetryCount = RETRY_MAX) then
                        -- Max number of RXSLIDES done
                        rxReset <= '1';
                        autoAlignState <= ST_RESET;
                     else
                        autoAlignState <= ST_SLIDE;
                     end if;
                  elsif (stabGoodX = '1') then
                     -- Protocol stable, check phase
                     autoAlignState <= ST_PHASE;
                     autoAlignPhaseReq <= '1';
                  end if;

               when ST_PHASE =>
                  -- Delay for the phase block
                  autoAlignState <= ST_WAIT_PHASE;

               when ST_WAIT_PHASE =>
                  -- Wait for DRP phase to be ready
                  autoAlignTimeout <= autoAlignTimeout + 1;

                  if (autoAlignTimeout = TIMEOUT_MAX) then
                     -- Some issue with DRP, reset
                     rxReset <= '1';
                     autoAlignState <= ST_RESET;
                  elsif (intCommaLatDone = '1') then
                     if (intCommaLat(0) = TARGET_PHASE_G) then
                        autoAlignState <= ST_LOCKED;
                     else
                        -- Wrong phase, only fixed by a reset
                        rxReset <= '1';
                        autoAlignState <= ST_RESET;
                     end if;
                  end if;

               when ST_RESET =>
                  -- Delay for the reset FSM
                  autoAlignTimeout <= autoAlignTimeout + 1;

                  if (autoAlignTimeout = TIMEOUT_MAX) then
                     autoAlignState <= ST_WAIT_READY;
                  end if;

               when ST_WAIT_READY =>
                  if (intReadyX = '1') then
                     -- Check the status of the link after the reset
                     autoAlignState <= ST_WAIT_SLIDE;
                  end if;

               when others =>
                  autoAlignState <= ST_WAIT_READY;
                  autoAlignTimeout <= (others => '0');
                  autoAlignRetryCount <= (others => '0');
                  autoAlignSlide <= '0';
                  autoAlignPhaseReq <= '0';
            end case;
         end if;
      end if;
   end process;


end rtl;
