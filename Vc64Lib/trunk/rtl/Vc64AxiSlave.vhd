-------------------------------------------------------------------------------
-- Title      : Register Slave Block
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : Vc64AxiSlave.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-09
-- Last update: 2014-04-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Slave block for Register protocol.
-- Packet is a minimum of 4 x 32-bits
--
-- Incoming Request:
-- Word 0   Data[1:0]   = VC (legacy, echoed)
-- Word 0   Data[7:2]   = Dest_ID (legacy, echoed)
-- Word 0   Data[31:8]  = TID[31:0] (legacy, echoed)
--
-- Word 1   Data[23:0]  = Address[23:0]
-- Word 1   Data[29:24] = Don't Care
-- Word 1   Data[31:30] = Opcode, 0x0=Read, 0x1=Write, 0x2=Set, 0x3=Clear 
--                        (bit set and bit clear not supported)
-- Word 2   Data[31:0]  = WriteData[31:0] or ReadCount[8:0]
--
-- Word N-1 Data[31:0]  = WriteData[31:0]
--
-- Word N   Data[31:2]  = Don't Care
--
-- Outgoing Response:
-- Word 0   Data[1:0]   = VC (legacy, echoed)
-- Word 0   Data[7:2]   = Dest_ID (legacy, echoed)
-- Word 0   Data[31:8]  = TID[31:0] (legacy, echoed)
--
-- Word 1   Data[23:0]  = Address[23:0]
-- Word 1   Data[29:24] = Don't Care
-- Word 1   Data[31:30] = OpCode, 0x0=Read, 0x1=Write, 0x2=Set, 0x3=Clear
--
-- Word 2   Data[31:0]  = ReadData[31:0]/WriteData[31:0]
--
-- Word N-1 Data[31:0]  = ReadData[31:0]/WriteData[31:0]
--
-- Word N   Data[31:2]  = Don't Care
-- Word N   Data[1]     = Timeout Flag (response data)
-- Word N   Data[0]     = Fail Flag (response data)
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
use work.AxiLitePkg.all;

entity Vc64AxiSlave is
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

      -- Streaming TX Data Interface (vcRxClk domain) 
      vcTxData        : out Vc64DataType;
      vcTxCtrl        : in  Vc64CtrlType;
      vcTxClk         : in  sl;
      vcTxRst         : in  sl := '0';

      -- AXI Lite Buss
      axiClk           : in  sl;
      axiClkRst        : in  sl;
      axiWriteMaster   : out AxiLiteWriteMasterType;
      axiWriteSlave    : in  AxiLiteWriteSlaveType;
      axiReadMaster    : out AxiLiteReadMasterType;
      axiReadSlave     : in  AxiLiteReadSlaveType
   );

end Vc64AxiSlave;

