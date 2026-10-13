-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Frozen changing scalars and two coherent snapshot word banks.
-- Capture latches the common pre-edge scalar cohort. A bounded serial copy
-- fills the inactive RAM bank while software keeps reading the old bank.
-- Prepared acknowledges the drained copy; publish switches the whole cohort.
-- AXI-only reset cancels read responses without canceling accepted snapshots.
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
use ieee.numeric_std.all;
library surf;
use surf.StdRtlPkg.all;
use surf.PtpPkg.all;
use surf.PtpRegisterPkg.all;

entity PtpSnapshotBank is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      WORDS_G        : positive := 1);
   port (
      clk      : in sl;
      rst      : in sl;
      scalars  : in Slv32Array(0 to WORDS_G-1);
      snapshot : in PtpSnapshotControlType;
      prepared : out sl;
      master   : in PtpRegisterMasterType;
      slave    : out PtpRegisterSlaveType);
end entity PtpSnapshotBank;

architecture rtl of PtpSnapshotBank is

   constant ADDR_BITS_C : positive := log2(2*WORDS_G);

   type ReadStateType is (IDLE_S, WAIT_S, READ_S);

   type RegType is record
      state        : ReadStateType;
      frozen       : Slv32Array(0 to WORDS_G-1);
      copying      : sl;
      index        : natural range 0 to WORDS_G;
      bank         : natural range 0 to 1;
      pendingBank  : natural range 0 to 1;
      valid        : sl;
      prepared     : sl;
      readValid    : sl;
      discard      : sl;
      response     : PtpRegisterSlaveType;
      readEnable   : sl;
      readAddress  : slv(ADDR_BITS_C-1 downto 0);
      writeEnable  : sl;
      writeAddress : slv(ADDR_BITS_C-1 downto 0);
      writeData    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      frozen       => (others => (others => '0')),
      copying      => '0',
      index        => 0,
      bank         => 0,
      pendingBank  => 1,
      valid        => '0',
      prepared     => '1',
      readValid    => '0',
      discard      => '0',
      response     => PTP_REGISTER_SLAVE_INIT_C,
      readEnable   => '0',
      readAddress  => (others => '0'),
      writeEnable  => '0',
      writeAddress => (others => '0'),
      writeData    => (others => '0'));

   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal readData : slv(31 downto 0);

begin

   U_Ram : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => ADDR_BITS_C,
         COMMON_CLK_G   => true,
         MEMORY_TYPE_G  => "distributed",
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,
         ena   => r.writeEnable,
         wea   => r.writeEnable,
         addra => r.writeAddress,
         dina  => r.writeData,
         clkb  => clk,
         rstb  => rst,
         enb   => r.readEnable,
         addrb => r.readAddress,
         doutb => readData);

   comb : process(all) is
      variable v : RegType;
   begin
      v := r;
      v.writeEnable := '0';
      v.readEnable := '0';
      v.response.ready := '0';

      if master.responseReady = '1' then
         v.response.responseValid := '0';
      end if;

      if r.copying = '1' then
         if r.index = WORDS_G then
            v.copying := '0';
            v.prepared := '1';
         else
            v.writeEnable := '1';
            v.writeAddress := toSlv(r.pendingBank*WORDS_G+r.index, ADDR_BITS_C);
            v.writeData := r.frozen(r.index);
            v.index := r.index+1;
         end if;
      end if;

      if snapshot.capture = '1' then
         v.frozen := scalars;
         v.copying := '1';
         v.index := 0;
         v.prepared := '0';
         v.pendingBank := 1-r.bank;
      end if;

      if snapshot.publish = '1' then
         v.bank := r.pendingBank;
         v.valid := '1';
      end if;

      case r.state is
         when IDLE_S =>

            if master.valid = '1' and master.cancel = '0' and r.response.responseValid = '0' and
               to_integer(unsigned(master.index)) < WORDS_G then
               v.response.ready := '1';
               v.discard := '0';
               v.readValid := r.valid;
               v.readEnable := '1';
               v.readAddress := toSlv(r.bank*WORDS_G+to_integer(unsigned(master.index)), ADDR_BITS_C);
               v.state := WAIT_S;
            end if;

         when WAIT_S =>
            v.state := READ_S;
         when READ_S =>
            v.response.data := (others => '0');

            if r.readValid = '1' then
               v.response.data := readData;
            end if;

            v.response.responseValid := not r.discard;
            v.state := IDLE_S;
      end case;

      if master.cancel = '1' then
         v.discard := '1';
         v.response.responseValid := '0';
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      prepared <= r.prepared;
      slave.ready <= v.response.ready;
      slave.responseValid <= r.response.responseValid;
      slave.data <= r.response.data;
   end process;

   seq : process(clk,rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process;

end architecture rtl;
