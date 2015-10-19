LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity eth_mac_test is 
end eth_mac_test;

-- Define architecture
architecture eth_mac_test of eth_mac_test is

   signal ethClk            : sl;
   signal ethClkRst         : sl;
   signal txEnable          : slv(1  downto 0);
   signal txBusy            : slv(1  downto 0);
   signal txLength          : Slv32Array(1 downto 0);
   signal prbsTxMasters     : AxiStreamMasterArray(1 downto 0);
   signal prbsTxSlaves      : AxiStreamSlaveArray(1 downto 0);
   signal iprbsTxMasters    : AxiStreamMasterArray(1 downto 0);
   signal iprbsTxSlaves     : AxiStreamSlaveArray(1 downto 0);
   signal prbsRxMasters     : AxiStreamMasterArray(1 downto 0);
   signal prbsRxCtrl        : AxiStreamCtrlArray(1 downto 0);
   signal updatedResults    : slv(1 downto 0);
   signal errMissedPacket   : slv(1 downto 0);
   signal errLength         : slv(1 downto 0);
   signal errEofe           : slv(1 downto 0);
   signal errDataBus        : slv(1 downto 0);
   signal errWordCnt        : Slv32Array(1 downto 0);
   signal errbitCnt         : Slv32Array(1 downto 0);
   signal packetRate        : Slv32Array(1 downto 0);
   signal packetLength      : Slv32Array(1 downto 0);
   signal phyTxd            : slv(63 downto 0);
   signal phyTxc            : slv(7  downto 0);
   signal phyRxd            : slv(63 downto 0);
   signal phyRxc            : slv(7  downto 0);
   signal phyReady          : sl;
   signal ethConfig         : EthMacConfigArray(1 downto 0);
   signal ethStatus         : EthMacStatusArray(1 downto 0);

begin

   process begin
      ethClk <= '1';
      wait for 6.4 ns;
      ethClk <= '0';
      wait for 6.4 ns;
   end process;

   process begin
      ethClkRst <= '1';
      wait for (50 ns);
      ethClkRst <= '0';
      wait;
   end process;

   U_TestGen: for i in 0 to 1 generate 

      process ( ethClk ) begin
         if rising_edge(ethClk) then
            if ethClkRst = '1' then
               txEnable(i) <= '0' after 1 ns;

               case i is 
                  when 0      => txLength(i) <= x"00000010" after 1 ns;
                  when 1      => txLength(i) <= x"00000010" after 1 ns;
                  when others => txLength(i) <= x"00000000" after 1 ns;
               end case;
            else
               if txBusy(i) = '0' and txEnable(i) = '0' then
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
            GEN_SYNC_FIFO_G            => true,
            CASCADE_SIZE_G             => 1,
            PRBS_SEED_SIZE_G           => 32,
            PRBS_TAPS_G                => (0 => 16),
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 256,    -- Almost full at 1/2 capacity
            MASTER_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (

            mAxisClk     => ethClk,
            mAxisRst     => ethClkRst,
            mAxisSlave   => iprbsTxSlaves(i),
            mAxisMaster  => iprbsTxMasters(i),
            locClk       => ethClk,
            locRst       => ethClkRst,
            trig         => txEnable(i),
            packetLength => txLength(i),
            busy         => txBusy(i),
            tDest        => x"00",
            tId          => (others=>'0')
         );

      U_TxFifo: entity work.AxiStreamFifo
         generic map (
            TPD_G               => 1 ns,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 0,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 0,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 255,
            SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C
         ) port map (
            sAxisClk    => ethClk,
            sAxisRst    => ethClkRst,
            sAxisMaster => iprbsTxMasters(i),
            sAxisSlave  => iprbsTxSlaves(i),
            sAxisCtrl   => open,
            mAxisClk    => ethClk,
            mAxisRst    => ethClkRst,
            mAxisMaster => prbsTxMasters(i),
            mAxisSlave  => prbsTxSlaves(i)
         );

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
            GEN_SYNC_FIFO_G            => true,
            PRBS_SEED_SIZE_G           => 32,
            PRBS_TAPS_G                => (0 => 16),
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 256,    -- Almost full at 1/2 capacity
            SLAVE_AXI_STREAM_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            SLAVE_AXI_PIPE_STAGES_G    => 0,
            MASTER_AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 0
         ) port map (
            sAxisClk        => ethClk,
            sAxisRst        => ethClkRst,
            sAxisMaster     => prbsRxMasters(i),
            sAxisSlave      => open,
            sAxisCtrl       => prbsRxCtrl(i),
            mAxisClk        => ethClk,
            mAxisRst        => ethClkRst,
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

   phyReady <= '1';

   U_EthMac0: entity work.EthMacTop
      generic map (
         TPD_G           => 1 ns,
         PAUSE_512BITS_G => 8
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => prbsTxMasters(0),
         sAxisSlave   => prbsTxSlaves(0),
         mAxisMaster  => prbsRxMasters(0),
         mAxisCtrl    => prbsRxCtrl(0),
         phyTxd       => phyTxd,
         phyTxc       => phyTxc,
         phyRxd       => phyRxd,
         phyRxc       => phyRxc,
         phyReady     => phyReady,
         ethConfig    => ethConfig(0),
         ethStatus    => ethStatus(0)
      );


   U_EthMac1: entity work.EthMacTop
      generic map (
         TPD_G           => 1 ns,
         PAUSE_512BITS_G => 8
      ) port map ( 
         ethClk       => ethClk,
         ethClkRst    => ethClkRst,
         sAxisMaster  => prbsTxMasters(1),
         sAxisSlave   => prbsTxSlaves(1),
         mAxisMaster  => prbsRxMasters(1),
         mAxisCtrl    => prbsRxCtrl(1),
         phyTxd       => phyRxd,
         phyTxc       => phyRxc,
         phyRxd       => phyTxd,
         phyRxc       => phyTxc,
         phyReady     => phyReady,
         ethConfig    => ethConfig(1),
         ethStatus    => ethStatus(1)
      );

   -- Configuration of MACs
   ethConfig(0).macAddress    <= x"001122334455";
   ethConfig(0).filtEnable    <= '0';
   ethConfig(0).pauseEnable   <= '1';
   ethConfig(0).pauseTime     <= x"0010";
   ethConfig(0).interFrameGap <= x"F";

   ethConfig(1).macAddress    <= x"66778899aabb";
   ethConfig(1).filtEnable    <= '0';
   ethConfig(1).pauseEnable   <= '0';
   ethConfig(1).pauseTime     <= x"0010";
   ethConfig(1).interFrameGap <= x"F";

end eth_mac_test;

