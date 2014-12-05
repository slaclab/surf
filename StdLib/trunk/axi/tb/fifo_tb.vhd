LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp2bPkg.all;

entity fifo_tb is end fifo_tb;

-- Define architecture
architecture fifo_tb of fifo_tb is

   signal saxiClk     : sl;
   signal saxiClkRst  : sl;
   signal maxiClk     : sl;
   signal maxiClkRst  : sl;
   signal sAxisMaster : AxiStreamMasterType;
   signal sAxisSlave  : AxiStreamSlaveType;
   signal sAxisCtrl   : AxiStreamCtrlType;
   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;
   signal axiCount    : slv(7 downto 0);

   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

   constant SLAVE_AXI_CONFIG_C  : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

begin

   process begin
      maxiClk <= '1';
      wait for 2.5 ns;
      maxiClk <= '0';
      wait for 2.5 ns;
   end process;

   process begin
      maxiClkRst <= '1';
      wait for (80 ns);
      maxiClkRst <= '0';
      wait;
   end process;

   process begin
      saxiClk <= '1';
      wait for 4 ns;
      saxiClk <= '0';
      wait for 4 ns;
   end process;

   process begin
      saxiClkRst <= '1';
      wait for (80 ns);
      saxiClkRst <= '0';
      wait;
   end process;

   process (saxiClk ) begin
      if rising_edge (saxiClk ) then
         if saxiClkRst = '1' then
            axiCount <= (others=>'0') after 1 ns;
         elsif sAxisSlave.tReady = '1' then
            axiCount <= axiCount + 1 after 1 ns;
         end if;
      end if;
   end process;


   process ( sAxisSlave, axiCount, saxiClkRst ) begin
      sAxisMaster <= AXI_STREAM_MASTER_INIT_C;

      sAxisMaster.tDest <= x"de";
      sAxisMaster.tId   <= x"ad";

      if axiCount(4 downto 0) = 8 then
         sAxisMaster.tValid <= '1';
         sAxisMaster.tLast <= '0';
         sAxisMaster.tKeep(15 downto 0) <= x"00FF";
         sAxisMaster.tData <= x"16151413121110090807060504030201";
      elsif axiCount(4 downto 0) = 15 then
         sAxisMaster.tValid <= '1';
         sAxisMaster.tLast <= '1';
         sAxisMaster.tData <= x"36353433323130292827262524232221";
         sAxisMaster.tKeep(15 downto 0) <= x"000F";
      else
         sAxisMaster.tLast <= '0';
         sAxisMaster.tValid <= '0';
      end if;
   end process;

   mAxisSlave.tReady <= '1';


   U_FIfo : entity work.AxiStreamFifo 
      generic map (
         TPD_G               => 1 ns,
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
      ) port map (
         sAxisClk        => saxiClk,
         sAxisRst        => saxiClkRst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         fifoPauseThresh => (others => '1'),
         mAxisClk        => maxiClk,
         mAxisRst        => maxiClkRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave
      );

end fifo_tb;

