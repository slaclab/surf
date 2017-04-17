-------------------------------------------------------------------------------
-- File       : SsiCmdMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-09
-- Last update: 2015-06-23
-------------------------------------------------------------------------------
-- Description:
-- Block for Command protocol over the VC.
-- The receive packet is 4 x 32-bits.
-- Word 0 Data[1:0]   = VC        (unused, legacy)
-- Word 0 Data[7:2]   = Dest_ID   (unused, legacy)
-- Word 0 Data[31:8]  = CmdCtx[31:0] (unused, legacy)
-- Word 1 Data[7:0]   = OpCode[7:0]
-- Word 1 Data[31:8]  = Don't Care
-- Word 2             = Don't Care
-- Word 3             = Don't Care
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
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

entity SsiCmdMaster is
   generic (
      TPD_G : time := 1 ns;

      -- AXI Stream FIFO Config
      SLAVE_READY_EN_G    : boolean                    := false;
      BRAM_EN_G           : boolean                    := false;
      XIL_DEVICE_G        : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G      : boolean                    := false;  --if set to true, this module is only Xilinx compatible only!!!
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 4;
      FIFO_FIXED_THRESH_G : boolean                    := true;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 8;

      -- AXI Stream Configuration
      AXI_STREAM_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
      );
   port (

      -- Streaming Data Interface
      axisClk     : in  sl;
      axisRst     : in  sl := '0';
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

      -- Command signals
      cmdClk    : in  sl;
      cmdRst    : in  sl;
      cmdMaster : out SsiCmdMasterType
      );
end SsiCmdMaster;

architecture rtl of SsiCmdMaster is

   signal fifoAxisMaster : AxiStreamMasterType;
   signal fifoAxisSlave  : AxiStreamSlaveType;

   type StateType is (IDLE_S, CMD_S, DUMP_S);

   type RegType is record
      txnNumber : slv(2 downto 0);
      cmdMaster : SsiCmdMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      txnNumber => (others => '0'),
      cmdMaster => SSI_CMD_MASTER_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   constant INT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

begin

   ----------------------------------
   -- Fifo
   ----------------------------------
   SlaveAxiStreamFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => INT_CONFIG_C)
      port map (
         sAxisClk    => axisClk,
         sAxisRst    => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => sAxisCtrl,
         mAxisClk    => cmdClk,
         mAxisRst    => cmdRst,
         mAxisMaster => fifoAxisMaster,
         mAxisSlave  => fifoAxisSlave);


   ----------------------------------
   -- Command State Machine
   ----------------------------------

   -- Always read
   fifoAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   comb : process (cmdRst, fifoAxisMaster, r) is
      variable v : RegType;
   begin
      v := r;

      -- Init, always read
      v.cmdMaster.valid := '0';


      if (fifoAxisMaster.tValid = '1') then
         v.txnNumber := r.txnNumber + 1;

         case r.txnNumber is
            when "000" =>
               v.cmdMaster.context := fifoAxisMaster.tData(31 downto 8);
            when "001" =>
               v.cmdMaster.opCode := fifoAxisMaster.tData(7 downto 0);
            when "011" =>
               v.cmdMaster.valid := fifoAxisMaster.tLast and not ssiGetUserEofe(INT_CONFIG_C, fifoAxisMaster);
            when "100" =>
               -- Too many txns in frame, freeze counting
               -- Will auto reset txnNumber to 0 on tLast
               v.txnNumber := r.txnNumber;
            when others => null;
         end case;


         --if (not axiStreamPacked(INT_CONFIG_C, fifoAxisMaster)) then
         --   -- Fail frame if any txn is not packed
         --   v.txnNumber       := "100";
         --   v.cmdMaster.valid := '0';
         --end if;

         if (fifoAxisMaster.tLast = '1') then
            -- Reset frame on tLast or EOFE
            v.txnNumber := "000";
         end if;
         
      end if;

      if (cmdRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      cmdMaster <= r.cmdMaster;

   end process comb;

   seq : process (cmdClk) is
   begin
      if (rising_edge(cmdClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

