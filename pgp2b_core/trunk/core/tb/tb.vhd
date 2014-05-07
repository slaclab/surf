LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity tb is end tb;

-- Define architecture
architecture tb of tb is

   signal locClk            : sl;
   signal locClkRst         : sl;
   signal pgpClk            : sl;
   signal pgpClkRst         : sl;
   signal updatedResults    : slv(3 downto 0);
   signal errMissedPacket   : slv(3 downto 0);
   signal errLength         : slv(3 downto 0);
   signal errEofe           : slv(3 downto 0);
   signal errDataBus        : slv(3 downto 0);
   signal errWordCnt        : Slv32Array(3 downto 0);
   signal errbitCnt         : Slv32Array(3 downto 0);
   signal packetRate        : Slv32Array(3 downto 0);
   signal packetLength      : Slv32Array(3 downto 0);
   signal enable            : sl;
   signal txEnable          : slv(3  downto 0);
   signal txBusy            : slv(3  downto 0);
   signal txLength          : Slv32Array(3 downto 0);
   signal iprbsTxMasters    : AxiStreamMasterArray(3 downto 0);
   signal prbsTxMasters     : AxiStreamMasterArray(3 downto 0);
   signal iprbsTxSlaves     : AxiStreamSlaveArray(3 downto 0);
   signal prbsTxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal prbsRxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsRxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal pgpTxIn           : Pgp2bTxInType;
   signal phyTxLanesOut     : Pgp2bTxPhyLaneOutArray(0 to 0);
   signal pgpRxIn           : Pgp2bRxInType;
   signal phyRxLanesIn      : Pgp2bRxPhyLaneInArray(0 to  0);
   signal pgpRxCtrl         : AxiStreamCtrlArray(3 downto 0);
   signal ipgpRxCtrl        : AxiStreamCtrlArray(3 downto 0);

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : 
      AxiLiteCrossbarMasterConfigArray(11 downto 0) := genAxiLiteConfig ( 12, x"F0000000", 4 );

   --constant INT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig (4);
   constant INT_CONFIG_C : AxiStreamConfigType := SSI_PGP2B_CONFIG_C;

begin

   process begin
      locClk <= '1';
      wait for 2.5 ns;
      locClk <= '0';
      wait for 2.5 ns;
   end process;

--   process begin
--      locClk <= '1';
--      wait for 5.0 ns;
--      locClk <= '0';
--      wait for 5.0 ns;
--   end process;

   process begin
      locClkRst <= '1';
      wait for (50 ns);
      locClkRst <= '0';
      wait;
   end process;

   process begin
      pgpClk <= '1';
      wait for 5 ns;
      pgpClk <= '0';
      wait for 5 ns;
   end process;

   process begin
      pgpClkRst <= '1';
      wait for (50 ns);
      pgpClkRst <= '0';
      wait;
   end process;

   process begin
      enable <= '0';
      wait for (1 us);
      enable <= '1';
      wait;
   end process;

   U_TxGen: for i in 0 to 3 generate 

      process ( pgpClk ) begin
         if rising_edge(pgpClk) then
            if pgpClkRst = '1' then
               txEnable(i) <= '0' after 1 ns;

               case i is 
                  when 0      => txLength(i) <= x"00000700" after 1 ns;
                  when 1      => txLength(i) <= x"00000800" after 1 ns;
                  when 2      => txLength(i) <= x"00000900" after 1 ns;
                  when 3      => txLength(i) <= x"00000A00" after 1 ns;
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
            MASTER_AXI_STREAM_CONFIG_G => INT_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (

            mAxisClk     => pgpClk,
            mAxisRst     => pgpClkRst,
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
   end generate;

   iprbsTxSlaves(0)          <= prbsTxSlaves(0);
   iprbsTxSlaves(3 downto 1) <= (others=>AXI_STREAM_SLAVE_INIT_C);
   --iprbsTxSlaves(3 downto 1) <= prbsTxSlaves(3 downto 1);

   prbsTxMasters(0)          <= iprbsTxMasters(0);
   prbsTxMasters(3 downto 1) <= (others=>AXI_STREAM_MASTER_INIT_C);
   --prbsTxMasters(3 downto 1) <= iprbsTxMasters(3 downto 1);

   U_PgpSim : entity work.Pgp2bLane 
      generic map (
         TPD_G             => 1 ns,
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => 1,
         PAYLOAD_CNT_TOP_G => 7,
         NUM_VC_EN_G       => 4
      ) port map ( 
         pgpTxClk          => pgpClk,
         pgpTxClkRst       => pgpClkRst,
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => open,
         pgpTxMasters      => prbsTxMasters,
         pgpTxSlaves       => prbsTxSlaves,
         phyTxLanesOut     => phyTxLanesOut,
         phyTxReady        => '1',
         pgpRxClk          => pgpClk,
         pgpRxClkRst       => pgpClkRst,
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => open,
         pgpRxMasters      => prbsRxMasters,
         pgpRxCtrl         => pgpRxCtrl,
         pgpRxMasterMuxed  => open,
         phyRxLanesOut     => open,
         phyRxLanesIn      => phyRxLanesIn,
         phyRxReady        => '1',
         phyRxInit         => open
      );

   pgpTxIn                 <= PGP2B_TX_IN_INIT_C;
   pgpRxIn                 <= PGP2B_RX_IN_INIT_C;
   phyRxLanesIn(0).data    <= phyTxLanesOut(0).data;
   phyRxLanesIn(0).dataK   <= phyTxLanesOut(0).dataK;
   phyRxLanesIn(0).dispErr <= (others=>'0');
   phyRxLanesIn(0).decErr  <= (others=>'0');

   pgpRxCtrl(0)          <= ipgpRxCtrl(0);
   pgpRxCtrl(3 downto 1) <= (others=>AXI_STREAM_CTRL_UNUSED_C);
   --pgpRxCtrl(3 downto 1) <= (others=>AXI_STREAM_CTRL_INIT_C);
   --pgpRxCtrl(3 downto 1) <= ipgpRxCtrl(3 downto 1);


   -- PRBS receiver
   U_RxGen: for i in 0 to 3 generate 
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
            SLAVE_AXI_STREAM_CONFIG_G  => INT_CONFIG_C,
            SLAVE_AXI_PIPE_STAGES_G    => 0,
            MASTER_AXI_STREAM_CONFIG_G => INT_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (
            sAxisClk        => pgpClk,
            sAxisRst        => pgpClkRst,
            sAxisMaster     => prbsRxMasters(i),
            sAxisSlave      => open,
            sAxisCtrl       => ipgpRxCtrl(i),
            mAxisClk        => pgpClk,
            mAxisRst        => pgpClkRst,
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

end tb;

