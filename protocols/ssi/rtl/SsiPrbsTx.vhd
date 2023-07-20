-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:   This module generates
--                PseudoRandom Binary Sequence (PRBS) on Virtual Channel Lane.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiPrbsTx is
   generic (
      -- General Configurations
      TPD_G                      : time                    := 1 ns;
      RST_ASYNC_G                : boolean                 := false;
      AXI_EN_G                   : sl                      := '1';
      AXI_DEFAULT_PKT_LEN_G      : slv(31 downto 0)        := x"00000FFF";
      AXI_DEFAULT_TRIG_DLY_G     : slv(31 downto 0)        := x"00000000";
      -- FIFO Configurations
      VALID_THOLD_G              : natural                 := 1;
      VALID_BURST_MODE_G         : boolean                 := false;
      SYNTH_MODE_G               : string                  := "inferred";
      MEMORY_TYPE_G              : string                  := "block";
      GEN_SYNC_FIFO_G            : boolean                 := false;
      CASCADE_SIZE_G             : positive                := 1;
      FIFO_ADDR_WIDTH_G          : positive                := 9;
      FIFO_PAUSE_THRESH_G        : positive                := 2**8;
      FIFO_INT_WIDTH_SELECT_G    : string                  := "WIDE";
      -- PRBS Configurations
      PRBS_SEED_SIZE_G           : natural range 32 to 512 := 32;
      PRBS_TAPS_G                : NaturalArray            := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
      PRBS_INCREMENT_G           : boolean                 := false;  -- Increment mode by default instead of PRBS
      -- AXI Stream Configurations
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType;
      MASTER_AXI_PIPE_STAGES_G   : natural range 0 to 16   := 0);
   port (
      -- Master Port (mAxisClk)
      mAxisClk        : in  sl;
      mAxisRst        : in  sl;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Trigger Signal (locClk domain)
      locClk          : in  sl;
      locRst          : in  sl                     := '0';
      trig            : in  sl                     := '1';
      packetLength    : in  slv(31 downto 0)       := x"00000FFF";
      forceEofe       : in  sl                     := '0';
      busy            : out sl;
      tDest           : in  slv(7 downto 0)        := X"00";
      tId             : in  slv(7 downto 0)        := X"00";
      -- Optional: Axi-Lite Register Interface (locClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SsiPrbsTx;

architecture rtl of SsiPrbsTx is

   constant EVENT_CNT_SIZE_C : integer := minimum(PRBS_SEED_SIZE_G, 32);
   constant PRBS_BYTES_C     : natural := wordCount(PRBS_SEED_SIZE_G, 8);
   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => PRBS_BYTES_C,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => MASTER_AXI_STREAM_CONFIG_G.TKEEP_MODE_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => MASTER_AXI_STREAM_CONFIG_G.TUSER_MODE_C);

   type StateType is (
      IDLE_S,
      SEED_RAND_S,
      LENGTH_S,
      DATA_S);

   type RegType is record
      busy           : sl;
      overflow       : sl;
      length         : slv(31 downto 0);
      packetLength   : slv(31 downto 0);
      dataCnt        : slv(31 downto 0);
      trigDly        : slv(31 downto 0);
      trigDlyCnt     : slv(31 downto 0);
      eventCnt       : slv(EVENT_CNT_SIZE_C-1 downto 0);
      randomData     : slv(PRBS_SEED_SIZE_G-1 downto 0);
      txAxisMaster   : AxiStreamMasterType;
      state          : StateType;
      axiEn          : sl;
      oneShot        : sl;
      trig           : sl;
      trigger        : sl;
      cntData        : sl;
      tDest          : slv(7 downto 0);
      tId            : slv(7 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      busy           => '1',
      overflow       => '0',
      length         => (others => '0'),
      packetLength   => AXI_DEFAULT_PKT_LEN_G,
      dataCnt        => (others => '0'),
      trigDly        => AXI_DEFAULT_TRIG_DLY_G,
      trigDlyCnt     => (others => '0'),
      eventCnt       => toSlv(1, EVENT_CNT_SIZE_C),
      randomData     => (others => '0'),
      txAxisMaster   => axiStreamMasterInit(PRBS_SSI_CONFIG_C),
      state          => IDLE_S,
      axiEn          => AXI_EN_G,
      oneShot        => '0',
      trig           => '0',
      trigger        => '0',
      cntData        => toSl(PRBS_INCREMENT_G),
      tDest          => X"00",
      tId            => X"00",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;
   signal txCtrl  : AxiStreamCtrlType;

begin

   assert ((PRBS_SEED_SIZE_G = 32) or (PRBS_SEED_SIZE_G = 64) or (PRBS_SEED_SIZE_G = 128) or (PRBS_SEED_SIZE_G = 256) or (PRBS_SEED_SIZE_G = 512)) report "PRBS_SEED_SIZE_G must be either [32,64,128,256,512]" severity failure;

   comb : process (axilReadMaster, axilWriteMaster, forceEofe, locRst, packetLength, r, tDest, tId,
                   trig, txCtrl, txSlave) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      ----------------------------------------------------------------------------------------------
      -- Axi-Lite Registers
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, X"00", 0, v.axiEn);
      axiSlaveRegister(axilEp, X"00", 1, v.trig);
      axiSlaveRegisterR(axilEp, X"00", 2, r.busy);
      axiSlaveRegisterR(axilEp, X"00", 3, r.overflow);
      axiSlaveRegister(axilEp, X"00", 5, v.cntData);

      axiSlaveRegister(axilEp, X"04", 0, v.packetLength);
      axiSlaveRegister(axilEp, X"08", 0, v.tDest);
      axiSlaveRegister(axilEp, X"08", 8, v.tId);
      axiSlaveRegister(axilEp, X"0C", 0, v.dataCnt);
      axiSlaveRegister(axilEp, X"18", 0, v.oneShot);
      axiSlaveRegister(axilEp, X"1C", 0, v.trigDly);

      axiSlaveRegisterR(axilEp, X"10", 0, r.eventCnt);
      axiSlaveRegisterR(axilEp, X"14", 0, r.randomData(minimum(PRBS_SEED_SIZE_G-1, 31) downto 0));
      axiSlaveRegisterR(axilEp, X"1C", 0, r.trigDly);

      axiSlaveRegisterR(axilEp, X"20", 0, toSlv(PRBS_SEED_SIZE_G, 32));

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ----------------------------------------------------------------------------------------------
      -- PRBS Stream Logic
      ----------------------------------------------------------------------------------------------

      -- Check for delay between AXI triggers
      if (r.trigDlyCnt = r.trigDly) or (r.trigDly /= v.trigDly) then
         v.trigDlyCnt := (others => '0');
         v.trigger    := r.trig;
      elsif (r.trigger = '0') then
         v.trigDlyCnt := r.trigDlyCnt + 1;
      end if;

      -- Override axi settings if axi not enabled
      if (v.axiEn = '0') then
         v.trigger      := trig;
         v.packetLength := packetLength;
         v.tDest        := tDest;
         v.tId          := tId;
      end if;

      -- Check for overflow condition or forced EOFE
      if (txCtrl.overflow = '1') or (forceEofe = '1') then
         -- Latch the overflow error bit for the data packet
         v.overflow := '1';
      end if;

      -- Check the AXIS flow control
      if txSlave.tReady = '1' then
         v.txAxisMaster.tValid := '0';
         v.txAxisMaster.tLast  := '0';
         v.txAxisMaster.tUser  := (others => '0');
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if (r.trigger = '1') or (r.oneShot = '1') then
               -- Reset the one shot
               v.oneShot                                 := '0';
               v.trigger                                 := '0';
               -- Latch the generator seed
               v.randomData                              := (others => '0');
               v.randomData(EVENT_CNT_SIZE_C-1 downto 0) := r.eventCnt;
               -- Set the busy flag
               v.busy                                    := '1';
               -- Reset the overflow flag
               v.overflow                                := '0';
               -- Latch the configuration
               v.txAxisMaster.tDest                      := r.tDest;
               v.txAxisMaster.tId                        := r.tId;
               -- Check the packet length request value
               if r.packetLength = 0 then
                  -- Force minimum packet length of 2 (+1)
                  v.length := toSlv(2, 32);
               elsif r.packetLength = 1 then
                  -- Force minimum packet length of 2 (+1)
                  v.length := toSlv(2, 32);
               else
                  v.length := r.packetLength;
               end if;
               -- Next State
               v.state := SEED_RAND_S;
            end if;
         ----------------------------------------------------------------------
         when SEED_RAND_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the random seed word
               v.txAxisMaster.tvalid                             := '1';
               v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := (others => '0');
               v.txAxisMaster.tData(EVENT_CNT_SIZE_C-1 downto 0) := r.eventCnt;
               -- Generate the next random data word
--               for i in 0 to PRBS_SEED_SIZE_G-1 loop
               v.randomData                                      := lfsrShift(v.randomData, PRBS_TAPS_G, '0');
--               end loop;
               -- Increment the counter
               v.eventCnt                                        := r.eventCnt + 1;
               -- Increment the counter
               v.dataCnt                                         := r.dataCnt + 1;
               -- Set the SOF bit
               ssiSetUserSof(PRBS_SSI_CONFIG_C, v.txAxisMaster, '1');
               -- Next State
               v.state                                           := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the upper packetLength value
               v.txAxisMaster.tvalid             := '1';
               v.txAxisMaster.tData              := (others => '0');
               v.txAxisMaster.tData(31 downto 0) := r.length;
               -- Increment the counter
               v.dataCnt                         := r.dataCnt + 1;
               -- Next State
               v.state                           := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if the FIFO is ready
            if v.txAxisMaster.tvalid = '0' then
               -- Send the random data word
               v.txAxisMaster.tValid := '1';
               -- Check if we are sending PRBS or counter data
               if r.cntData = '0' then
                  -- PRBS data
                  v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := r.randomData;
               else
                  -- Counter data
                  v.txAxisMaster.tData(PRBS_SEED_SIZE_G-1 downto 0) := (others => '0');
                  v.txAxisMaster.tData(31 downto 0)                 := r.dataCnt;
               end if;
               -- Generate the next random data word
--               for i in 0 to PRBS_SEED_SIZE_G-1 loop
               v.randomData := lfsrShift(v.randomData, PRBS_TAPS_G, '0');
--               end loop;
               -- Increment the counter
               v.dataCnt    := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.length then
                  -- Reset the counter
                  v.dataCnt            := (others => '0');
                  -- Set the EOF bit
                  v.txAxisMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(PRBS_SSI_CONFIG_C, v.txAxisMaster, r.overflow);
                  -- Reset the busy flag
                  v.busy               := '0';
                  -- Next State
                  v.state              := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (RST_ASYNC_G = false and locRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      busy           <= r.busy;
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (locClk, locRst) is
   begin
      if (RST_ASYNC_G) and (locRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_Inst : entity surf.AxiStreamFifoV2
      generic map(
         -- General Configurations
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => MASTER_AXI_PIPE_STAGES_G,
         PIPE_STAGES_G       => MASTER_AXI_PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => VALID_THOLD_G,
         VALID_BURST_MODE_G  => VALID_BURST_MODE_G,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         INT_WIDTH_SELECT_G  => FIFO_INT_WIDTH_SELECT_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => r.txAxisMaster,
         sAxisSlave  => txSlave,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
