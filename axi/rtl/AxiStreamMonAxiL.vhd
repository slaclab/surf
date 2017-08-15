-------------------------------------------------------------------------------
-- File       : AxiStreamMonAxiL.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-14
-- Last update: 2017-01-26
-------------------------------------------------------------------------------
-- Description: AXI Stream Monitor Module
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;


entity AxiStreamMonAxiL is
   generic (
      TPD_G           : time                := 1 ns;
      COMMON_CLK_G    : boolean             := false;  -- true if axisClk = statusClk
      AXIS_CLK_FREQ_G : real                := 156.25E+6;  -- units of Hz
      AXIS_NUM_SLOTS  : integer             := 1;
      AXIS_CONFIG_G   : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      AXIL_ERR_RESP_G : slv(1 downto 0)     := AXI_RESP_DECERR_C);
   port (
      -- AXIS Stream Interface
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : in  AxiStreamMasterArray(AXIS_NUM_SLOTS-1 downto 0);
      axisSlave         : in  AxiStreamSlaveArray(AXIS_NUM_SLOTS-1 downto 0);
      -- AXI lite slave port for register access
      axilClk           : in  std_logic;
      axilRst           : in  std_logic;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType);
end AxiStreamMonAxiL;

architecture rtl of AxiStreamMonAxiL is

   type RegType is record
      rstCnt            : sl;
      frameRate         : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
      frameRateMax      : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
      frameRateMin      : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
      bandwidth         : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);
      bandwidthMax      : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);
      bandwidthMin      : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      rstCnt            => '0',
      frameRate         => (others=>(others=>'0')),
      frameRateMax      => (others=>(others=>'0')),
      frameRateMin      => (others=>(others=>'0')),
      bandwidth         => (others=>(others=>'0')),
      bandwidthMax      => (others=>(others=>'0')),
      bandwidthMin      => (others=>(others=>'0')),
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal localRst : sl;


   signal frameRate         : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
   signal frameRateMax      : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
   signal frameRateMin      : Slv32Array(AXIS_NUM_SLOTS-1 downto 0);
   signal bandwidth         : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);
   signal bandwidthMax      : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);
   signal bandwidthMin      : Slv64Array(AXIS_NUM_SLOTS-1 downto 0);

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";   

begin

   localRst <= r.rstCnt or axisRst;

   G_StreamLinks : for i in 0 to (AXIS_NUM_SLOTS-1) generate 

      U_rateMonitor : entity work.AxiStreamMon 
      generic map(
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,  -- true if axisClk = statusClk
         AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,  -- units of Hz
         AXIS_CONFIG_G   => AXIS_CONFIG_G)
      port map(
         -- AXIS Stream Interface
         axisClk      => axisClk,
         axisRst      => localRst,
         axisMaster   => axisMaster(i), 
         axisSlave    => axisSlave(i),
         -- Status Interface
         statusClk    => axilClk,
         statusRst    => localRst,
         frameRate    => frameRate(i),
         frameRateMax => frameRateMax(i),
         frameRateMin => frameRateMin(i),
         bandwidth    => bandwidth(i),
         bandwidthMax => bandwidthMax(i),
         bandwidthMin => bandwidthMin(i)
      );

   end generate;

   comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, r,
                   frameRate, frameRateMax, frameRateMin, bandwidth, bandwidthMax, bandwidthMin) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
   begin
      v := r;

      for i in 0 to (AXIS_NUM_SLOTS-1) loop 
         v.frameRate(i)    := frameRate(i);
         v.frameRateMax(i) := frameRateMax(i);
         v.frameRateMin(i) := frameRateMin(i);
         v.bandwidth(i)    := bandwidth(i);
         v.bandwidthMax(i) := bandwidthMax(i);
         v.bandwidthMin(i) := bandwidthMin(i);
      end loop;

      v.rstCnt := '0';
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);
      
      axiSlaveRegister (regCon, x"00",  0, v.rstCnt);

      for i in 0 to (AXIS_NUM_SLOTS-1) loop
         axiSlaveRegisterR(regCon, toSlv(16 + (i * 48),16), 0,  r.frameRate(i));                       --x"10" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(20 + (i * 48),16), 0,  r.frameRateMax(i));                    --x"14" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(24 + (i * 48),16), 0,  r.frameRateMin(i));                    --x"18" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(28 + (i * 48),16), 0,  r.bandwidth(i)(31 downto 0));          --x"1C" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(32 + (i * 48),16), 0,  r.bandwidth(i)(63 downto 32));         --x"20" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(36 + (i * 48),16), 0,  r.bandwidthMax(i)(31 downto 0));       --x"24" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(40 + (i * 48),16), 0,  r.bandwidthMax(i)(63 downto 32));      --x"28" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(44 + (i * 48),16), 0,  r.bandwidthMin(i)(31 downto 0));       --x"2C" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(48 + (i * 48),16), 0,  r.bandwidthMin(i)(63 downto 32));      --x"30" + i * x"30" 
      end loop;
      
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);
      
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end rtl;


