-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Coherent vector clock-domain crossing with a full handshake
--
-- srcSend may only start when srcRcv is low and must remain asserted until
-- srcRcv asserts. The source payload is captured internally when srcSend
-- starts, then held until the complete four-phase handshake returns to idle.
-- With DEST_EXT_HSK_G=true, destReq remains asserted until destAck asserts and
-- destAck must remain asserted until destReq deasserts. With false, destReq is
-- a one-destClk-cycle valid pulse and the destination acknowledges internally.
--
-- Source and destination resets must be asserted together to abort an in-flight
-- transfer. A unilateral reset can drop or replay that transfer. No transfer is
-- guaranteed while either reset is asserted or while the handshake returns to
-- idle after reset.
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

library surf;
use surf.StdRtlPkg.all;

entity SynchronizerHandshake is
   generic (
      TPD_G              : time     := 1 ns;
      RST_POLARITY_G     : sl       := '1';
      RST_ASYNC_G        : boolean  := false;
      COMMON_CLK_G       : boolean  := false;  -- srcClk and destClk are identical
      SYNTH_MODE_G       : string   := "inferred";  -- Currently supports inferred only
      SRC_SYNC_STAGES_G  : positive := 2;
      DEST_SYNC_STAGES_G : positive := 2;
      DEST_EXT_HSK_G     : boolean  := true;  -- Require destination acknowledgment
      DATA_WIDTH_G       : positive := 16);
   port (
      -- Source clock domain
      srcClk  : in  sl;
      srcRst  : in  sl := not RST_POLARITY_G;
      srcData : in  slv(DATA_WIDTH_G-1 downto 0);
      srcSend : in  sl;
      srcRcv  : out sl;
      -- Destination clock domain
      destClk  : in  sl;
      destRst  : in  sl := not RST_POLARITY_G;
      destData : out slv(DATA_WIDTH_G-1 downto 0);
      destReq  : out sl;
      destAck  : in  sl := '0');
end entity SynchronizerHandshake;

architecture rtl of SynchronizerHandshake is

   type SrcStateType is (
      SRC_IDLE_S,
      SRC_WAIT_ACK_S,
      SRC_WAIT_SEND_LOW_S,
      SRC_WAIT_ACK_LOW_S);

   type SrcRegType is record
      req   : sl;
      rcv   : sl;
      state : SrcStateType;
   end record SrcRegType;

   constant SRC_REG_INIT_C : SrcRegType := (
      req   => '0',
      rcv   => '0',
      state => SRC_IDLE_S);

   type DestStateType is (
      DEST_IDLE_S,
      DEST_WAIT_ACK_S,
      DEST_WAIT_REQ_LOW_S,
      DEST_WAIT_ACK_LOW_S);

   type DestRegType is record
      req   : sl;
      ack   : sl;
      state : DestStateType;
   end record DestRegType;

   constant DEST_REG_INIT_C : DestRegType := (
      req   => '0',
      ack   => '0',
      state => DEST_IDLE_S);

   signal srcR   : SrcRegType := SRC_REG_INIT_C;
   signal srcRin : SrcRegType;

   signal destR   : DestRegType := DEST_REG_INIT_C;
   signal destRin : DestRegType;

   signal srcDataReg  : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
   signal srcDataRin  : slv(DATA_WIDTH_G-1 downto 0);
   signal destDataReg : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
   signal destDataRin : slv(DATA_WIDTH_G-1 downto 0);

   signal reqSync : sl := '0';
   signal ackSync : sl := '0';

