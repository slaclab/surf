-------------------------------------------------------------------------------
-- Title      : Command Slave Block
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : SsiCmdMaster.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-09
-- Last update: 2014-04-28
-- Platform   : 
-- Standard   : VHDL'93/02
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
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/09/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamCmdMaster is
   generic (
      TPD_G : time := 1 ns;

      -- AXI Stream FIFO Config
      BRAM_EN_G           : boolean                    := false;
      XIL_DEVICE_G        : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G      : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 4;
      FIFO_FIXED_THRESH_G : boolean                    := true;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 8;

      -- AXI Stream Configuration
      SLAVE_AXI_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
      );
   port (

      -- Streaming Data Interface
      axiClk          : in  sl;
      axiRst          : in  sl := '0';
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      sAxisFifoStatus : out AxiStreamFifoStatusType;

      -- Command signals
      cmdClk    : in  sl;
      cmdRst    : in  sl;
      cmdMaster : out CmdMasterType
      );
end AxiStreamCmdMaster;

architecture rtl of AxiStreamCmdMaster is

   constant CMD_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4);

   signal fifoAxisMaster : AxiStreamMasterType;
   signal fifoAxisSlave  : AxiStreamSlaveType;

   type StateType is (IDLE_S, CMD_S, DUMP_S);

   type RegType is record
      state     : StateType;
      txnNumber : slv(1 downto 0);
      cmdMaster : CmdMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => S_IDLE_C,
      txnNumber => (others => '0'),
      cmdMaster => SSI_CMD_MASTER_OUT_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ----------------------------------
   -- Fifo
   ----------------------------------
   AxiStreamFifo_1 : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         BRAM_EN_G           => BRAM_EN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => FIFO_FIXED_THRESH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => CMD_AXI_CONFIG_G)
      port map (
         slvAxiClk       => axiClk,
         slvAxiRst       => axiRst,
         slvAxisMaster   => sAxisMaster,
         slvAxisSlave    => sAxisSlave,
         mstAxiClk       => cmdClk,
         mstAxiRst       => cmdRst,
         mstAxisMaster   => fifoAxisMaster,
         mstAxisSlave    => fifoAxisSlave);


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
      v.cmdMasterOut.valid := '0';


      if (fifoAxisMaster.tValid = '1') then
         v.txnNumber := r.txnNumber + 1;

         case r.txnNumber is
            when "00" =>
               v.cmdMaster.ctxOut := fifoAxisMaster.tData(31 downto 8);
            when "01" =>
               v.cmdMaster.opCode := fifoAxisMaster.tData(7 downto 0);
            when "11" =>
               v.cmdMaster.valid := fifoAxisMaster.tLast = '1' and
                                    fifoAxisMaster.tUser(SSI_EOFE_C) = '0';
            when others => null;
         end case;

         -- Reset frame on tLast or EOFE
         if (fifoAxisMaster.tLast = '1' or fifoAxisMaster.tUser(SSI_EOFE_C) = '1') then
            v.txnNumber := (others => '0');
         end if;
         
      end if;

      if (not ssiTxnIsComplaint(SLAVE_AXI_STREAM_CONFIG_G, fifoAxisMaster)) then
         v := REG_INIT_C;
      end if;

      if (cmdRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      cmdMasterOut <= r.cmdMasterOut;

   end process comb;

   seq : process (cmdClk) is
   begin
      if (rising_edge(cmdClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

