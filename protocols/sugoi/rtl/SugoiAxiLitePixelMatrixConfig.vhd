-------------------------------------------------------------------------------
-- Title      : SUGOI Protocol: https://confluence.slac.stanford.edu/x/3of_E
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Sugoi AxiLite Pixel Matrix Configuration Module
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

entity SugoiAxiLitePixelMatrixConfig is
   generic (
      TPD_G           : time                   := 1 ns;
      RST_ASYNC_G     : boolean                := false;
      COL_GRAY_CODE_G : boolean                := true;
      COL_WIDTH_G     : positive range 1 to 10 := 6;
      ROW_GRAY_CODE_G : boolean                := true;
      ROW_WIDTH_G     : positive range 1 to 10 := 6;
      DATA_WIDTH_G    : positive range 1 to 11 := 9;
      TIMER_WIDTH_G   : positive range 1 to 16 := 12);
   port (
      -- Matrix periphery: coldec and rowdec
      colAddr         : out   slv(COL_WIDTH_G-1 downto 0);
      rowAddr         : out   slv(ROW_WIDTH_G-1 downto 0);
      allCol          : out   sl;
      allRow          : out   sl;
      dataBus         : inout slv(DATA_WIDTH_G-1 downto 0);
      readWrite       : out   sl;  -- Selects between read (0) or write operation (1)
      globalRstL      : out   sl;       -- Global reset, active low
      cckReg          : out   sl;
      cckPix          : out   sl;
      -- AXI-Lite Slave Interface:
      -- Configure AXI-Lite XBAR for "3+COL_WIDTH_G+ROW_WIDTH_G' address bits
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end entity SugoiAxiLitePixelMatrixConfig;

architecture rtl of SugoiAxiLitePixelMatrixConfig is

   constant COL_DEC_ADDR_LOW_C  : integer := 2;  -- 32-bit (4-byte) word alignment
   constant COL_DEC_ADDR_HIGH_C : integer := (COL_WIDTH_G+COL_DEC_ADDR_LOW_C)-1;
   subtype COL_ADDR_RANGE_C is integer range COL_DEC_ADDR_HIGH_C downto COL_DEC_ADDR_LOW_C;

   constant ROW_DEC_ADDR_LOW_C  : integer := COL_DEC_ADDR_HIGH_C+1;
   constant ROW_DEC_ADDR_HIGH_C : integer := (ROW_WIDTH_G+ROW_DEC_ADDR_LOW_C)-1;
   subtype ROW_ADDR_RANGE_C is integer range ROW_DEC_ADDR_HIGH_C downto ROW_DEC_ADDR_LOW_C;

   constant ADDR_PARTITION_C : integer := 2+COL_WIDTH_G+ROW_WIDTH_G;

   type StateType is (
      IDLE_S,
      READ_CMD_S,
      WRITE_CMD_S);

   type RegType is record
      colReg         : slv(COL_WIDTH_G-1 downto 0);
      colAddr        : slv(COL_WIDTH_G-1 downto 0);
      rowReg         : slv(ROW_WIDTH_G-1 downto 0);
      rowAddr        : slv(ROW_WIDTH_G-1 downto 0);
      allCol         : sl;
      allRow         : sl;
      dataOut        : slv(DATA_WIDTH_G-1 downto 0);
      readWrite      : sl;
      configTri      : sl;
      globalRstL     : sl;
      cckReg         : sl;
      cckPix         : sl;
      cnt            : natural range 0 to 7;
      timer          : slv(TIMER_WIDTH_G-1 downto 0);
      timerSize      : slv(TIMER_WIDTH_G-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      colReg         => (others => '0'),
      colAddr        => (others => '0'),
      rowReg         => (others => '0'),
      rowAddr        => (others => '0'),
      allCol         => '0',
      allRow         => '0',
      dataOut        => (others => '0'),
      readWrite      => '0',
      configTri      => '1',
      globalRstL     => '1',
      cckReg         => '0',
      cckPix         => '0',
      cnt            => 0,
      timer          => (others => '0'),
      timerSize      => (others => '1'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dataIn : slv(DATA_WIDTH_G-1 downto 0) := (others => '0');

begin

   dataBus <= r.dataOut when(r.configTri = '0') else (others => 'Z');
   dataIn  <= dataBus;

   comb : process (axilReadMaster, axilRst, axilWriteMaster, dataIn, r) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Decrement the counter
      if (r.timer /= 0) then
         v.timer := r.timer - 1;
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the counter
            v.cnt := 0;

            -- Set the timer
            v.timer := r.timerSize;

            -- Check for write TXN
            if (axilStatus.readEnable = '1') then

               -- Local registers
               if (axilReadMaster.araddr(ADDR_PARTITION_C) = '0') then

                  -- Decode address and assign read data
                  case (axilReadMaster.araddr(3 downto 0)) is
                     when x"0" =>
                        v.axilReadSlave.rdata(3 downto 0)   := x"1";
                        v.axilReadSlave.rdata(4)            := ite(COL_GRAY_CODE_G, '1', '0');
                        v.axilReadSlave.rdata(5)            := ite(ROW_GRAY_CODE_G, '1', '0');
                        v.axilReadSlave.rdata(11 downto 8)  := toSlv(COL_WIDTH_G, 4);
                        v.axilReadSlave.rdata(15 downto 12) := toSlv(ROW_WIDTH_G, 4);
                        v.axilReadSlave.rdata(19 downto 16) := toSlv(DATA_WIDTH_G, 4);
                        v.axilReadSlave.rdata(31 downto 24) := toSlv(TIMER_WIDTH_G, 8);
                        axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);
                     when x"C" =>
                        v.axilReadSlave.rdata(15 downto 0) := resize(r.timerSize, 16);
                        v.axilReadSlave.rdata(16)          := r.allCol;
                        v.axilReadSlave.rdata(17)          := r.allRow;
                        v.axilReadSlave.rdata(18)          := r.globalRstL;
                        axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);
                     when others =>
                        axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_DECERR_C);
                  end case;

               -- External pixel register access
               else

                  -- Decode the col/row address
                  v.colReg := axilReadMaster.araddr(COL_ADDR_RANGE_C);
                  v.rowReg := axilReadMaster.araddr(ROW_ADDR_RANGE_C);

                  -- Next state
                  v.state := READ_CMD_S;
               end if;

            end if;

            -- Check for read TXN
            if (axilStatus.writeEnable = '1') then

               -- Local registers
               if (axilWriteMaster.awaddr(ADDR_PARTITION_C) = '0') then

                  -- Decode address and assign write data
                  case (axilWriteMaster.awaddr(3 downto 0)) is
                     when x"C" =>
                        v.timerSize  := axilWriteMaster.wdata(TIMER_WIDTH_G-1 downto 0);
                        v.allCol     := axilWriteMaster.wdata(16);
                        v.allRow     := axilWriteMaster.wdata(17);
                        v.globalRstL := axilWriteMaster.wdata(18);
                        axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);
                     when others =>
                        axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_DECERR_C);
                  end case;

               -- External pixel register access
               else

                  -- Decode the col/row address
                  v.colReg := axilWriteMaster.awaddr(COL_ADDR_RANGE_C);
                  v.rowReg := axilWriteMaster.awaddr(ROW_ADDR_RANGE_C);

                  -- Decode the data field
                  v.dataOut := axilWriteMaster.wdata(DATA_WIDTH_G-1 downto 0);

                  -- Ack the write TXN
                  axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);

                  -- Next state
                  v.state := WRITE_CMD_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when READ_CMD_S =>
            -- Check the read phase
            case (r.cnt) is
               when 0 =>
                  -- CCK PIX HIGH
                  v.cckPix := '1';
                  v.cckReg := '0';
               when 1 =>
                  -- CCK PIX LOW
                  v.cckPix := '0';
                  v.cckReg := '0';
               when 2 =>
                  -- CCK REG HIGH
                  v.cckPix := '0';
                  v.cckReg := '1';
               when 3 =>
                  -- CCK REG LOW
                  v.cckPix := '0';
                  v.cckReg := '0';
               when others =>
                  -- Default
                  v.cckPix := '0';
                  v.cckReg := '0';
            end case;

            -- Check for timeout
            if (r.timer = 0) then

               -- Set the timer
               v.timer := r.timerSize;

               -- Check if "CCK REG LOW" phase
               if (r.cnt = 3) then

                  -- Assign read data
                  v.axilReadSlave.rdata(DATA_WIDTH_G-1 downto 0) := dataIn;

                  -- Ack the read TXN
                  axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);

                  -- Next state
                  v.state := IDLE_S;

               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;

            end if;
         ----------------------------------------------------------------------
         when WRITE_CMD_S =>
            -- Check the read phase
            case (r.cnt) is
               when 0 =>
                  -- Disable pixel driver
                  v.readWrite := '1';
                  v.configTri := '1';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when 1 =>
                  -- Enable config driver
                  v.readWrite := '1';
                  v.configTri := '0';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when 2 =>
                  -- CCK REG HIGH
                  v.readWrite := '1';
                  v.configTri := '0';
                  v.cckPix    := '0';
                  v.cckReg    := '1';
               when 3 =>
                  -- CCK REG LOW
                  v.readWrite := '1';
                  v.configTri := '0';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when 4 =>
                  -- CCK PIX HIGH
                  v.readWrite := '1';
                  v.configTri := '0';
                  v.cckPix    := '1';
                  v.cckReg    := '0';
               when 5 =>
                  -- CCK PIX LOW
                  v.readWrite := '1';
                  v.configTri := '0';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when 6 =>
                  -- Disable config driver
                  v.readWrite := '1';
                  v.configTri := '1';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when 7 =>
                  -- Enable pixel driver
                  v.readWrite := '0';
                  v.configTri := '1';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
               when others =>
                  -- Default
                  v.readWrite := '0';
                  v.configTri := '1';
                  v.cckPix    := '0';
                  v.cckReg    := '0';
            end case;

            -- Check for timeout
            if (r.timer = 0) then

               -- Set the timer
               v.timer := r.timerSize;

               -- Check if "Enable pixel driver" phase
               if (r.cnt = 7) then

                  -- Next state
                  v.state := IDLE_S;

               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      ----------------------------------------
      -- Check for the encoding of the address
      ----------------------------------------

      if (COL_GRAY_CODE_G) then
         v.colAddr := grayEncode(r.colReg);
      else
         v.colAddr := r.colReg;
      end if;

      if (ROW_GRAY_CODE_G) then
         v.rowAddr := grayEncode(r.rowReg);
      else
         v.rowAddr := r.rowReg;
      end if;

      --------
      -- Reset
      --------
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      colAddr        <= r.colAddr;
      rowAddr        <= r.rowAddr;
      allCol         <= r.allCol;
      allRow         <= r.allRow;
      readWrite      <= r.readWrite;
      globalRstL     <= r.globalRstL;
      cckReg         <= r.cckReg;
      cckPix         <= r.cckPix;

   end process comb;

   seq : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G and axilRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