begin

   assert (SYNTH_MODE_G = "inferred")
      report "SynchronizerHandshake: SYNTH_MODE_G currently supports inferred only"
      severity failure;

   assert (SRC_SYNC_STAGES_G >= 2)
      report "SynchronizerHandshake: SRC_SYNC_STAGES_G must be >= 2"
      severity failure;

   assert (DEST_SYNC_STAGES_G >= 2)
      report "SynchronizerHandshake: DEST_SYNC_STAGES_G must be >= 2"
      severity failure;

   assert (srcRst = RST_POLARITY_G) or (srcR.state /= SRC_WAIT_ACK_S) or (srcSend = '1')
      report "SynchronizerHandshake: srcSend deasserted before srcRcv asserted"
      severity warning;

   assert (not DEST_EXT_HSK_G) or (destRst = RST_POLARITY_G) or
          (destR.state /= DEST_IDLE_S) or (destAck = '0')
      report "SynchronizerHandshake: destAck asserted without destReq"
      severity warning;

   GEN_ASYNC : if (not COMMON_CLK_G) generate

      U_ReqSync : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            STAGES_G       => DEST_SYNC_STAGES_G)
         port map (
            clk     => destClk,   -- [in]
            rst     => destRst,   -- [in]
            dataIn  => srcR.req,  -- [in]
            dataOut => reqSync);  -- [out]

      U_AckSync : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            STAGES_G       => SRC_SYNC_STAGES_G)
         port map (
            clk     => srcClk,    -- [in]
            rst     => srcRst,    -- [in]
            dataIn  => destR.ack, -- [in]
            dataOut => ackSync);  -- [out]

   end generate GEN_ASYNC;

   GEN_COMMON : if (COMMON_CLK_G) generate

      reqSync <= srcR.req;
      ackSync <= destR.ack;

   end generate GEN_COMMON;

   srcComb : process (ackSync, srcData, srcDataReg, srcR, srcRst, srcSend) is
      variable v     : SrcRegType;
      variable dataV : slv(DATA_WIDTH_G-1 downto 0);
   begin
      v     := srcR;
      dataV := srcDataReg;

      case srcR.state is
         when SRC_IDLE_S =>
            if (srcSend = '1') then
               dataV   := srcData;
               v.req   := '1';
               v.state := SRC_WAIT_ACK_S;
            end if;

         when SRC_WAIT_ACK_S =>
            if (ackSync = '1') then
               v.rcv   := '1';
               v.state := SRC_WAIT_SEND_LOW_S;
            end if;

         when SRC_WAIT_SEND_LOW_S =>
            if (srcSend = '0') then
               v.req   := '0';
               v.state := SRC_WAIT_ACK_LOW_S;
            end if;

         when SRC_WAIT_ACK_LOW_S =>
            if (ackSync = '0') then
               v.rcv   := '0';
               v.state := SRC_IDLE_S;
            end if;
      end case;

      if (not RST_ASYNC_G) and (srcRst = RST_POLARITY_G) then
         v     := SRC_REG_INIT_C;
         dataV := (others => '0');
      end if;

      srcRin     <= v;
      srcDataRin <= dataV;

      srcRcv <= srcR.rcv;
   end process srcComb;

   srcSeq : process (srcClk, srcRst) is
   begin
      if (RST_ASYNC_G) and (srcRst = RST_POLARITY_G) then
         srcR       <= SRC_REG_INIT_C after TPD_G;
         srcDataReg <= (others => '0') after TPD_G;
      elsif rising_edge(srcClk) then
         srcR       <= srcRin     after TPD_G;
         srcDataReg <= srcDataRin after TPD_G;
      end if;
   end process srcSeq;

   destComb : process (destAck, destDataReg, destR, destRst, reqSync, srcDataReg) is
      variable v     : DestRegType;
      variable dataV : slv(DATA_WIDTH_G-1 downto 0);
   begin
      v     := destR;
      dataV := destDataReg;

      case destR.state is
         when DEST_IDLE_S =>
            if (reqSync = '1') then
               dataV := srcDataReg;
               v.req := '1';

               if DEST_EXT_HSK_G then
                  v.state := DEST_WAIT_ACK_S;
               else
                  v.ack   := '1';
                  v.state := DEST_WAIT_REQ_LOW_S;
               end if;
            end if;

         when DEST_WAIT_ACK_S =>
            if (destAck = '1') then
               v.ack   := '1';
               v.state := DEST_WAIT_REQ_LOW_S;
            end if;

         when DEST_WAIT_REQ_LOW_S =>
            if not DEST_EXT_HSK_G then
               v.req := '0';
            end if;

            if (reqSync = '0') then
               v.req := '0';

               if DEST_EXT_HSK_G then
                  v.state := DEST_WAIT_ACK_LOW_S;
               else
                  v.ack   := '0';
                  v.state := DEST_IDLE_S;
               end if;
            end if;

         when DEST_WAIT_ACK_LOW_S =>
            if (destAck = '0') then
               v.ack   := '0';
               v.state := DEST_IDLE_S;
            end if;
      end case;

      if (not RST_ASYNC_G) and (destRst = RST_POLARITY_G) then
         v     := DEST_REG_INIT_C;
         dataV := (others => '0');
      end if;

      destRin     <= v;
      destDataRin <= dataV;

      destData <= destDataReg;
      destReq  <= destR.req;
   end process destComb;

   destSeq : process (destClk, destRst) is
   begin
      if (RST_ASYNC_G) and (destRst = RST_POLARITY_G) then
         destR       <= DEST_REG_INIT_C after TPD_G;
         destDataReg <= (others => '0') after TPD_G;
      elsif rising_edge(destClk) then
         destR       <= destRin     after TPD_G;
         destDataReg <= destDataRin after TPD_G;
      end if;
   end process destSeq;

end architecture rtl;
