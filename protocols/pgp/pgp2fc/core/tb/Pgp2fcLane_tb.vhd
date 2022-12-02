-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for PGP
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity Pgp2fcLane_tb is
   generic (
      TPD_G : time := 0 ns;
      VC_CHANNELS : integer := 1;
      FC_WORDS : integer := 1;
      FC_ENABLE : boolean := true;
      FC_INTERVAL : integer := 8;
      FC_START_VAL : integer := 1
   );
end Pgp2fcLane_tb;

-- Define architecture
architecture Pgp2fcLane_tb of Pgp2fcLane_tb is

   signal locClk            : sl;
   signal locClkRst         : sl;
   signal slowClk           : sl;
   signal slowClkRst        : sl;
   signal enable            : sl;
   signal txEnable          : slv(VC_CHANNELS-1  downto 0);
   signal txBusy            : slv(VC_CHANNELS-1  downto 0);
   signal txLength          : Slv32Array(VC_CHANNELS-1 downto 0);
   signal prbsTxMasters     : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal prbsTxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal iprbsTxMasters    : AxiStreamMasterArray(VC_CHANNELS-1 downto 0);
   signal iprbsTxSlaves     : AxiStreamSlaveArray(VC_CHANNELS-1 downto 0);
   signal lprbsTxMasters    : AxiStreamMasterArray(VC_CHANNELS-1 downto 0);
   signal lprbsTxSlaves     : AxiStreamSlaveArray(VC_CHANNELS-1 downto 0);
   signal prbsRxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsRxSlaves      : AxiStreamSlaveArray(VC_CHANNELS-1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);
   signal prbsRxCtrl        : AxiStreamCtrlArray(3 downto 0) := (others => AXI_STREAM_CTRL_INIT_C);
   signal iprbsRxMasters    : AxiStreamMasterArray(VC_CHANNELS-1 downto 0);
   signal iprbsRxSlaves     : AxiStreamSlaveArray(VC_CHANNELS-1 downto 0);
   signal iprbsRxCtrl       : AxiStreamCtrlArray(VC_CHANNELS-1 downto 0);
   signal updatedResults    : slv(VC_CHANNELS-1 downto 0);
   signal errMissedPacket   : slv(VC_CHANNELS-1 downto 0);
   signal errLength         : slv(VC_CHANNELS-1 downto 0);
   signal errEofe           : slv(VC_CHANNELS-1 downto 0);
   signal errDataBus        : slv(VC_CHANNELS-1 downto 0);
   signal errWordCnt        : Slv32Array(VC_CHANNELS-1 downto 0);
   signal packetRate        : Slv32Array(VC_CHANNELS-1 downto 0);
   signal packetLength      : Slv32Array(VC_CHANNELS-1 downto 0);
   signal phyTxLaneOut      : Pgp2fcTxPhyLaneOutType;
   signal phyRxLaneIn       : Pgp2fcRxPhyLaneInType;
   signal pgpTxIn           : Pgp2fcTxInType;
   signal pgpTxOut          : Pgp2fcTxOutType;
   signal pgpRxIn           : Pgp2fcRxInType;
   signal pgpRxOut          : Pgp2fcRxOutType;

   signal fcTxSend          : sl := '0';
   signal fcTxWord          : slv(FC_WORDS*16-1 downto 0) := (others => '0');
   signal fcRxRecv          : sl;
   signal fcRxWord          : slv(FC_WORDS*16-1 downto 0);

   signal fcInterval        : integer range 0 to FC_INTERVAL-1 := FC_START_VAL;
   signal fcCounter         : unsigned(FC_WORDS*16-1 downto 0) := (others => '0');

   constant RCEG3_AXIS_DMA_CONFIG_G : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 4,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

