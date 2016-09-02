------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity dma_read_tb is end dma_read_tb;

-- Define architecture
architecture dma_read_tb of dma_read_tb is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 4
   );

   signal axiClk         : sl;
   signal axiClkRst      : sl;
   signal dmaReq         : AxiReadDmaReqType;
   signal dmaAck         : AxiReadDmaAckType;
   signal axisMaster     : AxiStreamMasterType;
   signal axisSlave      : AxiStreamSlaveType;
   signal axisCtrl       : AxiStreamCtrlType;
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal rxCount        : slv(31 downto 0);

begin

   process begin
      axiClk <= '1';
      wait for 5 ns;
      axiClk <= '0';
      wait for 5 ns;
   end process;

   process begin
      axiClkRst <= '1';
      wait for (100 ns);
      axiClkRst <= '0';
      wait;
   end process;

   U_AxiStreamDmaRead: entity work.AxiStreamDmaRead
      generic map (
         TPD_G            => 1 ns,
         AXIS_READY_EN_G  => true,
         AXIS_CONFIG_G    => AXIS_CONFIG_C,
         AXI_CONFIG_G     => AXI_CONFIG_C,
         AXI_BURST_G      => "01",
         AXI_CACHE_G      => "1111",
         MAX_PEND_G       => 256
      ) port map (
         axiClk          => axiClk,
         axiRst          => axiClkRst,
         dmaReq          => dmaReq,
         dmaAck          => dmaAck,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave,
         axisCtrl        => axisCtrl,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave
      );

   U_AxiReadEmulate: entity work.AxiReadEmulate 
      generic map (
         TPD_G         => 1 ns,
         AXI_CONFIG_G  => AXI_CONFIG_C
      ) port map (
         axiClk          => axiClk,
         axiRst          => axiClkRst,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave
      );

   axisSlave <= AXI_STREAM_SLAVE_FORCE_C;
   axisCtrl  <= AXI_STREAM_CTRL_UNUSED_C;

   process ( axiClk ) begin
      if rising_edge(axiClk) then
         if axiClkRst = '1' then
            dmaReq            <= AXI_READ_DMA_REQ_INIT_C;
            dmaReq.address    <= toSlv(0,64);
            dmaReq.size       <= toSlv(9000,32);
            dmaReq.firstUser  <= x"0a";
            dmaReq.lastUser   <= x"0b";
            dmaReq.dest       <= (others=>'0');
            dmaReq.id         <= (others=>'0');
         else
            if dmaReq.request = '1' then
               if dmaAck.done = '1' then
                  dmaReq.request <= '0';
                  --dmaReq.address <= dmaReq.address + 1;

                  --if dmaReq.address(5 downto 0) = 0 then
                     --dmaReq.size <= dmaReq.size + 1;
                  --end if;
               end if;
            else
               dmaReq.request    <= '1';
            end if;
         end if;
      end if;
   end process;

   process ( axiClk ) is
      variable nxtCount : slv(31 downto 0);
   begin
      if rising_edge(axiClk) then

         nxtCount := rxCount;

         if axiClkRst = '1' then
            rxCount  <= (others=>'0');
            nxtCount := (others=>'0');
         else

            if axisMaster.tValid = '1' then
               nxtCount := rxCount + onesCount(axisMaster.tKeep(7 downto 0));
            end if;

            if axisMaster.tValid = '1' and axisMaster.tLast = '1' then
               assert nxtCount = dmaReq.size report "size mismatch" severity warning;
               nxtCount := (others=>'0');
            end if;
         end if;

         rxCount <= nxtCount;

      end if;
   end process;

end dma_read_tb;

