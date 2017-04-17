-------------------------------------------------------------------------------
-- File       : pgp_test.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
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

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;

entity pgp_test is end pgp_test;

-- Define architecture
architecture pgp_test of pgp_test is

   signal locClk            : sl;
   signal locClkRst         : sl;
   signal slowClk           : sl;
   signal slowClkRst        : sl;
   signal enable            : sl;
   signal txEnable          : slv(3  downto 0);
   signal txBusy            : slv(3  downto 0);
   signal txLength          : Slv32Array(3 downto 0);
   signal prbsTxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsTxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal iprbsTxMasters    : AxiStreamMasterArray(3 downto 0);
   signal iprbsTxSlaves     : AxiStreamSlaveArray(3 downto 0);
   signal lprbsTxMasters    : AxiStreamMasterArray(3 downto 0);
   signal lprbsTxSlaves     : AxiStreamSlaveArray(3 downto 0);
   signal prbsRxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsRxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal prbsRxCtrl        : AxiStreamCtrlArray(3 downto 0);
   signal iprbsRxMasters    : AxiStreamMasterArray(3 downto 0);
   signal iprbsRxSlaves     : AxiStreamSlaveArray(3 downto 0);
   signal iprbsRxCtrl       : AxiStreamCtrlArray(3 downto 0);
   signal updatedResults    : slv(0 downto 0);
   signal errMissedPacket   : slv(0 downto 0);
   signal errLength         : slv(0 downto 0);
   signal errEofe           : slv(0 downto 0);
   signal errDataBus        : slv(0 downto 0);
   signal errWordCnt        : Slv32Array(0 downto 0);
   signal errbitCnt         : Slv32Array(0 downto 0);
   signal packetRate        : Slv32Array(0 downto 0);
   signal packetLength      : Slv32Array(0 downto 0);
   signal phyTxLanesOut     : Pgp2bTxPhyLaneOutArray(0 to 0);
   signal phyRxLanesOut     : Pgp2bRxPhyLaneOutArray(0 to 0);
   signal phyRxLanesIn      : Pgp2bRxPhyLaneInArray(0 to 0);
   signal pgpTxIn           : Pgp2bTxInType;
   signal pgpTxOut          : Pgp2bTxOutType;
   signal pgpRxIn           : Pgp2bRxInType;
   signal pgpRxOut          : Pgp2bRxOutType;

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

   U_TxGen: for i in 0 to 0 generate 

      process ( locClk ) begin
         if rising_edge(locClk) then
            if locClkRst = '1' then
               txEnable(i) <= '0' after 1 ns;

               case i is 
                  when 0      => txLength(i) <= x"00000004" after 1 ns;
                  --when 1      => txLength(i) <= x"00000800" after 1 ns;
                  --when 2      => txLength(i) <= x"00000900" after 1 ns;
                  --when 3      => txLength(i) <= x"00000A00" after 1 ns;
                  when others => txLength(i) <= x"00000001" after 1 ns;
               end case;
            else
               if txBusy(i) = '0' and enable = '1' and txEnable(i) = '0' then
                  txEnable(i) <= '1' after 1 ns;
               else
                  txEnable(i) <= '0' after 1 ns;
               end if;

               if txEnable(i) = '1' then
                  txLength(i) <= txLength(i) + 1 after 1 ns;
               end if;

            end if;
         end if;
      end process;

      U_SsiPrbsTx : entity work.SsiPrbsTx
         generic map (
            TPD_G                      => 1 ns,
            ALTERA_SYN_G               => false,
            ALTERA_RAM_G               => "M9K",
            XIL_DEVICE_G               => "7SERIES",  --Xilinx only generic parameter    
            BRAM_EN_G                  => true,
            USE_BUILT_IN_G             => false,  --if set to true, this module is only Xilinx compatible only!!!
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
            packetLength => txLength(i),
            busy         => txBusy(i),
            tDest        => conv_std_logic_vector(i,8),
            tId          => (others=>'0')
         );

         U_TxFifo : entity work.AxiStreamFifo
            generic map (
               TPD_G               => 1 ns,
               PIPE_STAGES_G       => 1,
               SLAVE_READY_EN_G    => true,
               VALID_THOLD_G       => 1,
               BRAM_EN_G           => true,
               XIL_DEVICE_G        => "7SERIES",
               USE_BUILT_IN_G      => false,
               GEN_SYNC_FIFO_G     => false,
               ALTERA_SYN_G        => false,
               ALTERA_RAM_G        => "M9K",
               CASCADE_SIZE_G      => 1,
               FIFO_ADDR_WIDTH_G   => 9,
               FIFO_FIXED_THRESH_G => true,
               FIFO_PAUSE_THRESH_G => 255,
               SLAVE_AXI_CONFIG_G  => RCEG3_AXIS_DMA_CONFIG_G,
               MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
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

   U_PgpTxMux : entity work.AxiStreamDeMux 
      generic map (
         TPD_G         => 1 ns,
         NUM_MASTERS_G => 4
      ) port map (
         axisClk      => locClk,
         axisRst      => locClkRst,
         sAxisMaster  => lprbsTxMasters(0),
         sAxisSlave   => lprbsTxSlaves(0),
         mAxisMasters => prbsTxMasters,
         mAxisSlaves  => prbsTxSlaves
      );


   U_Pgp: entity work.Pgp2bLane 
      generic map (
         TPD_G             => 1 ns,
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => 0,
         PAYLOAD_CNT_TOP_G => 7,
         NUM_VC_EN_G       => 4,
         TX_ENABLE_G       => true,
         RX_ENABLE_G       => true
      ) port map ( 
         pgpTxClk          => locClk,
         pgpTxClkRst       => locClkRst,
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => pgpTxOut,
         pgpTxMasters      => prbsTxMasters,
         pgpTxSlaves       => prbsTxSlaves,
         phyTxLanesOut     => phyTxLanesOut,
         phyTxReady        => '1',
         pgpRxClk          => locClk,
         pgpRxClkRst       => locClkRst,
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         pgpRxMasters      => prbsRxMasters,
         pgpRxMasterMuxed  => open,
         pgpRxCtrl         => prbsRxCtrl,
         phyRxLanesOut     => phyRxLanesOut,
         phyRxLanesIn      => phyRxLanesIn,
         phyRxReady        => '1',
         phyRxInit         => open
      );


   phyRxLanesIn(0).data    <= phyTxLanesOut(0).data;
   phyRxLanesIn(0).dataK   <= phyTxLanesOut(0).dataK;
   phyRxLanesIn(0).dispErr <= (others=>'0');
   phyRxLanesIn(0).decErr  <= (others=>'0');


   pgpTxIn <= PGP2B_TX_IN_INIT_C;
   pgpRxIn <= PGP2B_RX_IN_INIT_C;


   prbsRxSlaves(3 downto 1) <= (others=>AXI_STREAM_SLAVE_INIT_C);
   prbsRxCtrl(3 downto 1)   <= (others=>AXI_STREAM_CTRL_INIT_C);


   -- PRBS receiver
   U_RxGen: for i in 0 to 0 generate 

      AxiStreamFifo_Rx : entity work.AxiStreamFifo
         generic map(
            -- General Configurations
            TPD_G               => 1 ns,
            PIPE_STAGES_G       => 0,
            -- FIFO configurations
            BRAM_EN_G           => true,
            XIL_DEVICE_G        => "7SERIES",
            USE_BUILT_IN_G      => false,
            GEN_SYNC_FIFO_G     => false,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 11,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 511,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
            MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C
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

      U_SsiPrbsRx: entity work.SsiPrbsRx 
         generic map (
            TPD_G                      => 1 ns,
            STATUS_CNT_WIDTH_G         => 32,
            AXI_ERROR_RESP_G           => AXI_RESP_SLVERR_C,
            ALTERA_SYN_G               => false,
            ALTERA_RAM_G               => "M9K",
            CASCADE_SIZE_G             => 1,
            XIL_DEVICE_G               => "7SERIES",  --Xilinx only generic parameter    
            BRAM_EN_G                  => true,
            USE_BUILT_IN_G             => false,  --if set to true, this module is only Xilinx compatible only!!!
            GEN_SYNC_FIFO_G            => false,
            PRBS_SEED_SIZE_G           => 32,
            PRBS_TAPS_G                => (0 => 16),
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 256,    -- Almost full at 1/2 capacity
            SLAVE_AXI_STREAM_CONFIG_G  => SSI_PGP2B_CONFIG_C,
            SLAVE_AXI_PIPE_STAGES_G    => 0,
            MASTER_AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (
            sAxisClk        => slowClk,
            sAxisRst        => slowClkRst,
            sAxisMaster     => iprbsRxMasters(i),
            sAxisSlave      => iprbsRxSlaves(i),
            sAxisCtrl       => iprbsRxCtrl(i),
            mAxisClk        => slowClk,
            mAxisRst        => slowClkRst,
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
            errbitCnt       => errbitCnt(i),
            packetRate      => packetRate(i),
            packetLength    => packetLength(i)
         ); 
   end generate;

end pgp_test;