begin

   process begin
      locClk <= '1';
      wait for 2.5 ns;
      locClk <= '0';
      wait for 2.5 ns;
   end process;

   process begin
      locClkRst <= '1';
      wait for (50 ns);
      locClkRst <= '0';
      wait;
   end process;

   process begin
      slowClk <= '1';
      wait for 16 ns;
      slowClk <= '0';
      wait for 16 ns;
   end process;

   process begin
      slowClkRst <= '1';
      wait for (320 ns);
      slowClkRst <= '0';
      wait;
   end process;

   process begin
      enable <= '0';
      wait for (1 us);
      enable <= '1';
      wait;
   end process;

   process (locClk) begin
      if rising_edge(locClk) then
         fcTxSend <= '0';
         fcTxWord <= (others => '0');
         fcInterval <= FC_START_VAL;
         fcCounter <= fcCounter;

         if enable = '1' and FC_ENABLE = true then
            if fcInterval = FC_INTERVAL-1 then
               fcInterval <= 0;
            else
               fcInterval <= fcInterval + 1;
            end if;

            if fcInterval = 0 then
               fcTxSend <= '1';
               fcTxWord <= slv(fcCounter);
               fcCounter <= fcCounter + 1;
            end if;
         end if;
      end if;
   end process;

   U_TxGen: for i in 0 to VC_CHANNELS-1 generate

      process ( locClk ) begin
         if rising_edge(locClk) then
            if locClkRst = '1' then
               txEnable(i) <= '0' after TPD_G;

               case i is
                  when 0      => txLength(i) <= x"00000004" after TPD_G;
                  when 1      => txLength(i) <= x"00000800" after TPD_G;
                  when 2      => txLength(i) <= x"00000900" after TPD_G;
                  when 3      => txLength(i) <= x"00000A00" after TPD_G;
                  when others => txLength(i) <= x"00000001" after TPD_G;
               end case;
            else
               if txBusy(i) = '0' and enable = '1' and txEnable(i) = '0' then
                  txEnable(i) <= '1' after TPD_G;
               else
                  txEnable(i) <= '0' after TPD_G;
               end if;

               if txEnable(i) = '1' then
                  txLength(i) <= txLength(i) + 1 after TPD_G;
               end if;

            end if;
         end if;
      end process;

      U_SsiPrbsTx : entity surf.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_G,
            AXI_EN_G                   => '0',
            MEMORY_TYPE_G              => "block",
            GEN_SYNC_FIFO_G            => false,
            CASCADE_SIZE_G             => 1,
            PRBS_SEED_SIZE_G           => 32,
            PRBS_TAPS_G                => (0 => 16),
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 256,    -- Almost full at 1/2 capacity
            MASTER_AXI_STREAM_CONFIG_G => RCEG3_AXIS_DMA_CONFIG_G,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (

            mAxisClk     => locClk,
            mAxisRst     => locClkRst,
            mAxisSlave   => iprbsTxSlaves(i),
            mAxisMaster  => iprbsTxMasters(i),
            locClk       => locClk,
            locRst       => locClkRst,
            trig         => txEnable(i),
            packetLength => X"000000ff",
            tDest        => X"00",
            tId          => X"00",
--            packetLength => txLength(i),
--            tDest        => conv_std_logic_vector(i,8),
--            tId          => (others=>'0'),
            busy         => txBusy(i)
         );

         U_TxFifo : entity surf.AxiStreamFifoV2
            generic map (
               TPD_G               => TPD_G,
               PIPE_STAGES_G       => 1,
               SLAVE_READY_EN_G    => true,
               VALID_THOLD_G       => 1,
               MEMORY_TYPE_G       => "block",
               GEN_SYNC_FIFO_G     => false,
               CASCADE_SIZE_G      => 1,
               FIFO_ADDR_WIDTH_G   => 9,
               FIFO_FIXED_THRESH_G => true,
               FIFO_PAUSE_THRESH_G => 255,
               SLAVE_AXI_CONFIG_G  => RCEG3_AXIS_DMA_CONFIG_G,
               MASTER_AXI_CONFIG_G => PGP2FC_AXIS_CONFIG_C)
            port map (
               sAxisClk        => locClk,
               sAxisRst        => locClkRst,
               sAxisMaster     => iprbsTxMasters(i),
               sAxisSlave      => iprbsTxSlaves(i),
               sAxisCtrl       => open,
               fifoPauseThresh => (others => '1'),
               mAxisClk        => locClk,
               mAxisRst        => locClkRst,
               mAxisMaster     => lprbsTxMasters(i),
               mAxisSlave      => lprbsTxslaves(i));

   end generate;

   --prbsTxMasters(3 downto 1) <= (others=>AXI_STREAM_MASTER_INIT_C);

   U_PgpTxMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4
      ) port map (
         axisClk      => locClk,
         axisRst      => locClkRst,
         sAxisMaster  => lprbsTxMasters(0),
         sAxisSlave   => lprbsTxSlaves(0),
         mAxisMasters => prbsTxMasters,
         mAxisSlaves  => prbsTxSlaves
      );


   U_Pgp: entity surf.Pgp2fcLane
      generic map (
         TPD_G             => TPD_G,
         FC_WORDS_G        => FC_WORDS,
         VC_INTERLEAVE_G   => 0,
         PAYLOAD_CNT_TOP_G => 7,
         NUM_VC_EN_G       => VC_CHANNELS,
         TX_ENABLE_G       => true,
         RX_ENABLE_G       => true
      ) port map (
         pgpTxClk          => locClk,
         pgpTxClkRst       => locClkRst,
         fcTxSend          => fcTxSend,
         fcTxWord          => fcTxWord,
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => pgpTxOut,
         pgpTxMasters      => prbsTxMasters,
         pgpTxSlaves       => prbsTxSlaves,
         phyTxLaneOut      => phyTxLaneOut,
         phyTxReady        => '1',
         pgpRxClk          => locClk,
         pgpRxClkRst       => locClkRst,
         fcRxRecv          => fcRxRecv,
         fcRxWord          => fcRxWord,
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         pgpRxMasters      => prbsRxMasters,
         pgpRxMasterMuxed  => open,
         pgpRxCtrl         => prbsRxCtrl,
         phyRxLaneIn       => phyRxLaneIn,
         phyRxReady        => '1',
         phyRxInit         => open
      );


   phyRxLaneIn.data    <= phyTxLaneOut.data;
   phyRxLaneIn.dataK   <= phyTxLaneOut.dataK;
   phyRxLaneIn.dispErr <= (others=>'0');
   phyRxLaneIn.decErr  <= (others=>'0');


   pgpTxIn <= PGP2FC_TX_IN_INIT_C;
   pgpRxIn <= PGP2FC_RX_IN_INIT_C;


   --prbsRxSlaves(3 downto 1) <= (others=>AXI_STREAM_SLAVE_INIT_C);
   --prbsRxCtrl(3 downto 1)   <= (others=>AXI_STREAM_CTRL_INIT_C);


   -- PRBS receiver
   U_RxGen: for i in 0 to VC_CHANNELS-1 generate

      AxiStreamFifo_Rx : entity surf.AxiStreamFifoV2
         generic map(
            -- General Configurations
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => 0,
            -- FIFO configurations
            MEMORY_TYPE_G       => "block",
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 11,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 511,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => PGP2FC_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => PGP2FC_AXIS_CONFIG_C
         ) port map (
            -- Slave Port
            sAxisClk    => locClk,
            sAxisRst    => locClkRst,
            sAxisMaster => prbsRxMasters(i),
            sAxisSlave  => prbsRxSlaves(i),
            sAxisCtrl   => prbsRxCtrl(i),
            -- Master Port
            mAxisClk    => slowClk,
            mAxisRst    => slowClkRst,
            mAxisMaster => iprbsRxMasters(i),
            mAxisSlave  => iprbsRxSlaves(i));

      U_SsiPrbsRx: entity surf.SsiPrbsRx
         generic map (
            TPD_G                      => TPD_G,
            STATUS_CNT_WIDTH_G         => 32,
            CASCADE_SIZE_G             => 1,
            MEMORY_TYPE_G              => "block",
            GEN_SYNC_FIFO_G            => false,
            PRBS_SEED_SIZE_G           => 32,
            PRBS_TAPS_G                => (0 => 16),
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 256,    -- Almost full at 1/2 capacity
            SLAVE_AXI_STREAM_CONFIG_G  => PGP2FC_AXIS_CONFIG_C,
            SLAVE_AXI_PIPE_STAGES_G    => 0
         ) port map (
            sAxisClk        => slowClk,
            sAxisRst        => slowClkRst,
            sAxisMaster     => iprbsRxMasters(i),
            sAxisSlave      => iprbsRxSlaves(i),
            sAxisCtrl       => iprbsRxCtrl(i),
            mAxisMaster     => open,
            mAxisSlave      => AXI_STREAM_SLAVE_FORCE_C,
            axiClk          => '0',
            axiRst          => '0',
            axiReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
            axiReadSlave    => open,
            axiWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
            axiWriteSlave   => open,
            updatedResults  => updatedResults(i),
            busy            => open,
            errMissedPacket => errMissedPacket(i),
            errLength       => errLength(i),
            errDataBus      => errDataBus(i),
            errEofe         => errEofe(i),
            errWordCnt      => errWordCnt(i),
            packetRate      => packetRate(i),
            packetLength    => packetLength(i)
         );
   end generate;

end Pgp2fcLane_tb;

