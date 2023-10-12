-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: GTH RX Byte Alignment Checker module
-------------------------------------------------------------------------------
-- This file is part of 'LCLS Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS Timing Core', including this file,
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

entity GtRxAlignCheck is
   generic (
      TPD_G          : time   := 1 ns;
      GT_TYPE_G      : string := "GTHE3";   -- or GTYE3, GTHE4, GTYE4
      AXI_CLK_FREQ_G : real   := 125.0e6;
      DRP_ADDR_G     : slv(31 downto 0));
   port (
      -- Clock Monitoring
      txClk            : in  sl;
      rxClk            : in  sl;
      refClk           : in  sl;
      -- GTH Status/Control Interface
      resetIn          : in  sl;
      resetOut         : out sl;
      resetDone        : in  sl;
      resetErr         : in  sl;
      locked           : out sl;
      -- Clock and Reset
      axilClk          : in  sl;
      axilRst          : in  sl;
      -- Master AXI-Lite Interface
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Slave AXI-Lite Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end entity GtRxAlignCheck;

architecture rtl of GtRxAlignCheck is

   ----------------------------------------------------------------------
   -- GTHE3 = x"0000_0540" (DRP_ADDR=0x150, see UG576 (v1.5) on page 508)
   -- GTYE3 = x"0000_0940" (DRP_ADDR=0x250, see UG578 (v1.3) on page 396)
   -- GTHE4 = x"0000_0940" (DRP_ADDR=0x250, see UG576 (v1.5) on page 421)
   -- GTYE4 = x"0000_0940" (DRP_ADDR=0x250, see UG578 (v1.3) on page 443)
   ----------------------------------------------------------------------
   constant COMMA_ALIGN_LATENCY_OFFSET_C : slv(31 downto 0) := ite((GT_TYPE_G = "GTHE3"), x"0000_0540", x"0000_0940");
   constant COMMA_ALIGN_LATENCY_ADDR_C   : slv(31 downto 0) := (DRP_ADDR_G + COMMA_ALIGN_LATENCY_OFFSET_C);

   constant LOCK_VALUE_C : integer := 16;
   constant MASK_VALUE_C : integer := 126;

   type StateType is (
      RESET_S,
      READ_S,
      ACK_S,
      LOCKED_S);

   type RegType is record
      locked          : sl;
      rst             : sl;
      rstRetryCnt     : sl;
      override        : sl;
      rstlen          : slv(3 downto 0);
      rstcnt          : slv(3 downto 0);
      retryCnt        : slv(15 downto 0);
      tgt             : slv(6 downto 0);
      mask            : slv(6 downto 0);
      last            : slv(15 downto 0);
      sample          : Slv8Array(39 downto 0);
      sAxilWriteSlave : AxiLiteWriteSlaveType;
      sAxilReadSlave  : AxiLiteReadSlaveType;
      req             : AxiLiteReqType;
      state           : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      locked          => '0',
      rst             => '1',
      rstRetryCnt     => '0',
      override        => '0',
      rstlen          => toSlv(3, 4),
      rstcnt          => toSlv(0, 4),
      retryCnt        => toSlv(0, 16),
      tgt             => toSlv(LOCK_VALUE_C, 7),
      mask            => toSlv(MASK_VALUE_C, 7),
      last            => toSlv(0, 16),
      sample          => (others => (others => '0')),
      sAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      req             => AXI_LITE_REQ_INIT_C,
      state           => READ_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteAckType;


   signal txClkFreq  : slv(31 downto 0);
   signal rxClkFreq  : slv(31 downto 0);
   signal refClkFreq : slv(31 downto 0);

  -- attribute dont_touch              : string;
  -- attribute dont_touch of r         : signal is "TRUE";
  -- attribute dont_touch of ack       : signal is "TRUE";
  -- attribute dont_touch of txClkFreq : signal is "TRUE";
  -- attribute dont_touch of rxClkFreq : signal is "TRUE";

begin

   U_refClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXI_CLK_FREQ_G,   -- Units of Hz
         REFRESH_RATE_G => 1.0,         -- Units of Hz
         CNT_WIDTH_G    => 32)          -- Counters' width
      port map (
         -- Frequency Measurement and Monitoring Outputs (locClk domain)
         freqOut => refClkFreq,
         -- Clocks
         clkIn   => refClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_txClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXI_CLK_FREQ_G,   -- Units of Hz
         REFRESH_RATE_G => 1.0,         -- Units of Hz
         CNT_WIDTH_G    => 32)          -- Counters' width
      port map (
         -- Frequency Measurement and Monitoring Outputs (locClk domain)
         freqOut => txClkFreq,
         -- Clocks
         clkIn   => txClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_rxClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXI_CLK_FREQ_G,   -- Units of Hz
         REFRESH_RATE_G => 1.0,         -- Units of Hz
         CNT_WIDTH_G    => 32)          -- Counters' width
      port map (
         -- Frequency Measurement and Monitoring Outputs (locClk domain)
         freqOut => rxClkFreq,
         -- Clocks
         clkIn   => rxClk,
         locClk  => axilClk,
         refClk  => axilClk);

   comb : process (ack, axilRst, r, resetDone, resetErr, resetIn, rxClkFreq,
           sAxilReadMaster, sAxilWriteMaster, txClkFreq, refClkFreq) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable i      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rst         := '0';
      -- Reset the strobes
      v.rstRetryCnt := '0';

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      for i in 0 to r.sample'length-1 loop
         axiSlaveRegister(axilEp, toSlv(4*(i/4), 12), 8*(i mod 4), v.sample(i));
      end loop;
      axiSlaveRegister (axilEp, x"100", 0,  v.tgt);
      axiSlaveRegister (axilEp, x"100", 8,  v.mask);
      axiSlaveRegister (axilEp, x"100", 16, v.rstlen);
      axiSlaveRegister (axilEp, x"104", 0,  v.last);
      axiSlaveRegisterR(axilEp, x"108", 0,  txClkFreq);
      axiSlaveRegisterR(axilEp, x"10C", 0,  rxClkFreq);
      axiSlaveRegisterR(axilEp, x"110", 0,  v.locked);
      axiSlaveRegister (axilEp, x"114", 0,  v.override);
      axiSlaveRegister (axilEp, x"118", 0,  v.rstRetryCnt);
      axiSlaveRegisterR(axilEp, x"11C", 0,  v.retryCnt);
      axiSlaveRegisterR(axilEp, x"120", 0,  refClkFreq);


      -- Close out the transaction
      axiSlaveDefault(axilEp, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_OK_C);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when RESET_S =>
            -- Set the flags
            v.rst    := '1';
            v.locked := '0';
            -- Check the counter
            if (r.rstcnt = r.rstlen) then
               -- Wait for the reset transition
               if (resetDone = '0') then
                  -- Reset the counter
                  v.rstcnt := (others => '0');
                  -- Next state
                  v.state  := READ_S;
               end if;
            else
               -- Increment the counter
               v.rstcnt := r.rstcnt + 1;
            end if;
         ----------------------------------------------------------------------
         when READ_S =>
            -- Reset the flag
            v.locked := '0';
            -- Wait for the reset transition and check state of master AXI-Lite
            if (resetDone = '1') and (ack.done = '0') then
               -- Start the master AXI-Lite transaction
               v.req.request := '1';
               v.req.rnw     := '1';    -- read operation
               v.req.address := COMMA_ALIGN_LATENCY_ADDR_C;
               -- Next state
               v.state       := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- AXI-Lite transaction handshaking
            if (ack.done = '1') then
               -- Reset the flag
               v.req.request := '0';
               -- Get the index pointer
               i             := conv_integer(ack.rdData(6 downto 0));
               -- Increment the counter
               v.sample(i)   := r.sample(i) + 1;
               -- Save the last byte alignment check
               v.last        := ack.rdData(15 downto 0);
               -- Check the byte alignment
               if ( (((ack.rdData(6 downto 0) xor r.tgt) and r.mask) = toSlv(0, 7))
               or  v.override = '1') then
                  -- Next state
                  v.state := LOCKED_S;
               else
                  -- Set the flag
                  v.rst   := '1';
                  -- Next state
                  v.state := RESET_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LOCKED_S =>
            -- Set the flag (can now be reset only by an external resetIn/resetErr)
            v.locked := '1';
      ----------------------------------------------------------------------
      end case;

      -- Check for software controlled sampler reset
      if (axilEp.axiStatus.writeEnable = '1') and (sAxilWriteMaster.awaddr(8 downto 0) = toSlv(256, 9)) then
         v.sample := (others => (others => '0'));
      end if;

      -- Check for user reset
      if (resetIn = '1') or (resetErr = '1') then
         -- Setup flags for reset state
         v.rst         := '1';
         v.req.request := '0';
         -- Reset the counter
         v.rstcnt      := (others => '0');
         -- Next state
         v.state       := RESET_S;
      end if;

      -- Increment the reset retry counter (if triggered internally)
      if    (r.rstRetryCnt = '1') then
         -- Reset clause first
         v.retryCnt := (others => '0');
      elsif (v.rst = '1' and r.rst = '0' and resetIn = '0' and resetErr = '0') then
         -- Edge-triggered
         v.retryCnt := r.retryCnt + 1;
      end if;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxilReadSlave  <= r.sAxilReadSlave;
      sAxilWriteSlave <= r.sAxilWriteSlave;
      locked          <= r.locked;
      resetOut        <= r.rst;

   end process comb;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxiLiteMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave);

end rtl;
