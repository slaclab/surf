-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Versioned PTP result records with coherent snapshot pinning.
-- Five banks per record hold live, published snapshot, pending snapshot and
-- next result, plus a retiring reader. A common capture pins immutable pre-edge publication sources;
-- publish exposes the whole cohort only after all scalar banks finish copying.
-- Only 32-bit writes and reads reach synchronous RAM. No record is reconstructed
-- in a working register and RAM is invalidated through ownership, never reset.
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

entity PtpPublicationBank is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      RECORD_WORDS_G : IntegerArray;
      -- One-cycle inferred RAM; supported values: "distributed" or "block".
      MEMORY_TYPE_G  : string := "distributed");
   port (
      clk         : in sl;
      rst         : in sl;
      publication : in PtpPublicationType;
      snapshot    : in PtpSnapshotControlType;
      master      : in PtpRegisterMasterType;
      slave       : out PtpRegisterSlaveType);
end entity PtpPublicationBank;

architecture rtl of PtpPublicationBank is

   constant BANKS_C : positive := 5;

   function base(recordIndex : natural) return natural is
      variable ret : natural := 0;
   begin
      for i in RECORD_WORDS_G'range loop

         if i < recordIndex then
            ret := ret+RECORD_WORDS_G(i);
         end if;

      end loop;
      return ret;
   end function;

   constant WORDS_C : positive := base(RECORD_WORDS_G'length);

   constant ADDR_BITS_C : positive := log2(BANKS_C*WORDS_C);

   type BankArray is array(RECORD_WORDS_G'range) of natural range 0 to BANKS_C-1;
   type StateType is (IDLE_S, WAIT_S, READ_S);

   type RegType is record
      state        : StateType;
      live         : BankArray;
      held         : BankArray;
      pending      : BankArray;
      writing      : BankArray;
      liveValid    : slv(RECORD_WORDS_G'range);
      heldValid    : slv(RECORD_WORDS_G'range);
      pendingValid : slv(RECORD_WORDS_G'range);
      response     : PtpRegisterSlaveType;
      readValid    : sl;
      readerBank   : natural range 0 to BANKS_C-1;
      readerRecord : natural range 0 to 15;
      discard      : sl;
      readEnable   : sl;
      readAddress  : slv(ADDR_BITS_C-1 downto 0);
      writeEnable  : sl;
      writeAddress : slv(ADDR_BITS_C-1 downto 0);
      writeData    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      live         => (others => 0),
      held         => (others => 0),
      pending      => (others => 0),
      writing      => (others => 1),
      liveValid    => (others => '0'),
      heldValid    => (others => '0'),
      pendingValid => (others => '0'),
      response     => PTP_REGISTER_SLAVE_INIT_C,
      readValid    => '0',
      readerBank   => 0,
      readerRecord => 0,
      discard      => '0',
      readEnable   => '0',
      readAddress  => (others => '0'),
      writeEnable  => '0',
      writeAddress => (others => '0'),
      writeData    => (others => '0'));

   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal readData : slv(31 downto 0);

begin

   assert MEMORY_TYPE_G = "distributed" or MEMORY_TYPE_G = "block"
      report "Invalid PTP bank memory type" severity failure;

   assert RECORD_WORDS_G'low = 0 and RECORD_WORDS_G'length <= 16 and WORDS_C <= 256
      report "Invalid PTP publication layout" severity failure;

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
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
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
      variable v           : RegType;
      variable recordIndex : natural range 0 to 15;
      variable wordIndex   : natural range 0 to 255;
   begin
      v := r;
      v.writeEnable := '0';
      v.readEnable := '0';
      v.response.ready := '0';

      if master.responseReady = '1' then
         v.response.responseValid := '0';
      end if;

      -- This registered event describes the live record already visible at
      -- the producer's public boundary before this edge. Include it in capture.
      if publication.commit = '1' then
         recordIndex := to_integer(unsigned(publication.commitRecord));
         v.live(recordIndex) := r.writing(recordIndex);
         v.liveValid(recordIndex) := '1';
      end if;

      if snapshot.capture = '1' then
         v.pending := v.live;
         v.pendingValid := v.liveValid;
      end if;

      if snapshot.publish = '1' then
         v.held := r.pending;
         v.heldValid := r.pendingValid;
      end if;

      case r.state is
         when IDLE_S =>

            if master.valid = '1' and master.cancel = '0' and r.response.responseValid = '0' then
               wordIndex := to_integer(unsigned(master.index));
               if wordIndex < WORDS_C then
                  v.response.ready := '1';
                  v.discard := '0';
                  for i in RECORD_WORDS_G'range loop
                     if wordIndex >= base(i) and wordIndex < base(i)+RECORD_WORDS_G(i) then
                        v.readValid := r.heldValid(i);
                        v.readerBank := r.held(i);
                        v.readerRecord := i;
                        v.readAddress := toSlv(BANKS_C*base(i)+r.held(i)*RECORD_WORDS_G(i)+wordIndex-base(i), ADDR_BITS_C);
                     end if;
                  end loop;
                  v.readEnable := '1';
                  v.state := WAIT_S;
               end if;
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

      if publication.write = '1' then
         recordIndex := to_integer(unsigned(publication.recordIndex));
         wordIndex   := to_integer(unsigned(publication.wordIndex));
         if publication.first = '1' then
            for i in 0 to BANKS_C-1 loop
               if i /= v.live(recordIndex) and i /= v.held(recordIndex) and i /= v.pending(recordIndex) and
                  not (v.state /= IDLE_S and v.readerRecord = recordIndex and v.readerBank = i) then
                  v.writing(recordIndex) := i;
               end if;
            end loop;
         end if;
         v.writeEnable := '1';
         v.writeAddress := toSlv(BANKS_C*base(recordIndex)+v.writing(recordIndex)*RECORD_WORDS_G(recordIndex)+wordIndex, ADDR_BITS_C);
         v.writeData := publication.data;
      end if;

      if master.cancel = '1' then
         v.discard := '1';
         v.response.responseValid := '0';
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
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
