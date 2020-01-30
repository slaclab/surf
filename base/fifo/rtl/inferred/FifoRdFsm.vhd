-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: FIFO Read FSM
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

entity FifoRdFsm is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean  := false;
      FIFO_ASYNC_G   : boolean  := false;
      MEMORY_TYPE_G  : string   := "block";
      FWFT_EN_G      : boolean  := false;
      DATA_WIDTH_G   : positive := 16;
      ADDR_WIDTH_G   : positive := 4;
      EMPTY_THRES_G  : positive := 1);
   port (
      -- Reset
      rst           : in  sl;
      -- RD/WR FSM Interface
      rdRdy         : out sl;
      rdIndex       : out slv(ADDR_WIDTH_G-1 downto 0);
      wrRdy         : in  sl;
      wrIndex       : in  slv(ADDR_WIDTH_G-1 downto 0);
      -- RAM Interface
      addrb         : out slv(ADDR_WIDTH_G-1 downto 0);
      doutb         : in  slv(DATA_WIDTH_G-1 downto 0);
      enb           : out sl;
      regceb        : out sl;
      -- FIFO Read Interface
      rd_clk        : in  sl;
      rd_en         : in  sl;
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
end FifoRdFsm;

architecture rtl of FifoRdFsm is

   constant MAX_CNT_C : slv(ADDR_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      rdRdy        : sl;
      tValid       : slv(1 downto 0);
      enb          : sl;
      regceb       : sl;
      valid        : sl;
      underflow    : sl;
      prog_empty   : sl;
      almost_empty : sl;
      empty        : sl;
      count        : slv(ADDR_WIDTH_G-1 downto 0);
      rdAddr       : slv(ADDR_WIDTH_G-1 downto 0);
      rdIndex      : slv(ADDR_WIDTH_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rdRdy        => ite(FIFO_ASYNC_G, '0', '1'),
      tValid       => (others => '0'),
      enb          => ite(FWFT_EN_G, '0', '1'),
      regceb       => ite(FWFT_EN_G, '0', '1'),
      valid        => '0',
      underflow    => '0',
      prog_empty   => '1',
      almost_empty => '1',
      empty        => '1',
      count        => (others => '0'),
      rdAddr       => (others => '0'),
      rdIndex      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;

   comb : process (doutb, r, rd_en, wrIndex, wrRdy) is
      variable v      : RegType;
      variable wrAddr : slv(ADDR_WIDTH_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Set the flag
      v.rdRdy := '1';

      -- Reset strobes
      v.underflow := '0';
      v.valid     := '0';
      v.enb       := '0';
      v.regceb    := '0';

      -- Check for ASYNC FIFO config
      if FIFO_ASYNC_G then
         wrAddr := grayDecode(wrIndex);
      else
         wrAddr := wrIndex;
      end if;

      -- Check if write FSM ready after reset
      if (wrRdy = '1') then

         -----------------------------------------
         --             FWFT Mode
         -----------------------------------------      

         -- Check if FWFT FIFO
         if (FWFT_EN_G) then

            -- Flow Control Handshaking
            if (rd_en = '1') then
               v.tValid(1) := '0';
            end if;

            -- Check for BRAM (2 cycle read latency = DOB_REG_G + Internal REG )
            if (MEMORY_TYPE_G /= "distributed") then

               -- Check if we need to move data from RAM output to RAM REG
               if (v.tValid(1) = '0') and (r.tValid(0) = '1') then
                  -- Move the data into the RAM REG
                  v.regceb    := '1';
                  v.tValid(1) := '1';
                  v.tValid(0) := '0';
               end if;

               -- Check if able to move pipeline and FIFO is not empty
               if (v.tValid(0) = '0') and (r.empty = '0') then
                  -- Move the flag
                  v.enb       := '1';
                  v.tValid(0) := '1';
                  -- Increment the read address
                  v.rdAddr    := r.rdAddr + 1;
               end if;

            -- Else LUTRAM (1 cycle read latency = Internal REG)
            else

               -- Check if able to move pipeline and FIFO is not empty
               if (v.tValid(1) = '0') and (r.empty = '0') then
                  -- Move the flag
                  v.enb       := '1';
                  v.tValid(1) := '1';
                  -- Increment the read address
                  v.rdAddr    := r.rdAddr + 1;
               end if;

            end if;

         else

            -----------------------------------------
            --             FIFO Mode
            -----------------------------------------              

            -- Check for read operation
            if (rd_en = '1') then

               -- Check if FIFO is not empty
               if (r.empty = '0') then

                  -- Set the flag
                  v.valid := '1';

                  -- Increment the read address
                  v.rdAddr := r.rdAddr + 1;

               -- Else Underflow detected
               else

                  -- Set the flag
                  v.underflow := '1';

               end if;

            end if;

            -- Unused signals in FIFO mode
            v.enb    := '1';
            v.regceb := '1';

         end if;

         -- Update the count
         v.count := wrAddr - v.rdAddr;

      end if;

      -----------------------------------------
      --       Update flags
      -----------------------------------------

      -- Update the empty flag
      if (v.count = 0) then
         v.empty := '1';
      else
         v.empty := '0';
      end if;

      -- Update the almost_empty flag
      if (v.count = 1) or (v.count = 0) then
         v.almost_empty := '1';
      else
         v.almost_empty := '0';
      end if;

      -- Update the prog_empty flag
      if (v.count < EMPTY_THRES_G) then
         v.prog_empty := '1';
      else
         v.prog_empty := '0';
      end if;

      -- Check for sample in FIFO reg
      if (v.tValid(0) = '1') then
         -- Check for ASYNC FIFO config
         if FIFO_ASYNC_G then
            v.rdIndex := grayEncode(v.rdAddr-1);
         else
            v.rdIndex := v.rdAddr-1;
         end if;
      else
         -- Check for ASYNC FIFO config
         if FIFO_ASYNC_G then
            v.rdIndex := grayEncode(v.rdAddr);
         else
            v.rdIndex := v.rdAddr;
         end if;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -----------------------------------------
      --       Outputs
      -----------------------------------------

      -- RD/WR FSM Outputs
      if FIFO_ASYNC_G then
         rdRdy   <= r.rdRdy;
         rdIndex <= r.rdIndex;
      else
         rdRdy   <= v.rdRdy;
         rdIndex <= v.rdIndex;
      end if;

      -- RAM Outputs
      addrb  <= v.rdAddr;
      enb    <= v.enb;
      regceb <= v.regceb;

      -- Read Outputs
      dout         <= doutb;
      underflow    <= r.underflow;
      prog_empty   <= r.prog_empty;
      almost_empty <= r.almost_empty;
      empty        <= r.empty;

      if (FWFT_EN_G) then
         valid <= r.tValid(1);
         -- Check for sample in FIFO reg
         if (r.tValid(0) = '1') and (r.count /= MAX_CNT_C) then
            rd_data_count <= r.count + 1;
         else
            rd_data_count <= r.count;
         end if;
      else
         valid         <= v.valid;
         rd_data_count <= r.count;
      end if;

   end process comb;

   ASYNC_RST : if (RST_ASYNC_G) generate
      seq : process (rd_clk, rst) is
      begin
         if (rising_edge(rd_clk)) then
            r <= rin after TPD_G;
         end if;
         if (rst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;
   end generate ASYNC_RST;

   SYNC_RST : if (not RST_ASYNC_G) generate
      seq : process (rd_clk) is
      begin
         if (rising_edge(rd_clk)) then
            if (rst = RST_POLARITY_G) then
               r <= REG_INIT_C after TPD_G;
            else
               r <= rin after TPD_G;
            end if;
         end if;
      end process seq;
   end generate SYNC_RST;

end rtl;
