-------------------------------------------------------------------------------
-- Title      : Asynchronous Gearbox
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A generic gearbox with asynchronous input and output clocks
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity AsyncGearbox is

   generic (
      TPD_G          : time := 1 ns;
      INPUT_WIDTH_G  : positive;
      OUTPUT_WIDTH_G : positive;

      -- Async FIFO generics
      FIFO_BRAM_EN_G     : boolean               := true;
      FIFO_PIPE_STAGES_G : natural range 0 to 16 := 0;
      FIFO_ADDR_WIDTH_G  : integer range 2 to 48 := 4);
   port (
      slaveClk : in sl;
      slaveRst : in sl;

      -- input side data and flow control
      slaveData  : in  slv(INPUT_WIDTH_G-1 downto 0);
      slaveValid : in  sl := '1';
      slaveReady : out sl;

      -- sequencing and slip
      slip : in sl := '0';

      masterClk : in sl;
      masterRst : in sl;

      -- output side data and flow control
      masterData  : out slv(OUTPUT_WIDTH_G-1 downto 0);
      masterValid : out sl;
      masterReady : in  sl := '1');

end entity AsyncGearbox;

architecture rtl of AsyncGearbox is

   constant INPUT_FASTER_C : boolean := INPUT_WIDTH_G <= OUTPUT_WIDTH_G;

   signal fastClk : sl;
   signal fastRst : sl;

   signal gearboxDataIn   : slv(INPUT_WIDTH_G-1 downto 0);
   signal gearboxValidIn  : sl;
   signal gearboxReadyIn  : sl;
   signal gearboxDataOut  : slv(OUTPUT_WIDTH_G-1 downto 0);
   signal gearboxValidOut : sl;
   signal gearboxReadyOut : sl;
   signal gearboxSlip     : sl;

begin

   fastClk <= clkIn when INPUT_FASTER_C else clkOut;
   fastRst <= rstIn when INPUT_FASTER_C else rstOut;

   U_SynchronizerOneShot_1 : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => fastClk,            -- [in]
         rst     => fastRst,            -- [in]
         dataIn  => slip,               -- [in]
         dataOut => gearboxSlip);       -- [out]


   INPUT_FIFO_GEN : if (not INPUT_FASTER_C) generate
      U_FifoAsync_1 : entity work.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            FWFT_EN_G     => true,
            DATA_WIDTH_G  => INPUT_WIDTH_G,
            BRAM_EN_G     => FIFO_BRAM_EN_G,
            PIPE_STAGES_G => FIFO_PIPE_STAGES_G,
            ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G
            )
         port map (
            rst    => rstIn,            -- [in]
            wr_clk => clkIn,            -- [in]
            wr_en  => validIn,          -- [in]
            din    => dataIn,           -- [in]
            rd_clk => clkOut,           -- [in]
            rd_en  => gearboxReadyIn,   -- [in]
            dout   => gearboxDataIn,    -- [out]
            valid  => gearboxValidIn);  -- [out]
   end generate INPUT_FIFO_GEN;

   NO_INPUT_FIFO_GEN : if (INPUT_FASTER_C) generate
      readyIn        <= gearboxReadyIn;
      gearboxValidIn <= validIn;
      gearboxDataIn  <= dataIn;
   end generate NO_INPUT_FIFO_GEN;

   U_Gearbox_1 : entity work.Gearbox
      generic map (
         TPD_G          => TPD_G,
         INPUT_WIDTH_G  => OUTPUT_WIDTH_G,
         OUTPUT_WIDTH_G => INPUT_WIDTH_G)
      port map (
         clk         => fastClk,          -- [in]
         rst         => fastRst,          -- [in]
         slaveData   => gearboxDataIn,    -- [in]
         slaveValid  => gearboxValidIn,   -- [in]
         slaveReady  => gearboxReadyIn,   -- [out]
         masterData  => gearboxDataOut,   -- [out]
         masterValid => gearboxValidOut,  -- [out]
         masterReady => gearboxReadyOut,  -- [in]
         slip        => gearboxSlip);

   OUTPUT_FIFO_GEN : if (INPUT_FASTER_C) generate
      U_FifoAsync_1 : entity work.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            FWFT_EN_G     => true,
            DATA_WIDTH_G  => OUTPUT_WIDTH_G,
            BRAM_EN_G     => FIFO_BRAM_EN_G,
            PIPE_STAGES_G => FIFO_PIPE_STAGES_G,
            ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G)
         port map (
            rst    => fastRst,          -- [in]
            wr_clk => fastClk,          -- [in]
            wr_en  => gearboxValidOut,  -- [in]
            din    => gearboxDataOut,   -- [in]
            rd_clk => masterClk,        -- [in]
            rd_en  => masterReady,      -- [in]
            dout   => dataOut,          -- [out]
            valid  => masterValid);     -- [out]
   end generate INPUT_FIFO_GEN;

   NO_INPUT_FIFO_GEN : if (INPUT_FASTER_C) generate
      gearboxReadyOut <= masterReady;
      masterData      <= gearboxDataOut;
      masterValid     <= gearboxValidOut;
   end generate NO_INPUT_FIFO_GEN;
end architecture rtl;
