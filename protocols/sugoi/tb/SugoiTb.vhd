-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the SugoiTopTb module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity SugoiTopTb is end SugoiTopTb;

architecture testbed of SugoiTopTb is

   constant NUM_ASIC_C      : positive := 4;
   constant NUM_ADDR_BITS_C : positive := 28;
   constant ADDR_STRIDE_C   : positive := (2**NUM_ADDR_BITS_C);

   constant CLK_PERIOD_G : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_G/4;

   signal axilClk         : sl                     := '0';
   signal axilRst         : sl                     := '0';
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

   signal clkInP : slv(NUM_ASIC_C-1 downto 0) := (others => '0');
   signal clkInN : slv(NUM_ASIC_C-1 downto 0) := (others => '1');

   signal clkOutP : slv(NUM_ASIC_C-1 downto 0) := (others => '0');
   signal clkOutN : slv(NUM_ASIC_C-1 downto 0) := (others => '1');

   signal rxP : slv(NUM_ASIC_C-1 downto 0) := (others => '0');
   signal rxN : slv(NUM_ASIC_C-1 downto 0) := (others => '1');

   signal txP : slv(NUM_ASIC_C-1 downto 0) := (others => '0');
   signal txN : slv(NUM_ASIC_C-1 downto 0) := (others => '1');

   signal linkup : slv(NUM_ASIC_C downto 0) := (others => '0');

   signal globalRst  : slv(NUM_ASIC_C-1 downto 0) := (others => '0');
   signal globalRstL : slv(NUM_ASIC_C-1 downto 0) := (others => '0');

   signal opCode       : Slv8Array(NUM_ASIC_C-1 downto 0) := (others => (others => '0'));
   signal opCodeBit    : sl                               := '0';
   signal opCodeBitSel : natural                          := 0;

   signal fpgaGlobalRst  : sl              := '0';
   signal fpgaOpCode     : slv(7 downto 0) := (others => '0');
   signal fpgaOpCodeMask : slv(7 downto 0) := (others => '0');
   signal fpgaStrobe     : sl              := '0';

   signal startTrigTraffic : sl              := '0';
   signal trafficOpCode    : slv(7 downto 0) := (others => '0');

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_G,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => axilClk,
         rst  => axilRst);

   GEN_ASIC :
   for i in 0 to NUM_ASIC_C-1 generate

      U_SimModel : entity surf.SugoiAsicSimModel
         generic map (
            TPD_G           => TPD_G,
            NUM_ADDR_BITS_G => NUM_ADDR_BITS_C)
         port map (
            -- SUGOI Serial Ports
            clkInP  => clkInP(i),
            clkInN  => clkInN(i),
            rxP     => rxP(i),
            rxN     => rxN(i),
            txP     => txP(i),
            txN     => txN(i),
            clkOutP => clkOutP(i),
            clkOutN => clkOutN(i),
            -- Link Status
            linkup  => linkup(i),
            --Global Resets
            rst     => globalRst(i),
            rstL    => globalRstL(i),
            -- Trigger/Timing Command Bus
            opCode  => opCode(i));

      CHAIN_DEV : if (i /= 0) generate

         -- Daisy Chain Clock
         clkInP(i) <= clkOutP(i-1);
         clkInN(i) <= clkOutN(i-1);

         -- Daisy Chain Data
         rxP(i) <= txP(i-1);
         rxN(i) <= txN(i-1);

      end generate;

   end generate GEN_ASIC;

   U_Fpga : entity surf.SugoiFpgaCore
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => true,
         NUM_ADDR_BITS_G => NUM_ADDR_BITS_C,
         XIL_DEVICE_G    => "ULTRASCALE")
      port map (
         -- SUGOI Serial Ports
         sugioRxP        => txP(NUM_ASIC_C-1),
         sugioRxN        => txN(NUM_ASIC_C-1),
         sugioTxP        => rxP(0),
         sugioTxN        => rxN(0),
         sugioClkP       => clkInP(0),
         sugioClkN       => clkInN(0),
         -- Timing and Trigger Interface (timingClk domain)
         timingClk       => axilClk,
         timingRst       => axilRst,
         sugioGlobalRst  => fpgaGlobalRst,
         sugioOpCode     => fpgaOpCodeMask,
         sugioStrobe     => fpgaStrobe,
         sugioLinkup     => linkup(NUM_ASIC_C),
         -- AXI-Lite Master Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   fpgaOpCodeMask <= fpgaOpCode or trafficOpCode;

   opCodeBit <= opCode(0)(opCodeBitSel);

   gen_trig_traffic : process is
      variable idx : slv(2 downto 0) := (others => '0');
      variable i   : natural;
   begin
      wait until startTrigTraffic = '1';

      while (true) loop

         -- Increment counter
         idx := idx + 1;

         -- Toggle the bit
         wait until axilClk'event and axilClk = '1';
         trafficOpCode(conv_integer(idx)) <= '1';
         wait until axilClk'event and axilClk = '1';
         trafficOpCode(conv_integer(idx)) <= '0';

         -- Wait 7 strobes (random prime number, not power of 2)
         for i in 0 to 6 loop
            wait until fpgaStrobe'event and fpgaStrobe = '1';
         end loop;

      end loop;

   end process gen_trig_traffic;

   ------------------------
   -- Code Converge Testing
   ------------------------
   test : process is
      variable addr   : slv(31 downto 0) := (others => '0');
      variable wrData : slv(31 downto 0) := (others => '0');
      variable rdData : slv(31 downto 0) := (others => '0');
      variable i      : natural;
      variable j      : natural;
   begin
      -- Wait for the AXI-Lite reset to complete
      wait until axilRst = '1';
      wait until axilRst = '0';

      -- Wait for all links to be established
      wait until uAnd(linkup) = '1';

      ------------------------
      -- Firmware Global Reset
      ------------------------
      fpgaGlobalRst <= '1';
      wait until globalRst(0)'event and globalRst(0) = '1';
      fpgaGlobalRst <= '0';
      wait until globalRst(0)'event and globalRst(0) = '0';

      ------------------------
      -- Software Global Reset
      ------------------------
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"0000_0028", x"0000_0001", true);
      wait until globalRst(0)'event and globalRst(0) = '1';
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"0000_0028", x"0000_0000", true);
      wait until globalRst(0)'event and globalRst(0) = '0';

      -----------------------------------------
      -- Validate the trigger op-code interface
      -----------------------------------------
      for i in 0 to 7 loop

         -- Address the opcode bit to use for opCodeBit'event
         opCodeBitSel <= i;

         --------------------------
         -- Firmware Trigger Opcode
         --------------------------
         wait until axilClk'event and axilClk = '1';
         fpgaOpCode(i) <= '1';
         wait until axilClk'event and axilClk = '1';
         fpgaOpCode(i) <= '0';
         wait until opCodeBit'event and opCodeBit = '1';

         --------------------------
         -- Software Trigger Opcode
         --------------------------
         axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"0000_002C", toSlv(2**i, 32), true);
         wait until opCodeBit'event and opCodeBit = '1';

      end loop;

      -----------------------------------------------------------
      -- Enable the trigger opcode traffic during register access
      -----------------------------------------------------------
      startTrigTraffic <= '1';

      -----------------------------
      -- Local FPGA register Access
      -----------------------------
      addr   := x"0000_0018";
      wrData := x"0000_00AA";
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, addr, wrData, true);
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, addr, rdData, true);
      -- Verify the TXN
      if (wrData /= rdData) then
         assert false report "Simulation Failed!" severity failure;
      end if;

      ------------------------------------
      --  None 32-bit word address aligned
      ------------------------------------
      addr   := toSlv(ADDR_STRIDE_C+5, 32);  -- address not 32-bit word address aligned
      wrData := x"BABE_CAFE";
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, addr, wrData, true);
      -- Verify the bus error
      if (axilWriteSlave.bresp = 0) then
         assert false report "Simulation Failed: 32-bit write address alignment!" severity failure;
      end if;
      axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, addr, rdData, true);
      -- Verify the bus error
      if (axilReadSlave.rresp = 0) then
         assert false report "Simulation Failed: 32-bit read address alignment!" severity failure;
      end if;

      -------------------------------------------------
      -- Read and Write to ASICs' AxiVersion scratchpad
      -------------------------------------------------
      for i in 0 to NUM_ASIC_C-1 loop
         -- Sweep the byte positions
         for j in 0 to 3 loop

            ------------------------------------------------
            -- Sweeping the data byte field in SUGIO payload
            ------------------------------------------------
            addr   := toSlv((i+1)*ADDR_STRIDE_C+4, 32);
            wrData := toSlv(2**(8*j)+i, 32);
            axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, addr, wrData, true);
            axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, addr, rdData, true);

            -- Verify the the TXN
            if (wrData /= rdData) then
               assert false report "Simulation Failed: Data Byte sweep!" severity failure;
            end if;

            ---------------------------------------------------
            -- Sweeping the address byte field in SUGIO payload
            ---------------------------------------------------
            addr := toSlv((i+1)*ADDR_STRIDE_C+(ADDR_STRIDE_C/2)+4*(2**(8*j)), 32);
            axiLiteBusSimRead (axilClk, axilReadMaster, axilReadSlave, addr, rdData, true);

            -- Verify the the TXN
            if (addr(NUM_ADDR_BITS_C-1 downto 0) /= rdData(NUM_ADDR_BITS_C-1 downto 0)) then
               assert false report "Simulation Failed: Address Byte sweep!" severity failure;
            end if;

         end loop;
      end loop;

      -- Simulation Pass testing
      assert false report "Simulation Passed!" severity failure;

   end process test;

end testbed;
