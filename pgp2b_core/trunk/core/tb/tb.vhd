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

   signal ppiClk            : sl;
   signal ppiClkRst         : sl;
   signal pgpClk            : sl;
   signal pgpClkRst         : sl;
   signal updatedResults    : slv(3 downto 0);
   signal errMissedPacket   : slv(3 downto 0);
   signal errLength         : slv(3 downto 0);
   signal errEofe           : slv(3 downto 0);
   signal errWordCnt        : Slv32Array(3 downto 0);
   signal errbitCnt         : Slv32Array(3 downto 0);
   signal packetRate        : Slv32Array(3 downto 0);
   signal packetLength      : Slv32Array(3 downto 0);
   signal enable            : sl;
   signal txEnable          : slv(3  downto 0);
   signal txBusy            : slv(3  downto 0);
   signal txLength          : Slv32Array(3 downto 0);
   signal prbsTxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsTxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal prbsRxMasters     : AxiStreamMasterArray(3 downto 0);
   signal prbsRxSlaves      : AxiStreamSlaveArray(3 downto 0);
   signal pgpTxIn           : PgpTxInType;
   signal phyTxLanesOut     : PgpTxPhyLaneOutArray(0 to 0);
   signal pgpRxIn           : PgpRxInType;
   signal phyRxLanesIn      : PgpRxPhyLaneInArray(0 to  0);
   signal axiFifoStatus     : AxiStreamFifoStatusArray(3 downto 0);

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : 
      AxiLiteCrossbarMasterConfigArray(11 downto 0) := genAxiLiteConfig ( 12, x"F0000000", 4 );

begin

   process begin
      ppiClk <= '1';
      wait for 2.5 ns;
      ppiClk <= '0';
      wait for 2.5 ns;
   end process;

   process begin
      ppiClkRst <= '1';
      wait for (50 ns);
      ppiClkRst <= '0';
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

--      U_Vc64PrbsTx : entity work.Vc64PrbsTx
--         generic map (
--            TPD_G              => 1 ns,
--            RST_ASYNC_G        => false,
--            ALTERA_SYN_G       => false,
--            ALTERA_RAM_G       => "M9K",
--            XIL_DEVICE_G       => "7SERIES",  --Xilinx only generic parameter    
--            BRAM_EN_G          => true,
--            USE_BUILT_IN_G     => false,  --if set to true, this module is only Xilinx compatible only!!!
--            GEN_SYNC_FIFO_G    => false,
--            PIPE_STAGES_G      => 0,
--            FIFO_SYNC_STAGES_G => 3,
--            FIFO_ADDR_WIDTH_G  => 9,
--            FIFO_AFULL_THRES_G => 256     -- Almost full at 1/2 capacity
--         ) port map (
--            vcTxCtrl     => prbsTxCtrl(i), -- In
--            vcTxData     => prbsTxData(i), -- Out
--            vcTxClk      => pgpClk,
--            vcTxRst      => pgpClkRst,
--            trig         => txEnable(i),
--            packetLength => txLength(i),
--            busy         => txBusy(i),
--            locClk       => pgpClk,
--            locRst       => pgpClkRst 
--         );

   end generate;


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
         axiFifoStatus     => axiFifoStatus,
         pgpRxMasterMuxed  => open,
         phyRxLanesOut     => open,
         phyRxLanesIn      => phyRxLanesIn,
         phyRxReady        => '1',
         phyRxInit         => open
      );

   pgpTxIn                 <= PGP_TX_IN_INIT_C;
   pgpRxIn                 <= PGP_RX_IN_INIT_C;
   phyRxLanesIn(0).data    <= phyTxLanesOut(0).data;
   phyRxLanesIn(0).dataK   <= phyTxLanesOut(0).dataK;
   phyRxLanesIn(0).dispErr <= (others=>'0');
   phyRxLanesIn(0).decErr  <= (others=>'0');


   -- PRBS receiver
--   U_RxGen: for i in 0 to 3 generate 
--      U_Vc64PrbsRx: entity work.Vc64PrbsRx 
--         generic map (
--            TPD_G              => 1 ns,
--            LANE_NUMBER_G      => 0,
--            VC_NUMBER_G        => i,
--            RST_ASYNC_G        => false,
--            ALTERA_SYN_G       => false,
--            ALTERA_RAM_G       => "M9K",
--            XIL_DEVICE_G       => "7SERIES",  --Xilinx only generic parameter    
--            BRAM_EN_G          => true,
--            USE_BUILT_IN_G     => false,  --if set to true, this module is only Xilinx compatible only!!!
--            GEN_SYNC_FIFO_G    => false,
--            PIPE_STAGES_G      => 0,
--            FIFO_SYNC_STAGES_G => 3,
--            FIFO_ADDR_WIDTH_G  => 9,
--            FIFO_AFULL_THRES_G => 256     -- Almost full at 1/2 capacity
--         ) port map (
--            vcRxData             => prbsRxData(i),
--            vcRxCtrl             => prbsRxCtrl(i),
--            vcRxClk              => pgpClk,
--            vcRxRst              => pgpClkRst,
--            vcTxCtrl             => VC64_CTRL_FORCE_C,
--            vcTxData             => open,
--            vcTxClk              => pgpClk,
--            vcTxRst              => pgpClkRst,
--            updatedResults       => updatedResults(i),
--            busy                 => open,
--            errMissedPacket      => errMissedPacket(i),
--            errLength            => errLength(i),
--            errEofe              => errEofe(i),
--            errWordCnt           => errWordCnt(i),
--            errbitCnt            => errbitCnt(i),
--            packetRate           => packetRate(i),
--            packetLength         => packetLength(i)
--         ); 
--   end generate;

end tb;

