-------------------------------------------------------------------------------
-- File       : AxiMemTester.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-28
-- Last update: 2016-07-13
-------------------------------------------------------------------------------
-- Description: General Purpose AXI4 memory tester
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
use work.AxiPkg.all;

entity AxiMemTester is
   generic (
      TPD_G            : time                     := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)          := AXI_RESP_DECERR_C;
      START_ADDR_G     : slv;
      STOP_ADDR_G      : slv;
      BURST_LEN_G      : positive range 1 to 4096 := 4096;
      AXI_CONFIG_G     : AxiConfigType);
   port (
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      memReady        : out sl;
      memError        : out sl;
      -- DDR Memory Interface
      axiClk          : in  sl;
      axiRst          : in  sl;
      start           : in  sl;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType);
end AxiMemTester;

architecture rtl of AxiMemTester is

   constant START_C      : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_ADDR_G(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
   constant START_ADDR_C : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 12) & x"000";
   constant STOP_C       : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := STOP_ADDR_G(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
   constant STOP_ADDR_C  : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := STOP_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 12) & x"000";

   constant DATA_BITS_C : natural         := 8*AXI_CONFIG_G.DATA_BYTES_C;
   constant AXI_LEN_C   : slv(7 downto 0) := getAxiLen(AXI_CONFIG_G, BURST_LEN_G);


   constant PRBS_TAPS_C : NaturalArray       := (0 => 1023, 1 => 257, 2 => 113, 3 => 61, 4 => 29, 5 => 17, 6 => 7);
   constant PRBS_SEED_C : slv(1023 downto 0) := x"AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55AA55";
   
   type StateType is (
      IDLE_S,
      WRITE_ADDR_S,
      WRITE_DATA_S,
      WRITE_RESP_S,
      READ_ADDR_S,
      READ_DATA_S,
      DONE_S,
      ERROR_S);    

   type RegType is record
      done           : sl;
      error          : sl;
      wErrResp       : sl;
      rErrResp       : sl;
      rErrData       : sl;
      wTimerEn       : sl;
      rTimerEn       : sl;
      wTimer         : slv(31 downto 0);
      rTimer         : slv(31 downto 0);
      len            : slv(7 downto 0);
      address        : slv(63 downto 0);
      randomData     : slv(1023 downto 0);
      state          : StateType;
      axiWriteMaster : AxiWriteMasterType;
      axiReadMaster  : AxiReadMasterType;
   end record;
   
   constant REG_INIT_C : RegType := (
      done           => '0',
      error          => '0',
      wErrResp       => '0',
      rErrResp       => '0',
      rErrData       => '0',
      wTimerEn       => '0',
      rTimerEn       => '0',
      wTimer         => (others => '0'),
      rTimer         => (others => '0'),
      len            => AXI_LEN_C,
      address        => (others => '0'),
      randomData     => PRBS_SEED_C,
      state          => IDLE_S,
      axiWriteMaster => AXI_WRITE_MASTER_INIT_C,
      axiReadMaster  => AXI_READ_MASTER_INIT_C);   

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal done   : sl;
   signal error  : sl;
   signal wTimer : slv(31 downto 0);
   signal rTimer : slv(31 downto 0);

   type RegLiteType is record
      memReady       : sl;
      memError       : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_LITE_INIT_C : RegLiteType := (
      memReady       => '0',
      memError       => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal rLite   : RegLiteType := REG_LITE_INIT_C;
   signal rinLite : RegLiteType;

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";
   -- attribute dont_touch of rLite : signal is "true";
   
begin

   comb : process (axiReadSlave, axiRst, axiWriteSlave, r, start) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Update output registers 
      if axiWriteSlave.awready = '1' then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if axiWriteSlave.wready = '1' then
         v.axiWriteMaster.wvalid := '0';
         v.axiWriteMaster.wlast  := '0';
      end if;
      if axiReadSlave.arready = '1' then
         v.axiReadMaster.arvalid := '0';
      end if;

      -- Check the flags
      if (r.wTimerEn = '1') and (r.wTimer /= x"FFFFFFFF") then
         v.wTimer := r.wTimer + 1;
      end if;
      if (r.rTimerEn = '1') and (r.rTimer /= x"FFFFFFFF") then
         v.rTimer := r.rTimer + 1;
      end if;

      -- State Machine
      case (r.state) is

         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check calibration to complete
            if start = '1' then
               -- Set the flags
               v.wTimerEn                                      := '1';
               v.rTimerEn                                      := '0';
               -- Latch the generator seed
               v.randomData                                    := PRBS_SEED_C;
               -- Set the start address
               v.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_ADDR_C;
               -- Next State
               v.state                                         := WRITE_ADDR_S;
            end if;
         ----------------------------------------------------------------------
         when WRITE_ADDR_S =>
            if (v.axiWriteMaster.awvalid = '0') and (axiReadSlave.rvalid = '0') then
               -- Write Address channel
               v.axiWriteMaster.awvalid := '1';
               v.axiWriteMaster.awaddr  := r.address;
               -- Next State
               v.state                  := WRITE_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when WRITE_DATA_S =>
            if (v.axiWriteMaster.awvalid = '0') and (v.axiWriteMaster.wvalid = '0') then
               -- Write Data channel
               v.axiWriteMaster.wvalid                        := '1';
               v.axiWriteMaster.wdata(DATA_BITS_C-1 downto 0) := r.randomData(DATA_BITS_C-1 downto 0);
               -- Generate next random word
               v.randomData                                   := lfsrShift(r.randomData, PRBS_TAPS_C);
               -- Increment the counter
               v.len                                          := r.len - 1;
               -- Check that all txns are done
               if r.len = 0 then
                  -- Reset the counter
                  v.len                  := AXI_LEN_C;
                  -- Set the flag
                  v.axiWriteMaster.wlast := '1';
                  -- Next State
                  v.state                := WRITE_RESP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WRITE_RESP_S =>
            -- Wait for the response
            if axiWriteSlave.bvalid = '1' then
               -- Check for "OKAY" response 
               if axiWriteSlave.bresp = "00" then
                  -- Check for max. address 
                  if r.address = STOP_ADDR_C then
                     -- Reset the start address
                     v.address                                       := (others => '0');
                     v.address(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_ADDR_C;
                     -- Set the flags
                     v.wTimerEn                                      := '0';
                     v.rTimerEn                                      := '1';
                     -- Latch the generator seed
                     v.randomData                                    := PRBS_SEED_C;
                     -- Next State
                     v.state                                         := READ_ADDR_S;
                  else
                     -- Increment the counter
                     v.address := r.address + BURST_LEN_G;
                     -- Next State
                     v.state   := WRITE_ADDR_S;
                  end if;
               else
                  -- Set the flag
                  v.wErrResp := '1';
                  -- Next State
                  v.state    := ERROR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when READ_ADDR_S =>
            if (v.axiReadMaster.arvalid = '0') and (axiReadSlave.rvalid = '0') then
               -- Write Address channel
               v.axiReadMaster.arvalid := '1';
               v.axiReadMaster.araddr  := r.address;
               -- Next State
               v.state                 := READ_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when READ_DATA_S =>
            if (v.axiReadMaster.arvalid = '0') and (axiReadSlave.rvalid = '1') then
               -- Compare the data 
               if r.randomData(DATA_BITS_C-1 downto 0) /= axiReadSlave.rdata(DATA_BITS_C-1 downto 0) then
                  -- Set the flag
                  v.rErrData := '1';
                  -- Next State
                  v.state    := ERROR_S;
               end if;
               -- Generate next random word
               v.randomData := lfsrShift(r.randomData, PRBS_TAPS_C);
               -- Check for last transfer
               if axiReadSlave.rlast = '1' then
                  if axiReadSlave.rresp = "00" then
                     -- Check for max. address 
                     if r.address = STOP_ADDR_C then
                        report "AxiMemTester: Passed Test!";
                        report "wTimer = " & integer'image(conv_integer(v.wTimer));
                        report "rTimer = " & integer'image(conv_integer(v.rTimer));
                        -- Next State
                        v.state := DONE_S;
                     else
                        -- Increment the counter
                        v.address := r.address + BURST_LEN_G;
                        -- Next State
                        v.state   := READ_ADDR_S;
                     end if;
                  else
                     -- Set the flag
                     v.rErrResp := '1';
                     -- Next State
                     v.state    := ERROR_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            v.done     := '1';
            v.error    := '0';
            v.wTimerEn := '0';
            v.rTimerEn := '0';
         ----------------------------------------------------------------------
         when ERROR_S =>
            v.done     := '0';
            v.error    := '1';
            v.wTimerEn := '0';
            v.rTimerEn := '0';
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Write Address Constants      
      v.axiWriteMaster.awid    := (others => '0');
      v.axiWriteMaster.awlen   := AXI_LEN_C;
      v.axiWriteMaster.awsize  := toSlv(log2(AXI_CONFIG_G.DATA_BYTES_C), 3);
      v.axiWriteMaster.awburst := "01";    -- Burst type = "INCR"
      v.axiWriteMaster.awlock  := (others => '0');
      v.axiWriteMaster.awprot  := (others => '0');
      v.axiWriteMaster.awcache := "1111";  -- Write-back Read and Write-allocate      
      v.axiWriteMaster.awqos   := (others => '0');
      v.axiWriteMaster.bready  := '1';
      v.axiWriteMaster.wstrb   := (others => '1');

      -- Read Address Constants (copied from Write Constants) 
      v.axiReadMaster.arid    := v.axiWriteMaster.awid;
      v.axiReadMaster.arlen   := v.axiWriteMaster.awlen;
      v.axiReadMaster.arsize  := v.axiWriteMaster.awsize;
      v.axiReadMaster.arburst := v.axiWriteMaster.awburst;
      v.axiReadMaster.arlock  := v.axiWriteMaster.awlock;
      v.axiReadMaster.arprot  := v.axiWriteMaster.awprot;
      v.axiReadMaster.arcache := v.axiWriteMaster.awcache;
      v.axiReadMaster.arqos   := v.axiWriteMaster.awqos;
      v.axiReadMaster.rready  := v.axiWriteMaster.bready;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiWriteMaster <= r.axiWriteMaster;
      axiReadMaster  <= r.axiReadMaster;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   Sync_0 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         dataIn  => r.done,
         dataOut => done);

   Sync_1 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axilClk,
         dataIn  => r.error,
         dataOut => error);      

   Sync_2 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         -- Write Ports (wr_clk domain)
         wr_clk => axiClk,
         din    => r.wTimer,
         -- Read Ports (rd_clk domain)
         rd_clk => axilClk,
         dout   => wTimer);

   Sync_3 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         -- Write Ports (wr_clk domain)
         wr_clk => axiClk,
         din    => r.rTimer,
         -- Read Ports (rd_clk domain)
         rd_clk => axilClk,
         dout   => rTimer);         

   combLite : process (axilReadMaster, axilRst, axilWriteMaster, done, error, rLite, rTimer, wTimer) is
      variable v      : RegLiteType;
      variable regCon : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := rLite;

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      axiSlaveRegisterR(regCon, x"100", 0, rLite.memReady);
      axiSlaveRegisterR(regCon, x"104", 0, rLite.memError);
      axiSlaveRegisterR(regCon, x"108", 0, wTimer);
      axiSlaveRegisterR(regCon, x"10C", 0, rTimer);
      if (AXI_CONFIG_G.ADDR_WIDTH_C <= 32) then
         axiSlaveRegisterR(regCon, x"110", 0, START_C);
         axiSlaveRegisterR(regCon, x"114", 0, x"00000000");
         axiSlaveRegisterR(regCon, x"118", 0, STOP_C);
         axiSlaveRegisterR(regCon, x"11C", 0, x"00000000");
      else
         axiSlaveRegisterR(regCon, x"110", 0, START_C(31 downto 0));
         axiSlaveRegisterR(regCon, x"114", 0, START_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 32));
         axiSlaveRegisterR(regCon, x"118", 0, STOP_C(31 downto 0));
         axiSlaveRegisterR(regCon, x"11C", 0, STOP_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 32));
      end if;
      axiSlaveRegisterR(regCon, x"120", 0, toSlv(AXI_CONFIG_G.ADDR_WIDTH_C, 32));
      axiSlaveRegisterR(regCon, x"124", 0, toSlv(AXI_CONFIG_G.DATA_BYTES_C, 32));
      axiSlaveRegisterR(regCon, x"128", 0, toSlv(AXI_CONFIG_G.ID_BITS_C, 32));

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Latch the values from Synchronizers
      v.memReady := done;
      v.memError := error;

      -- Synchronous Reset
      if (axilRst = '1') then
         v := REG_LITE_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rinLite <= v;

      -- Outputs
      axilWriteSlave <= rLite.axilWriteSlave;
      axilReadSlave  <= rLite.axilReadSlave;
      memReady       <= rLite.memReady;
      memError       <= rLite.memError;
      
   end process combLite;

   seqLite : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         rLite <= rinLite after TPD_G;
      end if;
   end process seqLite;
   
end rtl;
