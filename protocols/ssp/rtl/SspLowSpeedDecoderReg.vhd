-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:  SSP Decoder Registers
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
use surf.AxiLitePkg.all;

entity SspLowSpeedDecoderReg is
   generic (
      TPD_G        : time     := 1 ns;
      SIMULATION_G : boolean  := false;
      DATA_WIDTH_G : positive := 10;
      NUM_LANE_G   : positive := 1);
   port (
      -- Deserialization Interface (deserClk domain)
      deserClk        : in  sl;
      deserRst        : in  sl;
      dlyConfig       : in  Slv9Array(NUM_LANE_G-1 downto 0);
      errorDet        : in  slv(NUM_LANE_G-1 downto 0);
      bitSlip         : in  slv(NUM_LANE_G-1 downto 0);
      eyeWidth        : in  Slv9Array(NUM_LANE_G-1 downto 0);
      locked          : in  slv(NUM_LANE_G-1 downto 0);
      idleCode        : in  slv(NUM_LANE_G-1 downto 0);
      enUsrDlyCfg     : out sl;
      usrDlyCfg       : out Slv9Array(NUM_LANE_G-1 downto 0);
      minEyeWidth     : out slv(7 downto 0);
      lockingCntCfg   : out slv(23 downto 0);
      bypFirstBerDet  : out sl;
      polarity        : out slv(NUM_LANE_G-1 downto 0);
      bitOrder        : out slv(1 downto 0);
      errorMask       : out slv(2 downto 0);
      lockOnIdle      : out sl;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SspLowSpeedDecoderReg;

architecture mapping of SspLowSpeedDecoderReg is

   constant STATUS_SIZE_C  : positive := 3*NUM_LANE_G;
   constant STATUS_WIDTH_C : positive := 16;

   type RegType is record
      enUsrDlyCfg    : sl;
      usrDlyCfg      : Slv9Array(NUM_LANE_G-1 downto 0);
      minEyeWidth    : slv(7 downto 0);
      lockingCntCfg  : slv(23 downto 0);
      bypFirstBerDet : sl;
      polarity       : slv(NUM_LANE_G-1 downto 0);
      bitOrder       : slv(1 downto 0);
      errorMask      : slv(2 downto 0);
      lockOnIdle     : sl;
      cntRst         : sl;
      rollOverEn     : slv(STATUS_SIZE_C-1 downto 0);
      readSlave      : AxiLiteReadSlaveType;
      writeSlave     : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      enUsrDlyCfg    => ite(SIMULATION_G, '1', '0'),
      usrDlyCfg      => (others => toSlv(219, 9)),
      minEyeWidth    => toSlv(80, 8),
      lockingCntCfg  => ite(SIMULATION_G, x"00_0004", x"00_FFFF"),
      bypFirstBerDet => '1',
      polarity       => (others => '0'),
      bitOrder       => (others => '0'),
      errorMask      => (others => '0'),
      lockOnIdle     => '0',
      cntRst         => '1',
      rollOverEn     => (others => '0'),
      readSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave     => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusIn  : slv(STATUS_SIZE_C-1 downto 0);
   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);
   signal statusCnt : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_WIDTH_C-1 downto 0);

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;

begin

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         NUM_ADDR_BITS_G => 12)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => deserClk,
         mAxiClkRst      => deserRst,
         mAxiReadMaster  => readMaster,
         mAxiReadSlave   => readSlave,
         mAxiWriteMaster => writeMaster,
         mAxiWriteSlave  => writeSlave);

   comb : process (deserRst, dlyConfig, eyeWidth, idleCode, r, readMaster,
                   statusCnt, statusOut, writeMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.cntRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, writeMaster, readMaster, v.writeSlave, v.readSlave);

      -- Map the read registers
      for i in STATUS_SIZE_C-1 downto 0 loop
         axiSlaveRegisterR(axilEp, toSlv((4*i), 12), 0, muxSlVectorArray(statusCnt, i));
      end loop;
      axiSlaveRegisterR(axilEp, x"400", 0, statusOut);

      for i in NUM_LANE_G-1 downto 0 loop

         -- Address starts at 0x200
         axiSlaveRegisterR(axilEp, toSlv(512+4*i, 12), 0, eyeWidth(i));

         -- Address starts at 0x500
         axiSlaveRegister (axilEp, toSlv(1280+4*i, 12), 0, v.usrDlyCfg(i));

         -- Address starts at 0x600
         axiSlaveRegisterR(axilEp, toSlv(1536+4*i, 12), 0, dlyConfig(i));

      end loop;

      axiSlaveRegisterR(axilEp, x"7FC", 0, toSlv(DATA_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"7FC", 8, toSlv(NUM_LANE_G, 8));

      axiSlaveRegister (axilEp, x"800", 0, v.enUsrDlyCfg);
      -- axiSlaveRegister (axilEp, x"804", 0, v.usrDlyCfg); -- Changed from "common" to 1 per lane
      axiSlaveRegister (axilEp, x"808", 0, v.minEyeWidth);
      axiSlaveRegister (axilEp, x"80C", 0, v.lockingCntCfg);

      axiSlaveRegister (axilEp, x"810", 0, v.bypFirstBerDet);
      axiSlaveRegister (axilEp, x"814", 0, v.polarity);
      axiSlaveRegister (axilEp, x"818", 0, v.bitOrder);
      axiSlaveRegister (axilEp, x"81C", 0, v.errorMask);


      axiSlaveRegisterR(axilEp, x"900", 0, idleCode);
      axiSlaveRegister (axilEp, x"904", 0, v.lockOnIdle);

      axiSlaveRegister (axilEp, x"FF8", 0, v.rollOverEn);
      axiSlaveRegister (axilEp, x"FFC", 0, v.cntRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      -- Outputs
      writeSlave     <= r.writeSlave;
      readSlave      <= r.readSlave;
      enUsrDlyCfg    <= r.enUsrDlyCfg;
      usrDlyCfg      <= r.usrDlyCfg;
      minEyeWidth    <= r.minEyeWidth;
      lockingCntCfg  <= r.lockingCntCfg;
      bypFirstBerDet <= r.bypFirstBerDet;
      polarity       <= r.polarity;
      bitOrder       <= r.bitOrder;
      errorMask      <= r.errorMask;
      lockOnIdle     <= r.lockOnIdle;

      -- Synchronous Reset
      if (deserRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (deserClk) is
   begin
      if (rising_edge(deserClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SyncStatusVector : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => true,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => STATUS_WIDTH_C,
         WIDTH_G        => STATUS_SIZE_C)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn     => statusIn,
         -- Output Status bit Signals (rdClk domain)
         statusOut    => statusOut,
         -- Status Bit Counters Signals (rdClk domain)
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => statusCnt,
         -- Clocks and Reset Ports
         wrClk        => deserClk,
         rdClk        => deserClk);

   statusIn((2*NUM_LANE_G)+NUM_LANE_G-1 downto 2*NUM_LANE_G) <= errorDet;
   statusIn((1*NUM_LANE_G)+NUM_LANE_G-1 downto 1*NUM_LANE_G) <= bitSlip;
   statusIn((0*NUM_LANE_G)+NUM_LANE_G-1 downto 0*NUM_LANE_G) <= locked;

end mapping;