architecture rtl of Vc64AxiSlave is

   signal intRxData  : Vc64DataType;
   signal intRxCtrl  : Vc64CtrlType;
   signal intTxData  : Vc64DataType;
   signal intTxCtrl  : Vc64CtrlType;

   type StateType is (S_IDLE_C, S_ADDR_C, S_WRITE_C, S_WRITE_AXI_C, S_READ_SIZE_C, 
                      S_READ_C, S_READ_AXI_C, S_STATUS_C, S_DUMP_C );

   type RegType is record
      echo           : slv(31 downto 0);
      address        : slv(31 downto 0);
      rdSize         : slv(8  downto 0);
      rdCount        : slv(8  downto 0);
      timer          : slv(23 downto 0);
      state          : StateType;
      timeout        : sl;
      fail           : sl;
      axiWriteMaster : AxiLiteWriteMasterType;
      axiReadMaster  : AxiLiteReadMasterType;
      intRxCtrl      : Vc64CtrlType;
      intTxData      : Vc64DataType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      echo           => (others => '0'),
      address        => (others => '0'),
      rdSize         => (others => '0'),
      rdCount        => (others => '0'),
      timer          => (others => '0'),
      state          => S_IDLE_C,
      timeout        => '0',
      fail           => '0',
      axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      intRxCtrl      => VC64_CTRL_INIT_C,
      intTxData      => VC64_DATA_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ----------------------------------
   -- Input FIFO Mux
   ----------------------------------
   U_RxFifoMux : entity work.Vc64FifoMux 
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
         vcTxClk        => axiClk,
         vcTxRst        => axiClkRst
      );


   -------------------------------------
   -- Master State Machine
   -------------------------------------

   comb : process (axiClkRst, r, intRxData, intTxCtrl, axiWriteSlave, axiReadSlave ) is
      variable v  : RegType;
   begin
      v := r;

      -- Init
      v.intTxData            := intRxData;
      v.intTxData.eof        := '0';
      v.intTxData.eofe       := '0';
      v.intTxData.valid      := '0';
      v.intRxCtrl.ready      := '0';
      v.intRxCtrl.almostFull := '0';

      -- State machine
      case r.state is

         -- Idle
         when S_IDLE_C =>
            v.axiWriteMaster  := AXI_LITE_WRITE_MASTER_INIT_C;
            v.axiReadMaster   := AXI_LITE_READ_MASTER_INIT_C;
            v.address         := (others => '0');
            v.rdSize          := (others => '0');
            v.rdCount         := (others => '0');
            v.timeout         := '0';
            v.fail            := '0';
            v.intRxCtrl.ready := '1';

            -- Frame is starting
            if intRxData.valid = '1' and intRxData.sof = '1' and intRxData.eof = '0' then
               v.intTxData.valid := '1'; -- Echo word 0
               v.echo            := intRxData.data(31 downto 0);
               v.state           := S_ADDR_C;
            end if;

         -- Address Field
         when S_ADDR_C =>
            v.intRxCtrl.ready := '1';

            if intRxData.valid = '1' then
               v.address         := "000000" & intRxData.data(23 downto 0) & "00";
               v.intTxData.valid := '1'; -- Echo word 1

               -- Short frame, return error
               if intRxData.eof = '1' then
                  v.fail  := '1';
                  v.state := S_STATUS_C;

               -- Read
               elsif intRxData.data(31 downto 30) = "00" then
                  v.state := S_READ_SIZE_C;

               -- Write 
               elsif intRxData.data(31 downto 30) = "01" then
                  v.state := S_WRITE_C;

               -- Not supported
               else
                  v.fail  := '1';
                  v.state := S_DUMP_C;
               end if;
            end if;

         -- Prepare Write Transaction
         when S_WRITE_C =>
            v.axiWriteMaster.awaddr       := r.address;
            v.axiWriteMaster.awprot       := (others=>'0');
            v.axiWriteMaster.wstrb        := (others=>'1');
            v.axiWriteMaster.wdata        := intRxData.data(31 downto 0);
            v.intRxCtrl.ready             := '1';
            v.timer                       := (others=>'1');

            if intRxData.valid = '1' then
               if intRxData.eof = '1' then
                  v.state := S_STATUS_C;
               else
                  v.intTxData.valid        := '1'; -- Echo write data
                  v.axiWriteMaster.awvalid := '1';
                  v.axiWriteMaster.wvalid  := '1';
                  v.axiWriteMaster.bready  := '1';
                  v.state                  := S_WRITE_AXI_C;
               end if;
            end if;

         -- Write Transaction, AXI
         when S_WRITE_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if axiWriteSlave.awready = '1' then
               v.axiWriteMaster.awvalid := '0';
            end if;
            if axiWriteSlave.wready = '1' then
               v.axiWriteMaster.wvalid := '0';
            end if;
            if axiWriteSlave.bvalid = '1' then
               v.axiWriteMaster.bready := '0';

               if axiWriteSlave.bresp /= AXI_RESP_OK_C then
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.axiWriteMaster.awvalid := '0';
               v.axiWriteMaster.wvalid  := '0';
               v.axiWriteMaster.bready  := '0';
               v.timeout                := '1';
            end if;

            -- Transaction is done
            if v.axiWriteMaster.awvalid = '0' and 
               v.axiWriteMaster.wvalid = '0' and 
               v.axiWriteMaster.bready = '0' then

               v.address := r.address + 4;
               v.state   := S_WRITE_C;
            end if;

         -- Read size 
         when S_READ_SIZE_C =>
            v.rdCount := (others=>'0');
            v.rdSize  := intRxData.data(8 downto 0);

            -- Don't read if EOF (need for dump later)
            if intRxData.valid = '1' then
               v.intRxCtrl.ready := not intRxData.eof;
               v.state           := S_READ_C;
            end if;

         -- Read transaction
         when S_READ_C =>
            v.axiReadMaster.araddr  := r.address;
            v.axiReadMaster.arprot  := (others=>'0');
            v.timer                 := (others=>'1');

            -- Start AXI transaction
            v.axiReadMaster.arvalid := '1';
            v.axiReadMaster.rready  := '1';
            v.state                 := S_READ_AXI_C;

         -- Read AXI
         when S_READ_AXI_C =>
            v.timer := r.timer - 1;

            -- Clear control signals on ack
            if axiReadSlave.arready = '1' then
               v.axiReadMaster.arvalid := '0';
            end if;
            if axiReadSlave.rvalid = '1' then
               v.axiReadMaster.rready        := '0';
               v.intTxData.data(31 downto 0) := axiReadSlave.rdata;

               if axiReadSlave.rresp /= AXI_RESP_OK_C then
                  v.fail := '1';
               end if;
            end if;

            -- End transaction on timeout
            if r.timer = 0 then
               v.axiReadMaster.arvalid := '0';
               v.axiReadMaster.rready  := '0';
               v.timeout               := '1';
            end if;

            -- Transaction is done
            if v.axiReadMaster.arvalid = '0' and v.axiReadMaster.rready = '0' then
               v.intTxData.valid := '1';
               v.address         := r.address + 4;
               v.rdCount         := r.rdCount + 1;

               if r.rdCount = r.rdSize then
                  v.state := S_DUMP_C;
               else
                  v.state := S_READ_C;
               end if;
            end if;

         -- Dump until EOF
         when S_DUMP_C =>
            v.intRxCtrl.ready := '1';

            if intRxData.valid = '1' and intRxData.eof = '1' then
               v.state := S_STATUS_C;
            end if;

         -- Send Status
         when S_STATUS_C =>
            v.intTxData.valid             := '1';
            v.intTxData.eof               := '1';
            v.intTxData.data(63 downto 2) := (others=>'0');
            v.intTxData.data(1)           := r.timeout;
            v.intTxData.data(0)           := r.fail;
            v.state                       := S_IDLE_C;

         when others =>
            v.state := S_IDLE_C;

      end case;

      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axiWriteMaster <= r.axiWriteMaster;
      axiReadMaster  <= r.axiReadMaster;
      intRxCtrl      <= v.intRxCtrl;
      intTxData      <= r.intTxData;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


   ----------------------------------
   -- Output FIFO Mux
   ----------------------------------
   U_TxFifoMux : entity work.Vc64FifoMux 
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
         RX_WIDTH_G          => 32,
         TX_WIDTH_G          => VC_WIDTH_G
      ) port map (
         vcRxAlignError => open,
         vcRxDropWrite  => open,
         vcRxTermFrame  => open,
         vcRxThreshold  => (others => '1'),
         vcRxData       => intTxData,
         vcRxCtrl       => intTxCtrl,
         vcRxClk        => axiClk,
         vcRxRst        => axiClkRst,
         vcTxCtrl       => vcTxCtrl,
         vcTxData       => vcTxData,
         vcTxClk        => vcTxClk,
         vcTxRst        => vcTxRst
      );

end rtl;

