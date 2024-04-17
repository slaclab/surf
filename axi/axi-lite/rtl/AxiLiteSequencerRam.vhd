-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: The slave AXI-Lite interface used to load a sequence of master
--              AXI-Lite transactions.  The transactions are stored in
--              address=[1:2**ADDR_WIDTH_G-1].  Writing to Address[0] will
--              start the transaction sequence and the number of transactions
--              to execute.  At the end of the sequence (or if a bus error is
--              detected during the sequence) a slave AXI-lite bus response is
--              executed.  If there is a bus error, the address/response/data
--              is written into address[0] of the RAM for debugging.
-------------------------------------------------------------------------------
-- Sequencer's RAM Address mapping:
-- sAxil.address[0x00].BIT[ADDR_WIDTH_G-1:0](write) = (r.size) Starts transactions and number of transactions to execute (zero exclusive)
-- sAxil.address[0x00].BIT[31:ADDR_WIDTH_G](write)  = Unused
-- sAxil.address[0x04].BIT[31:0](write)             = Unused
-- sAxil.address[0x00](Read)                        = zero if no error response else mAxil.Data[errorEvent].BIT[31:00]
-- sAxil.address[0x04](Read)                        = zero if no error response else mAxil.Address[errorEvent].BIT[31:02] & errorResp
-- sAxil.address[0x08] = Ram.Address[0x1].BIT[31:00]: Sequenced mAxil.Data[0].BIT[31:00]
-- sAxil.address[0x0C] = Ram.Address[0x1].BIT[63:32]: Sequenced mAxil.Address[0].BIT[31:02] & '0' & RnW
-- sAxil.address[0x10] = Ram.Address[0x2].BIT[31:00]: Sequenced mAxil.Data[1][31:00]
-- sAxil.address[0x14] = Ram.Address[0x2].BIT[63:32]: Sequenced mAxil.Address[1].BIT[31:02] & '0' & RnW
-- sAxil.address[0x18] = Ram.Address[0x3].BIT[31:00]: Sequenced mAxil.Data[2][31:00]
-- sAxil.address[0x1C] = Ram.Address[0x3].BIT[63:32]: Sequenced mAxil.Address[2].BIT[31:02] & '0' & RnW
-- .....
-- .....
-- sAxil.address[8*r.size+0x0] = Ram.Address[r.size].BIT[31:00]: Sequenced mAxil.Data[r.size-1][31:00]
-- sAxil.address[8*r.size+0x4] = Ram.Address[r.size].BIT[63:32]: Sequenced mAxil.Address[r.size-1].BIT[31:02] & '0' & RnW
--
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteSequencerRam is
   generic (
      TPD_G               : time                 := 1 ns;
      RST_ASYNC_G         : boolean              := false;
      SYNTH_MODE_G        : string               := "inferred";
      MEMORY_TYPE_G       : string               := "block";
      MEMORY_INIT_FILE_G  : string               := "none";  -- Used for MEMORY_TYPE_G="XPM only
      MEMORY_INIT_PARAM_G : string               := "0";  -- Used for MEMORY_TYPE_G="XPM only
      WAIT_FOR_RESPONSE_G : boolean              := false;  -- false: immediately respond back for address[0], true: wait for the end of the transaction sequences
      READ_LATENCY_G      : natural range 0 to 3 := 2;
      ADDR_WIDTH_G        : positive             := 8);  -- Number of sequenced AXI-Lite master transactions = 2**ADDR_WIDTH_G - 1
   port (
      -- Clock and Reset
      axilClk          : in  sl;
      axilRst          : in  sl;
      -- External Control Interface
      extStart         : in  sl                           := '0';
      extSize          : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      extBusy          : out sl;
      extDone          : out sl;
      -- Slave AXI-Lite Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Master AXI-Lite Interface
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType);
end entity AxiLiteSequencerRam;

