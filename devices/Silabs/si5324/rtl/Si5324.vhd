-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Datasheet: https://www.silabs.com/documents/public/data-sheets/Si5324.pdf
-- Manual:    https://www.silabs.com/documents/public/reference-manuals/si53xx-reference-manual.pdf
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

library unisim;
use unisim.vcomponents.all;

entity Si5324 is
   generic (
      TPD_G              : time   := 1 ns;
      MEMORY_INIT_FILE_G : string := "none";  -- Used to initialization boot ROM
      CLK_PERIOD_G       : real   := (1.0/156.25E+6);
      SPI_SCLK_PERIOD_G  : real   := (1.0/5.0E+6));
   port (
      -- Clock and Reset
      axilClk         : in  sl;
      axilRst         : in  sl;
      -- AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Status Interface
      booting         : out sl;
      -- Chip Interface
      rstL            : out sl;
      rate            : out slv(1 downto 0);  -- Reference Clock Rate = MM (109 to 125.5 MHz XTAL)
      cmode           : out sl;         -- SPI control mode (CMODE = 1)
      csL             : out sl;         -- Chip Select
      sclk            : out sl;         -- Serial Clock
      mosi            : out sl;         -- Serial Data In
      miso            : in  sl);        -- Serial Data Out
end entity Si5324;

