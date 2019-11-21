-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:   This module is used to sync a FWFT FIFO bus 
--                either as a pass through or with pipeline register stages.
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


library surf;
use surf.StdRtlPkg.all;

entity FifoOutputPipeline is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean                    := false;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      PIPE_STAGES_G  : natural range 0 to 16      := 1);
   port (
      -- Slave Port
      sData  : in  slv(DATA_WIDTH_G-1 downto 0);
      sValid : in  sl;
      sRdEn  : out sl;
      -- Master Port
      mData  : out slv(DATA_WIDTH_G-1 downto 0);
      mValid : out sl;
      mRdEn  : in  sl;
      -- Clock and Reset
      clk    : in  sl;
      rst    : in  sl := not RST_POLARITY_G);              -- Optional reset
end FifoOutputPipeline;

architecture rtl of FifoOutputPipeline is

   constant PIPE_STAGES_C : natural := PIPE_STAGES_G+1;

   type DataArray is array (natural range <>) of slv(DATA_WIDTH_G-1 downto 0);

   type RegType is record
      sRdEn  : sl;
      mValid : slv(0 to PIPE_STAGES_C);
      mData  : DataArray(0 to PIPE_STAGES_C);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      sRdEn  => '0',
      mValid => (others => '0'),
      mData  => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      mData  <= sData;
      mValid <= sValid;
      sRdEn  <= mRdEn;

   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate
      
      comb : process (mRdEn, r, rst, sData, sValid) is
         variable v : RegType;
         variable i : natural;
      begin
         -- Latch the current value
         v := r;

         -- Check if we need to shift register
         if (r.mValid(PIPE_STAGES_C) = '0') or (mRdEn = '1') then
            -- Shift the data up the pipeline
            for i in PIPE_STAGES_C downto 2 loop
               v.mValid(i) := r.mValid(i-1);
               v.mData(i)  := r.mData(i-1);
            end loop;

            -- Check if the lowest cell is empty
            if r.mValid(0) = '0' then
               -- Set the read bit
               v.sRdEn := '1';
               -- Check if we were pulling the FIFO last clock cycle
               if r.sRdEn = '1' then
                  -- Shift the FIFO data
                  v.mValid(1) := sValid;
                  v.mData(1)  := sData;
               else
                  -- Clear valid in stage 1
                  v.mValid(1) := '0';
               end if;
            else
               -- Shift the lowest cell
               v.mValid(1) := r.mValid(0);
               v.mData(1)  := r.mData(0);
               -- Check if we were pulling the FIFO last clock cycle
               if r.sRdEn = '1' then
                  -- Reset the read bit
                  v.sRdEn     := '0';
                  -- Fill the lowest cell
                  v.mValid(0) := sValid;
                  v.mData(0)  := sData;
               else
                  -- Set the read bit
                  v.sRdEn     := '1';
                  -- Reset the lowest cell mValid
                  v.mValid(0) := '0';
               end if;
            end if;
         else
            -- Reset the read bit
            v.sRdEn := '0';
            -- Check if we were pulling the FIFO last clock cycle
            if r.sRdEn = '1' then
               -- Fill the lowest cell
               v.mValid(0) := sValid;
               v.mData(0)  := sData;
            elsif r.mValid(0) = '0' then
               -- Set the read bit
               v.sRdEn := '1';
            end if;
            -- Check if we need to internally shift the data to remove gaps
            for i in PIPE_STAGES_C-1 downto 1 loop
               -- Check for empty cell ahead of a filled cell
               if (r.mValid(i) = '0') and (r.mValid(i-1) = '1') then
                  -- Shift the lowest cell                  
                  v.mValid(i)   := r.mValid(i-1);
                  v.mData(i)    := r.mData(i-1);
                  -- Reset the flag
                  v.mValid(i-1) := '0';
               end if;
            end loop;
         end if;

         -- Synchronous Reset
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         sRdEn  <= r.sRdEn;
         mValid <= r.mValid(PIPE_STAGES_C);
         mData  <= r.mData(PIPE_STAGES_C);
         
      end process comb;

      seq : process (clk, rst) is
      begin
         if rising_edge(clk) then
            r <= rin after TPD_G;
         end if;
         -- Asynchronous Reset
         if (RST_ASYNC_G and rst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
