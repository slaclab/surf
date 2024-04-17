-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SPI Master Wrapper that includes a state machine for SPI paging
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

entity ads54j60 is
   generic (
      TPD_G             : time            := 1 ns;
      CLK_PERIOD_G      : real            := (1.0/156.25E+6);
      SPI_SCLK_PERIOD_G : real            := 1.0E-6);
   port (
      -- Clock and Reset
      axiClk         : in  sl;
      axiRst         : in  sl;
      -- AXI-Lite Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- SPI Interface
      coreBusyIn     : in  sl := '0';
      coreBusyOut    : out sl;
      coreRst        : out sl;
      coreSclk       : out sl;
      coreSDin       : in  sl;
      coreSDout      : out sl;
      coreCsb        : out sl);
end entity ads54j60;

architecture rtl of ads54j60 is

   constant DLY_C : natural := integer(1.0E-6/CLK_PERIOD_G);  -- min. 1us delay between SPI cycles

   type StateType is (
      IDLE_S,
      INIT_S,
      REQ_S,
      ACK_S);

   type RegType is record
      busy          : sl;
      rst           : sl;
      axiRd         : sl;
      wrEn          : sl;
      wrData        : slv(23 downto 0);
      data          : slv(7 downto 0);
      addr          : slv(11 downto 0);
      xferType      : slv(3 downto 0);
      timer         : natural range 0 to DLY_C;
      cnt           : natural range 0 to 4;
      size          : natural range 0 to 4;
      wrArray       : Slv24Array(3 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      busy          => '0',
      rst           => '0',
      axiRd         => '0',
      wrEn          => '0',
      wrData        => (others => '0'),
      data          => (others => '0'),
      addr          => (others => '0'),
      xferType      => (others => '0'),
      timer         => 0,
      cnt           => 0,
      size          => 0,
      wrArray       => (others => (others => '0')),
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdEn   : sl;
   signal rdData : slv(23 downto 0);

begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, coreBusyIn, r,
                   rdData, rdEn) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.wrEn := '0';

      -- Increment the timer
      if (r.timer /= DLY_C) then
         v.timer := r.timer + 1;
      end if;

      -- Get the AXI-Lite status
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset flag
            v.busy := '0';
            if (coreBusyIn = '0') then
               -- Check if write transaction
               if (axiStatus.writeEnable = '1') then
                  -- Set the flag
                  v.axiRd    := '0';
                  -- Save the data/address
                  v.data     := axiWriteMaster.wdata(7 downto 0);
                  v.addr     := axiWriteMaster.awaddr(13 downto 2);
                  v.xferType := axiWriteMaster.awaddr(17 downto 14);
                  -- Next State
                  v.state    := INIT_S;
               -- Check if read transaction
               elsif (axiStatus.readEnable = '1') then
                  -- Set the flag
                  v.axiRd    := '1';
                  -- Save the data/address
                  v.data     := x"FF";
                  v.addr     := axiReadMaster.araddr(13 downto 2);
                  v.xferType := axiReadMaster.araddr(17 downto 14);
                  -- Next State
                  v.state    := INIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Set flag
            v.busy  := '1';
            -- Next State
            v.state := REQ_S;
            -- Reset the counter
            v.cnt   := 0;
            -- Check the transfer type
            -- Note: Refer to https://docs.google.com/spreadsheets/d/1aINNgtx3KLSflWDiDSXf65TUzIWHkWEZvU6GziYwcpY
            case r.xferType is
               -- General Registers: (XFER_Type = 0x0)
               when x"0" =>
                  v.size       := 1;
                  v.wrArray(0) := (r.axiRd & "000" & r.addr & r.data);
               -- Main digital page channel A: (XFER_Type = 0x1)
               when x"1" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"68");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "110" & r.addr & r.data);
               -- JESD digital page channel A: (XFER_Type = 0x2)
               when x"2" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"69");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "110" & r.addr & r.data);
               -- JESD analog page channel A: (XFER_Type = 0x3)
               when x"3" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"6A");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "110" & r.addr & r.data);
               -- Master Bank: (XFER_Type = 0x7)
               when x"7" =>
                  v.size       := 2;
                  v.wrArray(0) := (x"0011" & x"80");
                  v.wrArray(1) := (r.axiRd & "000" & r.addr & r.data);
               -- Analog Bank: (XFER_Type = 0x8)
               when x"8" =>
                  v.size       := 2;
                  v.wrArray(0) := (x"0011" & x"0F");
                  v.wrArray(1) := (r.axiRd & "000" & r.addr & r.data);
               -- Main digital page channel B: (XFER_Type = 0x9)
               when x"9" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"68");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "111" & r.addr & r.data);
               -- JESD digital page channel B: (XFER_Type = 0xA)
               when x"A" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"69");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "111" & r.addr & r.data);
               -- JESD analog page channel B: (XFER_Type = 0xB)
               when x"B" =>
                  v.size       := 4;
                  v.wrArray(0) := (x"4003" & x"00");
                  v.wrArray(1) := (x"4004" & x"6A");
                  v.wrArray(2) := (x"4005" & x"01");
                  v.wrArray(3) := (r.axiRd & "111" & r.addr & r.data);
               -- Clear Unused Pages: (XFER_Type = 0xE)
               when x"E" =>
                  v.size       := 2;
                  v.wrArray(0) := (x"4001" & x"00");
                  v.wrArray(1) := (x"4002" & x"00");
               -- Hardware Reset (XFER_Type = 0xF)
               when others =>
                  -- Check if transaction type
                  if (r.axiRd = '0') then
                     -- Write the bit
                     v.rst := axiWriteMaster.wdata(0);
                     -- Send the write response
                     axiSlaveWriteResponse(v.axiWriteSlave);
                  else
                     -- Reade the bit
                     v.axiReadSlave.rdata(7 downto 0) := ("0000000" & r.rst);
                     -- Send the response
                     axiSlaveReadResponse(v.axiReadSlave);
                  end if;
                  --- Next state
                  v.state := IDLE_S;
            end case;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check for min. chip select gap
            if (r.timer = DLY_C) then
               -- Start the transaction
               v.wrEn   := '1';
               v.wrData := r.wrArray(r.cnt);
               -- Increment the counter
               v.cnt    := r.cnt + 1;
               --- Next state
               v.state  := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- Wait for the transaction to complete
            if (rdEn = '1') and (r.wrEn = '0') then
               -- Reset the timer
               v.timer := 0;
               -- Check for last transaction
               if (r.size = r.cnt) then
                  -- Check if transaction type
                  if (r.axiRd = '0') then
                     -- Send the write response
                     axiSlaveWriteResponse(v.axiWriteSlave);
                  else
                     -- Latch the read byte
                     v.axiReadSlave.rdata(7 downto 0) := rdData(7 downto 0);
                     -- Send the response
                     axiSlaveReadResponse(v.axiReadSlave);
                  end if;
                  --- Next state
                  v.state := IDLE_S;
               else
                  --- Next state
                  v.state := REQ_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiWriteSlave <= r.axiWriteSlave;
      axiReadSlave  <= r.axiReadSlave;
      coreBusyOut   <= r.busy;
      coreRst       <= (r.rst or axiRst);

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SpiMaster : entity surf.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 24,
         CPHA_G            => '0',
         CPOL_G            => '0',
         CLK_PERIOD_G      => CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)
      port map (
         clk       => axiClk,
         sRst      => axiRst,
         chipSel   => "0",
         wrEn      => r.wrEn,
         wrData    => r.wrData,
         rdEn      => rdEn,
         rdData    => rdData,
         spiCsL(0) => coreCsb,
         spiSclk   => coreSclk,
         spiSdi    => coreSDout,
         spiSdo    => coreSDin);

end architecture rtl;
