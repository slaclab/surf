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

   signal axiClk      : sl;
   signal axiClkRst   : sl;
   signal sAxisMaster : AxiStreamMasterType;
   signal sAxisSlave  : AxiStreamSlaveType;
   signal sAxisCtrl   : AxiStreamCtrlType;
   signal mAxisMaster : AxiStreamMasterType;
   signal mAxisSlave  : AxiStreamSlaveType;
   signal axiCount    : slv(7 downto 0);

   constant SLAVE_AXI_CONFIG_C  : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_NORMAL_C
   );

   constant MASTER_AXI_CONFIG_C : AxiStreamConfigTYpe := ssiAxiStreamConfig (2);

begin

   process begin
      axiClk <= '1';
      wait for 8 ns;
      axiClk <= '0';
      wait for 8 ns;
   end process;

   process begin
      axiClkRst <= '1';
      wait for (80 ns);
      axiClkRst <= '0';
      wait;
   end process;


   process (axiClk ) begin
      if rising_edge (axiClk ) then
         if axiClkRst = '1' then
            axiCount <= (others=>'0') after 1 ns;
         elsif sAxisSlave.tReady = '1' then
            axiCount <= axiCount + 1 after 1 ns;
         end if;
      end if;
   end process;


   process ( sAxisSlave, axiCount, axiClkRst ) begin
      sAxisMaster <= AXI_STREAM_MASTER_INIT_C;

      sAxisMaster.tValid <= not axiClkRst;

      sAxisMaster.tDest <= x"de";
      sAxisMaster.tId   <= x"ad";

      for i in 0 to 15 loop
         sAxisMaster.tData(i*8+7 downto i*8) <= conv_std_logic_vector((conv_integer(axiCount(7 downto 0)) * i),8);
         sAxisMaster.tStrb(i) <= '1';
         sAxisMaster.tKeep(i) <= '1';
         sAxisMaster.tUser(i*4+3 downto i*4) <= conv_std_logic_vector(i,4);
      end loop;

      if axiCount(3 downto 0) = 15 then
         sAxisMaster.tLast <= '1';
         sAxisMaster.tKeep(15 downto 15) <= (others=>'0');
      else
         sAxisMaster.tLast <= '0';
      end if;
   end process;

   mAxisSlave.tReady <= '1';


   U_FIfo : entity work.AxiStreamFifo 
      generic map (
         TPD_G               => 1 ns,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
      ) port map (
         sAxisClk        => axiClk,
         sAxisRst        => axiClkRst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         fifoPauseThresh => (others => '1'),
         mAxisClk        => axiClk,
         mAxisRst        => axiClkRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave
      );

end fifo_tb;

