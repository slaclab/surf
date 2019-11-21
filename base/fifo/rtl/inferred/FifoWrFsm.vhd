-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: FIFO Write FSM
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


library surf;
use surf.StdRtlPkg.all;

entity FifoWrFsm is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean  := false;
      FIFO_ASYNC_G   : boolean  := false;
      DATA_WIDTH_G   : positive := 16;
      ADDR_WIDTH_G   : positive := 4;
      FULL_THRES_G   : positive := 1);
   port (
      -- Reset
      rst           : in  sl;
      -- RD/WR FSM Interface
      rdRdy         : in  sl;
      rdIndex       : in  slv(ADDR_WIDTH_G-1 downto 0);
      wrRdy         : out sl;
      wrIndex       : out slv(ADDR_WIDTH_G-1 downto 0);
      -- RAM Interface
      wea           : out sl;
      addra         : out slv(ADDR_WIDTH_G-1 downto 0);
      dina          : out slv(DATA_WIDTH_G-1 downto 0);
      -- FIFO Write Interface
      wr_clk        : in  sl;
      wr_en         : in  sl;
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl);
end FifoWrFsm;

architecture rtl of FifoWrFsm is

   constant FULL_C  : slv(ADDR_WIDTH_G-1 downto 0) := (others => '1');
   constant AFULL_C : slv(ADDR_WIDTH_G-1 downto 0) := FULL_C-1;

   type RegType is record
      wrRdy       : sl;
      wr_ack      : sl;
      overflow    : sl;
      prog_full   : sl;
      almost_full : sl;
      full        : sl;
      not_full    : sl;
      count       : slv(ADDR_WIDTH_G-1 downto 0);
      wrAddr      : slv(ADDR_WIDTH_G-1 downto 0);
      wrIndex     : slv(ADDR_WIDTH_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      wrRdy       => ite(FIFO_ASYNC_G, '0', '1'),
      wr_ack      => '0',
      overflow    => '0',
      prog_full   => '1',
      almost_full => '1',
      full        => '1',
      not_full    => '0',
      count       => (others => '1'),
      wrAddr      => (others => '0'),
      wrIndex     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-1))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-1)"
      severity failure;

   comb : process (din, r, rdIndex, rdRdy, wr_en) is
      variable v      : RegType;
      variable rdAddr : slv(ADDR_WIDTH_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Set the flag
      v.wrRdy := '1';

      -- Reset strobes
      v.overflow := '0';
      v.wr_ack   := '0';

      -- Check for ASYNC FIFO config
      if FIFO_ASYNC_G then
         rdAddr := grayDecode(rdIndex);
      else
         rdAddr := rdIndex;
      end if;

      -- Check if read FSM ready after reset
      if (rdRdy = '1') then

         -- Check for read operation
         if (wr_en = '1') then

            -- Check if FIFO is not full
            if (r.full = '0') then

               -- Set the flag
               v.wr_ack := '1';

               -- Increment the write address
               v.wrAddr := r.wrAddr + 1;

            -- Else Underflow detected
            else

               -- Set the flag
               v.overflow := '1';

            end if;

         end if;

         -- Update the count
         v.count := v.wrAddr - rdAddr;

      end if;

      -----------------------------------------
      --       Update flags
      -----------------------------------------

      -- Update the full flag
      if (v.count = FULL_C) then
         v.full     := '1';
         v.not_full := '0';
      else
         v.full     := '0';
         v.not_full := '1';
      end if;

      -- Update the almost_full flag
      if (v.count = AFULL_C) or (v.count = FULL_C) then
         v.almost_full := '1';
      else
         v.almost_full := '0';
      end if;

      -- Update the prog_empty flag
      if (v.count > FULL_THRES_G) or (v.count = FULL_C) then
         v.prog_full := '1';
      else
         v.prog_full := '0';
      end if;

      -- Check for ASYNC FIFO config
      if FIFO_ASYNC_G then
         v.wrIndex := grayEncode(v.wrAddr);
      else
         v.wrIndex := v.wrAddr;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -----------------------------------------
      --       Outputs
      -----------------------------------------

      -- RD/WR FSM Outputs
      if FIFO_ASYNC_G then
         wrRdy   <= r.wrRdy;
         wrIndex <= r.wrIndex;
      else
         wrRdy   <= v.wrRdy;
         wrIndex <= v.wrIndex;
      end if;

      -- RAM Outputs
      wea   <= v.wr_ack;
      addra <= v.wrAddr;
      dina  <= din;

      -- Read Outputs
      wr_data_count <= r.count;
      wr_ack        <= r.wr_ack;
      overflow      <= r.overflow;
      prog_full     <= r.prog_full;
      almost_full   <= r.almost_full;
      full          <= r.full;
      not_full      <= r.not_full;

   end process comb;

   ASYNC_RST : if (RST_ASYNC_G) generate
      seq : process (rst, wr_clk) is
      begin
         if (rising_edge(wr_clk)) then
            r <= rin after TPD_G;
         end if;
         if (rst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;
   end generate ASYNC_RST;

   SYNC_RST : if (not RST_ASYNC_G) generate
      seq : process (wr_clk) is
      begin
         if (rising_edge(wr_clk)) then
            if (rst = RST_POLARITY_G) then
               r <= REG_INIT_C after TPD_G;
            else
               r <= rin after TPD_G;
            end if;
         end if;
      end process seq;
   end generate SYNC_RST;

end rtl;
