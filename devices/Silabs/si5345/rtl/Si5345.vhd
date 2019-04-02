-------------------------------------------------------------------------------
-- File       : Si5345.vhd
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity Si5345 is
   generic (
      TPD_G             : time := 1 ns;
      CLK_PERIOD_G      : real := (1.0/156.25E+6);
      SPI_SCLK_PERIOD_G : real := (1.0/10.0E+6));
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
      coreRst        : out sl;
      coreSclk       : out sl;
      coreSDin       : in  sl;
      coreSDout      : out sl;
      coreCsb        : out sl);
end entity Si5345;

architecture rtl of Si5345 is

   constant DLY_C : natural := 4*integer(SPI_SCLK_PERIOD_G/CLK_PERIOD_G);  -- >= 2 SCLK delay between SPI cycles

   type StateType is (
      IDLE_S,
      INIT_S,
      REQ_S,
      ACK_S,
      DONE_S);

   type RegType is record
      axiRd         : sl;
      wrEn          : sl;
      wrData        : slv(15 downto 0);
      data          : slv(7 downto 0);
      addr          : slv(7 downto 0);
      page          : slv(7 downto 0);
      timer         : natural range 0 to DLY_C;
      cnt           : natural range 0 to 4;
      wrArray       : Slv16Array(3 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      state         : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axiRd         => '0',
      wrEn          => '0',
      wrData        => (others => '0'),
      data          => (others => '0'),
      addr          => (others => '0'),
      page          => (others => '0'),
      timer         => 0,
      cnt           => 0,
      wrArray       => (others => (others => '0')),
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal freeRunClk : sl;
   signal rdEn       : sl;
   signal rdData     : slv(15 downto 0);

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";
   -- attribute dont_touch of freeRunClk : signal is "TRUE";
   -- attribute dont_touch of rdEn       : signal is "TRUE";
   -- attribute dont_touch of rdData     : signal is "TRUE";

begin

   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, rdData, rdEn) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
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
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the timer
            v.timer := 0;
            -- Check if write transaction
            if (axiStatus.writeEnable = '1') then
               -- Set the flag
               v.axiRd := '0';
               -- Save the data/address
               v.data  := axiWriteMaster.wdata(7 downto 0);
               v.addr  := axiWriteMaster.awaddr(9 downto 2);
               v.page  := x"0" & axiWriteMaster.awaddr(13 downto 10);
               -- Send the write response
               axiSlaveWriteResponse(v.axiWriteSlave);
               -- Next State
               v.state := INIT_S;
            -- Check if read transaction      
            elsif (axiStatus.readEnable = '1') then
               -- Set the flag
               v.axiRd := '1';
               -- Save the address
               v.addr  := axiReadMaster.araddr(9 downto 2);
               v.page  := x"0" & axiReadMaster.araddr(13 downto 10);
               -- Next State
               v.state := INIT_S;
            end if;
         ----------------------------------------------------------------------
         when INIT_S =>
            -----------------------------------------------------------------
            -- Refer to Si5345, Si5344, Si5342 Rev. D Family Reference Manual
            -- In Section 9.2 SPI Interface
            -----------------------------------------------------------------
            -- Set the address to page location
            v.wrArray(0) := x"00" & x"01";
            -- Write the page location
            v.wrArray(1) := x"40" & r.page;
            -- Set the address location within the page
            v.wrArray(2) := x"00" & r.addr;
            -- Check if write transaction 
            if (r.axiRd = '0') then
               -- Write Data
               v.wrArray(3) := x"40" & r.data;
            else
               -- Read Data
               v.wrArray(3) := x"80" & x"FF";
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
               -- Increment the counter
               v.cnt    := r.cnt + 1;               
               -- Check for last transaction
               if (r.cnt = 3) then
                  -- Reset the counter
                  v.cnt := 0;
                  -- Check if read transaction type
                  if (r.axiRd = '1') then
                     -- Latch the read byte
                     v.axiReadSlave.rdata(7 downto 0) := rdData(7 downto 0);
                     -- Send the response 
                     axiSlaveReadResponse(v.axiReadSlave);
                  end if;
                  --- Next state
                  v.state := DONE_S;
               else
                  --- Next state
                  v.state := REQ_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Check for min. chip select gap
            if (r.timer = DLY_C) then
               --- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs 
      axiWriteSlave <= r.axiWriteSlave;
      axiReadSlave  <= r.axiReadSlave;
      coreRst       <= axiRst;
      if (r.state = IDLE_S) then
         freeRunClk <= '0';
      else
         freeRunClk <= '1';
      end if;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SpiMaster : entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 16,
         CPHA_G            => '0',
         CPOL_G            => '0',
         CLK_PERIOD_G      => CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)
      port map (
         clk        => axiClk,
         sRst       => axiRst,
         chipSel    => "0",
         freeRunClk => freeRunClk,
         wrEn       => r.wrEn,
         wrData     => r.wrData,
         rdEn       => rdEn,
         rdData     => rdData,
         spiCsL(0)  => coreCsb,
         spiSclk    => coreSclk,
         spiSdi     => coreSDout,
         spiSdo     => coreSDin);

end architecture rtl;
