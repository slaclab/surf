-------------------------------------------------------------------------------
-- File       : BoxcarIntegrator.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simple boxcar integrator
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

use work.StdRtlPkg.all;

entity BoxcarIntegrator is
   generic (
      TPD_G        : time     := 1 ns;
      DATA_WIDTH_G : positive := 16;
      ADDR_WIDTH_G : positive := 10);
   port (
      clk       : in  sl;
      rst       : in  sl;
      -- Configuration
      intCount  : in slv(ADDR_WIDTH_G-1 downto 0);
      -- Inbound Interface
      ibValid   : in  sl := '1';
      ibReady   : out sl;
      ibData    : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid   : out sl;
      obData    : out slv(DATA_WIDTH_G+ADDR_WIDTH_G-1 downto 0);
      obReady   : in  sl := '1';
      obPeriod  : out sl);

end BoxcarIntegrator;

architecture rtl of BoxcarIntegrator is

   type State is ( INIT_S, READY_S, ADD_S, SUB_S, OUT_S );

   type RegType is record intValue   : slv(SUM_WIDTH_G-1 downto 0);
      state      : State;
      ibData     : slv(DATA_WIDTH_G-1 downto 0);
      obPerCnt   : slv(ADDR_WIDTH_G-1 downto 0);
      intFull    : sl;
      intPass    : sl;
      fifoRead   : sl;
      fifoWrite  : sl;
      fifoRst    : sl;
      obData     : slv(SUM_WIDTH_G-1  downto 0);
      obValid    : sl;
      obPeriod   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => INIT_S,
      ibData    => (others=>'0'),
      obPerCnt  => (others=>'0'),
      intFull   => '0',
      intPass   => '0',
      fifoRead  => '0',
      fifoWrite => '0',
      fifoRst   => '1',
      obData    => (others=>'0'),
      obValid   => '0',
      obPeriod  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoDout  : slv(DATA_WIDTH_G-1 downto 0);
   signal fifoCount : slv(ADDR_WIDTH_G-1 downto 0);
   signal fifoFull  : sl;

begin

   comb : process (r, rst, intCount, ibValid, ibData, obRead, intCount, fifoValid, fifoCount, fifoDout, outAck ) is
      variable v : RegType;
   begin

      v := r;

      -- Init
      v.fifoRead := '0';
      v.intFull  := '0';
      v.intPass  := '0';

      -- Compute pass through
      if intValue = 0 then
         v.intPass := '1';
      elsif fifoCount = intValue then
         v.intFull := '1';
      end if;

      -- State machine
      case r.state is

         -- Init
         when INIT_S =>
            v.state := WAIT_S;

            if r.fifoRst = '0' and fifoFull = '0' then
               v.state := READY_S;
            end if;

         -- Ready for data
         when READY_S =>
            v.ibReady := '1';
            v.ibValue := ibValue;

            -- Inbound data is valid
            if ibValid = '1' then

               -- Pass through
               if r.intPass = '1' then
                  v.obValue  := ibData;
                  v.obValid  := '1';
                  v.obPeriod := '1';
                  v.state    := OUT_S;
               else
                  v.state     := ADD_S;
                  v.fifoWrite := '1';
                  v.fifoRead  := r.intFull;
               end if;
            end if;

         -- Add
         when ADD_S =>
            v.obValue := r.obValue + r.ibValue;

            if r.fifoRead = '1' then
               v.state := SUB_S;
            end if;
               
         -- Sub
         when SUB_S =>
            v.obValue := r.obValue - fifoOut;
            v.obValid := '1';
            v.state   := OUT_S;

            if r.obPerCnt = perCount then
               v.obPeriod := '1';
               v.obPerCnt := (others=>'0');
            else
               v.obPeriod := '0';
               v.obPerCnt := r.obPerCnt + 1;
            end if;

         -- Output
         when OUT_S =>
            if obReady = '1' then
               v.obValid  := '0';
               v.obPeriod := '0';
               v.state    := READY_S;
            end if;

         when others =>
            v.state := INIT_S;

      end case;

      -- Catch situation where FIFO count exceeds current setting
      -- can occur when configuration changes
      if rst = '1' or fifoCount > intCount then
         v := REG_INIT_C;
      end if;

      -- Outputs
      ibReady  <= v.ibReady;
      obValid  <= r.obValid;
      obData   <= r.obData;
      obPeriod <= r.obPeriod;

      rin <= v;

   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Holding FIFO
   U_Fifo: entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => false,
         DATA_WIDTH_G    => DATA_WIDTH_G,
         ADDR_WIDTH_G    => ADDR_WIDTH_G
      ) port map (
         rst           => r.fifoRst,
         wr_clk        => clk,
         wr_en         => r.fifoWrite,
         din           => r.ibData,
         rd_clk        => clk,
         rd_en         => r.fifoRead,
         dout          => fifoDout,
         rd_data_count => fifoCount,
         full          => fifoFull
      );

end rtl;