architecture rtl of AxiLiteSequencerRam is

   subtype AXI_DEC_ADDR_RANGE_C is integer range 2 downto 2;
   constant AXI_RAM_ADDR_HIGH_C : integer := ADDR_WIDTH_G+AXI_DEC_ADDR_RANGE_C'high;
   constant AXI_RAM_ADDR_LOW_C  : integer := AXI_DEC_ADDR_RANGE_C'high+1;
   subtype AXI_RAM_ADDR_RANGE_C is integer range AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C;

   type StateType is (
      IDLE_S,
      S_AXI_RD_S,
      M_AXI_REQ_S,
      M_AXI_ACK_S,
      SEQ_DONE_S);

   type RegType is record
      extBusy         : sl;
      extDone         : sl;
      sAxilWriteSlave : AxiLiteWriteSlaveType;
      sAxilReadSlave  : AxiLiteReadSlaveType;
      din             : slv(63 downto 0);
      wstrb           : slv(7 downto 0);
      addr            : slv(ADDR_WIDTH_G-1 downto 0);
      size            : slv(ADDR_WIDTH_G-1 downto 0);
      cnt             : slv(ADDR_WIDTH_G-1 downto 0);
      seqAddr         : slv(ADDR_WIDTH_G-1 downto 0);
      resp            : slv(1 downto 0);
      rdLatecy        : natural range 0 to READ_LATENCY_G;
      req             : AxiLiteReqType;
      state           : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      extBusy         => '0',
      extDone         => '0',
      sAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      wstrb           => (others => '0'),
      din             => (others => '0'),
      addr            => (others => '0'),
      size            => (others => '0'),
      cnt             => (others => '0'),
      seqAddr         => (others => '0'),
      resp            => (others => '0'),
      rdLatecy        => 0,
      req             => AXI_LITE_REQ_INIT_C,
      state           => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal seqData : slv(63 downto 0);
   signal dout    : slv(63 downto 0);
   signal ack     : AxiLiteAckType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   U_AxiLiteMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => RST_ASYNC_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave);

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_RAM : entity surf.TrueDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            COMMON_CLK_G        => true,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => MEMORY_INIT_PARAM_G,
            READ_LATENCY_G      => READ_LATENCY_G,
            DATA_WIDTH_G        => 64,
            BYTE_WR_EN_G        => true,
            BYTE_WIDTH_G        => 8,
            ADDR_WIDTH_G        => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka  => axilClk,
            wea   => r.wstrb,
            addra => r.addr,
            dina  => r.din,
            douta => dout,
            -- Port B
            clkb  => axilClk,
            addrb => r.seqAddr,
            doutb => seqData);
   end generate;

   GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
      U_RAM : entity surf.TrueDualPortRamAlteraMf
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => READ_LATENCY_G,
            DATA_WIDTH_G   => 64,
            BYTE_WR_EN_G   => true,
            BYTE_WIDTH_G   => 8,
            ADDR_WIDTH_G   => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka  => axilClk,
            wea   => r.wstrb,
            addra => r.addr,
            dina  => r.din,
            douta => dout,
            -- Port B
            clkb  => axilClk,
            addrb => r.seqAddr,
            doutb => seqData);
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
      U_RAM : entity surf.TrueDualPortRam
         generic map (
            TPD_G        => TPD_G,
            RST_ASYNC_G  => RST_ASYNC_G,
            BYTE_WR_EN_G => true,
            DOA_REG_G    => ite(READ_LATENCY_G >= 2, true, false),
            DOB_REG_G    => ite(READ_LATENCY_G >= 2, true, false),
            DATA_WIDTH_G => 64,
            BYTE_WIDTH_G => 8,
            ADDR_WIDTH_G => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka    => axilClk,
            wea     => '1',
            weaByte => r.wstrb,
            addra   => r.addr,
            dina    => r.din,
            douta   => dout,
            -- Port B
            clkb    => axilClk,
            addrb   => r.seqAddr,
            doutb   => seqData);
   end generate;

   comb : process (ack, axilRst, dout, extSize, extStart, r, sAxilReadMaster,
                   sAxilWriteMaster, seqData) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
      variable rdIdx      : natural;
      variable wrIdx      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Update the variables
      wrIdx := conv_integer(sAxilWriteMaster.awaddr(AXI_DEC_ADDR_RANGE_C));
      rdIdx := conv_integer(sAxilReadMaster.araddr(AXI_DEC_ADDR_RANGE_C));

      -- Reset strobes
      v.wstrb := (others => '0');

      ---------------------------------
      -- Determine the transaction type
      ---------------------------------
      axiSlaveWaitTxn(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilStatus);

      -----------------------------------
      -- Multiplex read data onto axi bus
      -----------------------------------
      v.sAxilReadSlave.rdata := dout((rdIdx+1)*32-1 downto rdIdx*32);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>

            -- Reset the flags
            v.extBusy := '0';
            v.extDone := '0';

            -- Preset RAM Address to first transaction
            v.seqAddr := toSlv(1, ADDR_WIDTH_G);

            -- Check for write transaction
            if (axilStatus.writeEnable = '1') then

               -- Check if loading the RAM
               if (sAxilWriteMaster.awaddr(AXI_RAM_ADDR_HIGH_C downto 0) /= 0) then

                  -- Write the data to RAM
                  v.addr                                := sAxilWriteMaster.awaddr(AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C);
                  v.din(31 downto 0)                    := sAxilWriteMaster.wdata;
                  v.din(63 downto 32)                   := sAxilWriteMaster.wdata;
                  v.wstrb((wrIdx+1)*4-1 downto wrIdx*4) := sAxilWriteMaster.wstrb;

                  -- Send the write response
                  axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);

               -- Else go through the sequence
               else

                  -- Latch the size
                  v.size := sAxilWriteMaster.wdata(ADDR_WIDTH_G-1 downto 0);

                  -- Reset the counter
                  v.cnt := (others => '0');

                  -- Check for invalid size
                  if (v.size = 0) then
                     -- Send the error response
                     axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_DECERR_C);
                  else

                     -- Check if we are not going to wait for end of transaction to send bus responds
                     if (WAIT_FOR_RESPONSE_G = false) then
                        -- Clear out debugging cache
                        v.addr  := (others => '0');
                        v.din   := (others => '0');
                        v.wstrb := (others => '1');

                        -- Send the write response
                        axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);

                     end if;

                     -- Next state
                     v.state := M_AXI_REQ_S;
                  end if;

               end if;

            -- Check for read transaction
            elsif (axilStatus.readEnable = '1') then

               -- Set the address bus
               v.addr := sAxilReadMaster.araddr(AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C);

               -- Next state
               v.state := S_AXI_RD_S;

            -- Check for external start and non-zero size
            elsif (extStart = '1') and (extSize /= 0) then

               -- Set the flag
               v.extBusy := '1';

               -- Latch the size
               v.size := extSize;

               -- Reset the counter
               v.cnt := (others => '0');

               -- Clear out debugging cache
               v.addr  := (others => '0');
               v.din   := (others => '0');
               v.wstrb := (others => '1');

               -- Next state
               v.state := M_AXI_REQ_S;

            end if;
         ----------------------------------------------------------------------
         when S_AXI_RD_S =>
            -- Wait for the RAM read latency
            if (r.rdLatecy = 0) then

               -- Send the read response
               axiSlaveReadResponse(v.sAxilReadSlave, AXI_RESP_OK_C);

               -- Next state
               v.state := IDLE_S;

            end if;
         ----------------------------------------------------------------------
         when M_AXI_REQ_S =>
            -- Wait for the RAM read latency
            if (r.rdLatecy = 0) then
               -- Check if transaction completed
               if (ack.done = '0') then

                  -- Setup the AXI-Lite Master request
                  v.req.request := '1';
                  v.req.address := seqData(63 downto 34) & "00";
                  v.req.rnw     := seqData(32);  -- 0 = Write operation, 1 = Read operation
                  v.req.wrData  := seqData(31 downto 0);

                  -- Increment the read counter
                  v.cnt := r.cnt + 1;

                  -- Next state
                  v.state := M_AXI_ACK_S;

               end if;
            end if;
         ----------------------------------------------------------------------
         when M_AXI_ACK_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then

               -- Reset the flag
               v.req.request := '0';

               -- Setup for the next read
               v.seqAddr := r.seqAddr + 1;

               -- Check for error response
               if (ack.resp /= 0) then

                  -- Write the error transaction in RAM[addr=0]
                  v.addr              := (others => '0');
                  v.wstrb             := (others => '1');
                  v.din(63 downto 32) := r.req.address(31 downto 2) & ack.resp;
                  v.din(31 downto 0)  := r.req.wrData;

                  -- Check if we are going to wait for end of transaction to send bus responds
                  if (WAIT_FOR_RESPONSE_G = true) then
                     -- Send the write response
                     axiSlaveWriteResponse(v.sAxilWriteSlave, ack.resp);
                  end if;

                  -- Next state
                  v.state := IDLE_S;

               -- Else ack.resp = AXI_RESP_OK_C
               else

                  -- Check if read transaction
                  if (r.req.rnw = '1') then

                     -- Write the read transaction into RAM
                     v.addr              := r.seqAddr;
                     v.wstrb             := (others => '1');
                     v.din(63 downto 32) := r.req.address(31 downto 2) & '0' & r.req.rnw;
                     v.din(31 downto 0)  := ack.rdData;

                  end if;

                  -- Check for last transaction
                  if (r.cnt = r.size) then

                     -- Check if we are going to wait for end of transaction to send bus responds
                     if (WAIT_FOR_RESPONSE_G = true) then

                        -- Send the write response
                        axiSlaveWriteResponse(v.sAxilWriteSlave, AXI_RESP_OK_C);

                        -- Next state
                        v.state := IDLE_S;

                     else
                        -- Next state
                        v.state := SEQ_DONE_S;
                     end if;

                  else

                     -- Next state
                     v.state := M_AXI_REQ_S;

                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEQ_DONE_S =>
            -- Set all bits to 1 so SW knowns it done
            v.addr  := (others => '0');
            v.din   := (others => '1');
            v.wstrb := (others => '1');
            -- Next state
            v.state := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- Check for change in read address
      if (r.addr /= v.addr) or (r.seqAddr /= v.seqAddr) then
         -- Set the timeout
         v.rdLatecy := READ_LATENCY_G;

      -- Check if need to decrement the counter
      elsif (r.rdLatecy /= 0) then
         -- Decrement the counter
         v.rdLatecy := r.rdLatecy - 1;
      end if;

      -- Check for IDLE transition
      if (r.state /= IDLE_S) and (v.state = IDLE_S) then
         -- Set flag if sequence was externally initiated
         v.extDone := r.extBusy;
      end if;

      -- Output assignment
      sAxilReadSlave  <= r.sAxilReadSlave;
      sAxilWriteSlave <= r.sAxilWriteSlave;
      extBusy         <= v.extBusy;
      extDone         <= v.extDone;

      -- Reset
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G and axilRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
