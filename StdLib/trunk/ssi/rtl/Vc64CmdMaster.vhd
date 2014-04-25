-------------------------------------------------------------------------------
-- Title      : Command Slave Block
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : Vc64CmdMaster.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-09
-- Last update: 2014-04-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block for Command protocol over the VC.
-- The receive packet is 4 x 32-bits.
-- Word 0 Data[1:0]   = VC        (unused, legacy)
-- Word 0 Data[7:2]   = Dest_ID   (unused, legacy)
-- Word 0 Data[31:8]  = TID[31:0] (unused, legacy)
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
use work.Vc64Pkg.all;

entity Vc64CmdMaster is
   generic (
      TPD_G              : time                       := 1 ns;
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G     : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      BRAM_EN_G          : boolean                    := true;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 2**24;
      LITTLE_ENDIAN_G    : boolean                    := true;
      VC_WIDTH_G         : integer range 8  to 64     := 16   -- Bits: 8, 16, 32 or 64
   );
   port (

      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData        : in  Vc64DataType;
      vcRxCtrl        : out Vc64CtrlType;
      vcRxClk         : in  sl;
      vcRxRst         : in  sl := '0';

      -- Command signals
      cmdClk          : in  sl;
      cmdClkRst       : in  sl;
      cmdMasterOut    : out Vc64CmdMasterOutType
   );
end Vc64CmdMaster;

architecture rtl of Vc64CmdMaster is

   signal intRxData  : Vc64DataType;
   signal intRxCtrl  : Vc64CtrlType;

   type StateType is ( S_IDLE_C, S_CMD_C, S_DUMP_C );

   type RegType is record
      state            : StateType;
      cmdMasterOut     : Vc64CmdMasterOutType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => S_IDLE_C,
      cmdMasterOut     => VC64_CMD_MASTER_OUT_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ----------------------------------
   -- FIFO Mux
   ----------------------------------
   U_Vc64FifoMux : entity work.Vc64FifoMux 
      generic map (
         TPD_G               => TPD_G,
         RST_ASYNC_G         => false,
         RST_POLARITY_G      => '1',
         CASCADE_SIZE_G      => 1,
         LAST_STAGE_ASYNC_G  => true,
         EN_FRAME_FILTER_G   => true,
         PIPE_STAGES_G       => 0,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         BRAM_EN_G           => BRAM_EN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_SYNC_STAGES_G  => FIFO_SYNC_STAGES_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THES_G   => true,
         FIFO_AFULL_THRES_G  => FIFO_AFULL_THRES_G,
         LITTLE_ENDIAN_G     => LITTLE_ENDIAN_G,
         RX_WIDTH_G          => VC_WIDTH_G,
         TX_WIDTH_G          => 32
      ) port map (
         vcRxAlignError => open,
         vcRxDropWrite  => open,
         vcRxTermFrame  => open,
         vcRxThreshold  => (others => '1'),
         vcRxData       => vcRxData,
         vcRxCtrl       => vcRxCtrl,
         vcRxClk        => vcRxClk,
         vcRxRst        => vcRxRst,
         vcTxCtrl       => intRxCtrl,
         vcTxData       => intRxData,
         vcTxClk        => cmdClk,
         vcTxRst        => cmdClkRst
      );

   ----------------------------------
   -- Command State Machine
   ----------------------------------

   -- Always read
   intRxCtrl <= VC64_CTRL_FORCE_C;

   comb : process (cmdClkRst, r, intRxData ) is
      variable v  : RegType;
   begin
      v := r;

      -- Init, always read
      v.cmdMasterOut.valid    := '0';

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            if intRxData.valid = '1' and intRxData.sof = '1' then
               v.cmdMasterOut.ctxOut := intRxData.data(31 downto 8);
               v.state              := S_CMD_C;
            end if;

         -- Command Pulse
         when S_CMD_C =>
            if intRxData.valid = '1' then
               v.cmdMasterOut.opCode := intRxData.data(7 downto 0);
               v.state              := S_DUMP_C;
            end if;

         -- Dump
         when S_DUMP_C =>
            if intRxData.valid = '1' and intRxData.eof = '1' then
               v.cmdMasterOut.valid := not intRxData.eofe;
               v.state := S_IDLE_C;
            end if;

         when others =>
            v.state := S_IDLE_C;

      end case;

      if (cmdClkRst = '1') then
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