architecture rtl of Si5324 is

   constant BOOT_ROM_C : boolean := (MEMORY_INIT_FILE_G /= "none");

   constant DLY_C : natural := 8*integer(SPI_SCLK_PERIOD_G/CLK_PERIOD_G);  -- >= 4 SCLK delay between SPI cycles

   type StateType is (
      BOOT_ROM_S,
      IDLE_S,
      INIT_S,
      REQ_S,
      ACK_S,
      DONE_S);

   type RegType is record
      axilRd         : sl;
      wrEn           : sl;
      wrData         : slv(15 downto 0);
      data           : slv(7 downto 0);
      addr           : slv(7 downto 0);
      timer          : natural range 0 to DLY_C;
      cnt            : natural range 0 to 1;
      wrArray        : Slv16Array(1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      ramAddr        : slv(8 downto 0);
      booting        : sl;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilRd         => '0',
      wrEn           => '0',
      wrData         => (others => '0'),
      data           => (others => '0'),
      addr           => (others => '0'),
      timer          => 0,
      cnt            => 0,
      wrArray        => (others => (others => '0')),
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      ramAddr        => (others => '0'),
      booting        => ite(BOOT_ROM_C, '1', '0'),
      state          => BOOT_ROM_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal freeRunClk : sl;
   signal rdEn       : sl;
   signal rdData     : slv(15 downto 0);

   signal ramData : slv(15 downto 0) := (others => '0');

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";
   -- attribute dont_touch of freeRunClk : signal is "TRUE";
   -- attribute dont_touch of rdEn       : signal is "TRUE";
   -- attribute dont_touch of rdData     : signal is "TRUE";

begin

   GEN_BOOT_ROM : if BOOT_ROM_C generate
      U_ROM : entity surf.SimpleDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            COMMON_CLK_G        => true,
            MEMORY_TYPE_G       => "block",
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => "",
            READ_LATENCY_G      => 1,
            DATA_WIDTH_G        => 16,
            ADDR_WIDTH_G        => 9)
         port map (
            -- Port A
            clka  => axilClk,
            -- Port B
            clkb  => axilClk,
            addrb => r.ramAddr,
            doutb => ramData);
   end generate;

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, ramData,
                   rdData, rdEn) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      if (rdEn = '0') then
         v.wrEn := '0';
      end if;

      -- Increment the timer
      if (r.timer /= DLY_C) then
         v.timer := r.timer + 1;
      end if;

      -- Get the AXI-Lite status
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when BOOT_ROM_S =>
            -- Set the flag
            v.axilRd  := '0';
            -- Save the data/address
            v.data    := ramData(7 downto 0);
            v.addr    := ramData(15 downto 8);
            -- Increment the counter
            v.ramAddr := r.ramAddr + 1;
            -- Check for empty transaction or roll over of counter
            if (ramData /= 0) and (v.ramAddr /= 0) then
               -- Next State
               v.state := INIT_S;
            else
               -- Reset the counter
               v.ramAddr := (others => '0');
               -- Reset the flag
               v.booting := '0';
               -- Next State
               v.state   := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the timer
            v.timer := 0;
            -- Check if write transaction
            if (axilStatus.writeEnable = '1') then
               -- Set the flag
               v.axilRd := '0';
               -- Save the data/address
               v.data   := axilWriteMaster.wdata(7 downto 0);
               v.addr   := axilWriteMaster.awaddr(9 downto 2);
               -- Send the write response
               axiSlaveWriteResponse(v.axilWriteSlave);
               -- Next State
               v.state  := INIT_S;
            -- Check if read transaction
            elsif (axilStatus.readEnable = '1') then
               -- Set the flag
               v.axilRd := '1';
               -- Save the address
               v.addr   := axilReadMaster.araddr(9 downto 2);
               -- Next State
               v.state  := INIT_S;
            end if;
         ----------------------------------------------------------------------
         when INIT_S =>
            -----------------------------------------------------------------
            -- Refer to Si53xx-RM Family Reference Manual
            -- In Section 6.14. Serial Microprocessor Interface (SPI)
            -----------------------------------------------------------------
            -- Set the address
            v.wrArray(0) := x"00" & r.addr;
            -- Check if write transaction
            if (r.axilRd = '0') then
               -- Write Data
               v.wrArray(1) := x"40" & r.data;
            else
               -- Read Data
               v.wrArray(1) := x"80" & x"FF";
            end if;
            -- Next State
            v.state := REQ_S;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check for min. chip select gap
            if (r.timer = DLY_C) then
               -- Start the transaction
               v.wrEn   := '1';
               v.wrData := r.wrArray(r.cnt);
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
               if (r.cnt = 1) then
                  -- Reset the counter
                  v.cnt := 0;
                  -- Check if read transaction type
                  if (r.axilRd = '1') then
                     -- Latch the read byte
                     v.axilReadSlave.rdata(7 downto 0) := rdData(7 downto 0);
                     -- Send the response
                     axiSlaveReadResponse(v.axilReadSlave);
                  end if;
                  --- Next state
                  v.state := DONE_S;
               else
                  -- Increment the counter
                  v.cnt   := r.cnt + 1;
                  --- Next state
                  v.state := REQ_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Check for min. chip select gap
            if (r.timer = DLY_C) then
               -- Check if booting
               if (r.booting = '1') then
                  --- Next state
                  v.state := BOOT_ROM_S;
               else
                  --- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      rstL           <= not(axilRst);
      cmode          <= '1';
      booting        <= r.booting;
      if (r.state = IDLE_S) or (r.state = BOOT_ROM_S) then
         freeRunClk <= '0';
      else
         freeRunClk <= '1';
      end if;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
         if BOOT_ROM_C then
            v.state := BOOT_ROM_S;
         else
            v.state := IDLE_S;
         end if;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SpiMaster : entity surf.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 16,
         CPHA_G            => '0',
         CPOL_G            => '0',
         CLK_PERIOD_G      => CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)
      port map (
         clk        => axilClk,
         sRst       => axilRst,
         chipSel    => "0",
         freeRunClk => freeRunClk,
         wrEn       => r.wrEn,
         wrData     => r.wrData,
         rdEn       => rdEn,
         rdData     => rdData,
         spiCsL(0)  => csL,
         spiSclk    => sclk,
         spiSdi     => mosi,
         spiSdo     => miso);

   GEN_RATE :
   for i in 1 downto 0 generate
      U_OBUFT : OBUFT
         port map (
            I => '1',
            T => '1',
            O => rate(i));
   end generate GEN_RATE;

end rtl;
