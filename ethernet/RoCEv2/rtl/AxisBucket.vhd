-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: TokenBucket implementation in Axi-Stream
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxisBucket is

   generic (
      TPD_G          : time             := 1 ns;
      RST_ASYNC_G    : boolean          := false;
      PIPE_STAGES_G  : natural          := 0;
      RST_POLARITY_G : sl               := '1';
      FRAC_BITS_G    : natural          := 16;
      BUCKET_SIZE_G  : slv(31 downto 0) := x"10000000";  -- in bytes
      AXIS_CONFIG_G  : AxiStreamConfigType
   );

   port (
      axisClk      : in  sl;
      axisRst      : in  sl;
      byte_per_clk : in  slv(15 + FRAC_BITS_G downto 0);  -- Q16.16
      packet_size  : in  slv(31 downto 0);
      rd_en        : out sl;
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType
      );
end entity AxisBucket;

architecture rtl of AxisBucket is

   type FrameState is (
      IDLE_S,
      READ_S
   );

   type RegType is record
      state      : FrameState;
      armed      : sl;
      count      : slv(31 + FRAC_BITS_G downto 0);
      go_idle    : boolean;
      axisSlave  : AxiStreamSlaveType;
      axisMaster : AxiStreamMasterType;
      rd_en      : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      armed      => '0',
      count      => (others => '0'),
      go_idle    => false,
      axisSlave  => AXI_STREAM_SLAVE_INIT_C,
      axisMaster => axiStreamMasterInit(AXIS_CONFIG_G),
      rd_en      => '0'
      );
   constant BUCKET_FRAC_C      : slv(FRAC_BITS_G-1 downto 0)    := (others => '0');
   constant BUCKET_SIZE_FULL_C : slv(31 + FRAC_BITS_G downto 0) := BUCKET_SIZE_G & BUCKET_FRAC_C;

   signal r              : RegType := REG_INIT_C;
   signal rin            : RegType;
   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin  -- architecture rtl

   comb : process (axisRst, byte_per_clk, packet_size, pipeAxisSlave, r,
                   sAxisMaster) is
      variable v                     : RegType;
      variable packetSizeFull        : slv(31 + FRAC_BITS_G downto 0);
      variable fracBitsForPacketSize : slv(FRAC_BITS_G-1 downto 0);
   begin  -- process comb
      -- Latch the current value
      v := r;

      -- Init
      v.axisSlave.tReady := '0';
      v.rd_en            := '0';

      -- Set fixed point arithmetic
      fracBitsForPacketSize := (others => '0');
      packetSizeFull        := packet_size & fracBitsForPacketSize;

      -- Choose ready source and clear valid
      if (pipeAxisSlave.tReady = '1') then
         v.axisMaster.tValid := '0';
         if r.go_idle then
            v.go_idle := false;
            v.state   := IDLE_S;
         end if;
      end if;

      -- FSM
      case r.state is
         -------------------------------------------------------------------------
         when IDLE_S =>
            v.axisMaster := axiStreamMasterInit(AXIS_CONFIG_G);
            if sAxisMaster.tValid = '1' and r.count >= packetSizeFull then
               v.rd_en := '1';
               v.state := READ_S;
            end if;
            if r.armed = '0' then
               v.state := READ_S;
            end if;
         when READ_S =>
            if v.axisMaster.tValid = '0' and r.go_idle = false then
               v.axisMaster       := sAxisMaster;
               v.axisSlave.tReady := '1';
               if v.axisMaster.tValid = '1' and v.axisMaster.tLast = '1' then
                  v.armed   := '1';
                  v.go_idle := true;
               end if;
            end if;
      -----------------------------------------------------------------------
      end case;

      -- Increase bucket every clock cycle
      if BUCKET_SIZE_FULL_C - r.count > byte_per_clk then
         v.count := r.count + byte_per_clk;
      else
         v.count := BUCKET_SIZE_FULL_C;
      end if;

      if v.rd_en = '1' then
         v.count := v.count - packetSizeFull;
      end if;

      -- Outputs
      pipeAxisMaster <= r.axisMaster;
      sAxisSlave     <= v.axisSlave;
      rd_en          <= v.rd_en;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

-- Optional output pipeline registers to ease timing
   AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
