-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Three immutable/working PTP configuration banks in word RAM.
-- Prepare pins the old shadow and clones it to a new writable shadow. Writes
-- after prepare wait for the bounded clone, preserving every untouched word.
-- The active pointer changes only on apply. Scan words allow the owning module
-- to validate sequentially; prepared is raised after the final word drains.
-- Two request owners arbitrate fairly. AXI-only cancellation drops responses,
-- never accepted writes, frozen banks, initialization or coordination.
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
use surf.PtpRegisterPkg.all;

entity PtpConfigBank is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      DEFAULTS_G     : Slv32Array);
   port (
      clk       : in sl;
      rst       : in sl;
      prepare   : in sl;
      apply     : in sl;
      prepared  : out sl;
      scanValid : out sl;
      scanIndex : out slv(7 downto 0);
      scanData  : out slv(31 downto 0);
      masters   : in PtpRegisterMasterArray(0 to 1);
      slaves    : out PtpRegisterSlaveArray(0 to 1));
end entity PtpConfigBank;

architecture rtl of PtpConfigBank is

   constant WORDS_C     : positive := DEFAULTS_G'length;
   constant ADDR_BITS_C : positive := log2(3*WORDS_C);

   type StateType is (
      INIT_S, INIT_DRAIN_S, IDLE_S, READ_WAIT_S, READ_S, WRITE_S, FINISH_S,
      COPY_WAIT_S, COPY_S, COPY_NEXT_S, COPY_DONE_S);

   type RegType is record
      state         : StateType;
      activeBank    : natural range 0 to 2;
      shadowBank    : natural range 0 to 2;
      candidateBank : natural range 0 to 2;
      initialize    : natural range 0 to 3*WORDS_C-1;
      index         : natural range 0 to WORDS_C-1;
      copyPending   : sl;
      prepared      : sl;
      scanValid     : sl;
      scanIndex     : slv(7 downto 0);
      scanData      : slv(31 downto 0);
      owner         : natural range 0 to 1;
      cursor        : natural range 0 to 1;
      request       : PtpRegisterMasterType;
      discard       : sl;
      responses     : PtpRegisterSlaveArray(0 to 1);
      readEnable    : sl;
      readAddress   : slv(ADDR_BITS_C-1 downto 0);
      writeEnable   : sl;
      writeAddress  : slv(ADDR_BITS_C-1 downto 0);
      writeData     : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state         => INIT_S,
      activeBank    => 2,
      shadowBank    => 0,
      candidateBank => 1,
      initialize    => 0,
      index         => 0,
      copyPending   => '0',
      prepared      => '1',
      scanValid     => '0',
      scanIndex     => (others => '0'),
      scanData      => (others => '0'),
      owner         => 0,
      cursor        => 0,
      request       => PTP_REGISTER_MASTER_INIT_C,
      discard       => '0',
      responses     => (others => PTP_REGISTER_SLAVE_INIT_C),
      readEnable    => '0',
      readAddress   => (others => '0'),
      writeEnable   => '0',
      writeAddress  => (others => '0'),
      writeData     => (others => '0'));

   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal readData : slv(31 downto 0);

