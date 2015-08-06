-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiMemTester.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-28
-- Last update: 2015-08-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      TPD_G        : time := 1 ns;
      START_ADDR_G : slv;
      STOP_ADDR_G  : slv;
      AXI_CONFIG_G : AxiConfigType);
   port (
      -- AXI-Lite Interface
      axiLiteClk         : in  sl;
      axiLiteRst         : in  sl;
      axiLiteReadMaster  : in  AxiLiteReadMasterType;
      axiLiteReadSlave   : out AxiLiteReadSlaveType;
      axiLiteWriteMaster : in  AxiLiteWriteMasterType;
      axiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      memReady           : out sl;
      memError           : out sl;
      -- DDR Memory Interface
      axiClk             : in  sl;
      axiRst             : in  sl;
      start              : in  sl;
      axiWriteMaster     : out AxiWriteMasterType;
      axiWriteSlave      : in  AxiWriteSlaveType;
      axiReadMaster      : out AxiReadMasterType;
      axiReadSlave       : in  AxiReadSlaveType);
end AxiMemTester;

architecture rtl of AxiMemTester is

   constant START_C         : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_ADDR_G(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
   constant START_ADDR_C    : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := START_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 12) & x"000";
   constant STOP_C          : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := STOP_ADDR_G(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0);
   constant STOP_ADDR_C     : slv(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 0) := STOP_C(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto 12) & x"000";

   constant DATA_BITS_C : natural := 8*AXI_CONFIG_G.DATA_BYTES_C;
   constant BURST_LEN_C : natural := (4096/AXI_CONFIG_G.DATA_BYTES_C);  -- 4kB boundary

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
      len            : natural range 0 to BURST_LEN_C;
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
      len            => 0,
      address        => (others => '0'),
      randomData     => PRBS_SEED_C,
      state          => IDLE_S,
      axiWriteMaster => AXI_WRITE_MASTER_INIT_C,
      axiReadMaster  => AXI_READ_MASTER_INIT_C);   

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";
   
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
               v.len                                          := r.len + 1;
               -- Check the counter size
               if r.len = BURST_LEN_C-1 then
                  -- Reset the counter
                  v.len                  := 0;
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
                     v.address                                       := (others=>'0');
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
                     v.address := r.address + 4096;
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
                        -- Next State
                        v.state := DONE_S;
                     else
                        -- Increment the counter
                        v.address := r.address + 4096;
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
      v.axiWriteMaster.awlen   := toSlv(BURST_LEN_C-1, 8);
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

   U_AxiLiteEmpty : entity work.AxiLiteEmpty
      generic map (
         TPD_G => TPD_G)
      port map (
         axiClk         => axiLiteClk,
         axiClkRst      => axiLiteRst,
         axiReadMaster  => axiLiteReadMaster,
         axiReadSlave   => axiLiteReadSlave,
         axiWriteMaster => axiLiteWriteMaster,
         axiWriteSlave  => axiLiteWriteSlave);  

   Sync_0 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axiLiteClk,
         dataIn  => r.done,
         dataOut => memReady);

   Sync_1 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axiLiteClk,
         dataIn  => r.error,
         dataOut => memError);         

end rtl;
