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
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.I2cPkg.all;

entity stream_tb is end stream_tb;

-- Define architecture
architecture stream_tb of stream_tb is

   signal axiClk            : sl;
   signal axiClkRst         : sl;
   signal axiMaster         : AxiStreamMasterType;
   signal axiSlave          : AxiStreamSlaveType;

   constant AXIS_CONFIG_C : AxiStreamConfigTYpe := ssiAxiStreamConfig (4);

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

   U_AxiStreamSim : entity work.AxiStreamSim 
      generic map (
         TPD_G            => 1 ns,
         AXIS_CONFIG_G    => AXIS_CONFIG_C,
         EOFE_TUSER_EN_G  => true,
         EOFE_TUSER_BIT_G => SSI_EOFE_C,
         SOF_TUSER_EN_G   => true,
         SOF_TUSER_BIT_G  => SSI_SOF_C
      ) port map ( 
         sAxisClk    => axiClk,
         sAxisRst    => axiClkRst,
         sAxisMaster => axiMaster,
         sAxisSlave  => axiSlave,
         mAxisClk    => axiClk,
         mAxisRst    => axiClkRst,
         mAxisMaster => axiMaster,
         mAxisSlave  => axiSlave
      );

end stream_tb;