begin

   assert DEFAULTS_G'low = 0 and WORDS_C <= 256 report "Invalid PTP configuration word layout" severity failure;

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
      variable v         : RegType;
      variable selected  : integer range -1 to 1;
      variable candidate : natural range 0 to 1;
      variable bank      : natural range 0 to 2;
      variable address   : natural;
   begin
      v := r;
      v.readEnable := '0';
      v.writeEnable := '0';
      v.scanValid := '0';
      selected := -1;
      bank     := r.shadowBank;
      for i in 0 to 1 loop
         v.responses(i).ready := '0';

         if masters(i).responseReady = '1' or masters(i).cancel = '1' then
            v.responses(i).responseValid := '0';
         end if;

         if masters(i).cancel = '1' and r.owner = i then
            v.discard := '1';
         end if;

      end loop;

      case r.state is
         when INIT_S =>
            v.writeEnable := '1';
            v.writeAddress := toSlv(r.initialize, ADDR_BITS_C);
            v.writeData := DEFAULTS_G(r.initialize mod WORDS_C);

            if r.initialize = 3*WORDS_C-1 then
               v.state := INIT_DRAIN_S;
            else
               v.initialize := r.initialize+1;
            end if;

         when INIT_DRAIN_S =>
            v.state := IDLE_S;
         when IDLE_S =>

            if r.copyPending = '1' then
               v.copyPending := '0';
               v.index := 0;
               v.readEnable := '1';
               v.readAddress := toSlv(r.candidateBank*WORDS_C, ADDR_BITS_C);
               v.state := COPY_WAIT_S;
            elsif prepare = '0' then
               for i in 0 to 1 loop
                  candidate := (r.cursor+i) mod 2;
                  if selected = -1 and masters(candidate).valid = '1' and masters(candidate).cancel = '0' and
                     r.responses(candidate).responseValid = '0' and to_integer(unsigned(masters(candidate).index)) < WORDS_C then
                     selected := candidate;
                  end if;
               end loop;
               if selected /= -1 then
                  v.responses(selected).ready := '1';
                  v.owner := selected;
                  v.cursor := 1-selected;
                  v.request := masters(selected);
                  v.discard := '0';
                  if masters(selected).bank = "01" then
                     bank := r.activeBank;
                  elsif masters(selected).bank = "10" then
                     bank := r.candidateBank;
                  end if;
                  address := bank*WORDS_C+to_integer(unsigned(masters(selected).index));
                  v.readEnable := '1';
                  v.readAddress := toSlv(address, ADDR_BITS_C);
                  v.writeAddress := toSlv(address, ADDR_BITS_C);
                  v.state := READ_WAIT_S;
               end if;
            end if;

         when READ_WAIT_S =>
            v.state := READ_S;
         when READ_S =>
            v.responses(r.owner).data := readData;

            if r.request.write = '1' then
               v.writeData := (readData and not r.request.mask) or (r.request.data and r.request.mask);
               v.writeEnable := '1';
               v.state := WRITE_S;
            else
               v.state := FINISH_S;
            end if;

         when WRITE_S =>
            v.state := FINISH_S;
         when FINISH_S =>

            if v.discard = '0' then
               v.responses(r.owner).responseValid := '1';
            end if;

            v.state := IDLE_S;
         when COPY_WAIT_S =>
            v.state := COPY_S;
         when COPY_S =>
            v.scanValid := '1';
            v.scanIndex := toSlv(r.index, 8);
            v.scanData := readData;
            v.writeEnable := '1';
            v.writeAddress := toSlv(r.shadowBank*WORDS_C+r.index, ADDR_BITS_C);
            v.writeData := readData;
            v.state := COPY_NEXT_S;
         when COPY_NEXT_S =>

            if r.index = WORDS_C-1 then
               v.state := COPY_DONE_S;
            else
               v.index := r.index+1;
               v.readEnable := '1';
               v.readAddress := toSlv(r.candidateBank*WORDS_C+r.index+1, ADDR_BITS_C);
               v.state := COPY_WAIT_S;
            end if;

         when COPY_DONE_S =>
            v.prepared := '1';
            v.state := IDLE_S;
      end case;

      if prepare = '1' then
         v.candidateBank := r.shadowBank;
         v.shadowBank := 3-r.activeBank-r.shadowBank;
         v.prepared := '0';
         v.copyPending := '1';
      end if;

      if apply = '1' then
         v.activeBank := r.candidateBank;
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      for i in 0 to 1 loop
         slaves(i).ready <= v.responses(i).ready;
         slaves(i).responseValid <= r.responses(i).responseValid;
         slaves(i).data <= r.responses(i).data;
      end loop;
      prepared <= r.prepared;
      scanValid <= r.scanValid;
      scanIndex <= r.scanIndex;
      scanData <= r.scanData;
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
