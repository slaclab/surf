-------------------------------------------------------------------------------
-- Title      : Asynchronous Gearbox
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A generic gearbox with asynchronous input and output clocks
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

entity AsyncGearbox is

   generic (
      TPD_G                : time     := 1 ns;
      SLAVE_WIDTH_G        : positive;
      SLAVE_BIT_REVERSE_G  : boolean := false;
      MASTER_WIDTH_G       : positive;
      MASTER_BIT_REVERSE_G : boolean := false;
      -- Pipelining generics
      INPUT_PIPE_STAGES_G  : natural  := 0;
      OUTPUT_PIPE_STAGES_G : natural  := 0;
      -- Async FIFO generics
      FIFO_MEMORY_TYPE_G   : string   := "distributed";
      FIFO_ADDR_WIDTH_G    : positive := 4);
   port (
      slaveClk : in sl;
      slaveRst : in sl;

      -- input side data and flow control
      slaveData  : in  slv(SLAVE_WIDTH_G-1 downto 0);
      slaveValid : in  sl := '1';
      slaveReady : out sl;

      -- sequencing and slip
      slip : in sl := '0';

      masterClk : in sl;
      masterRst : in sl;

      -- output side data and flow control
      masterData  : out slv(MASTER_WIDTH_G-1 downto 0);
      masterValid : out sl;
      masterReady : in  sl := '1');

end entity AsyncGearbox;

architecture mapping of AsyncGearbox is

   constant SLAVE_FASTER_C : boolean := SLAVE_WIDTH_G <= MASTER_WIDTH_G;

   signal fastClk : sl;
   signal fastRst : sl;

   signal gearboxDataIn   : slv(SLAVE_WIDTH_G-1 downto 0);
   signal gearboxValidIn  : sl;
   signal gearboxReadyIn  : sl;
   signal gearboxDataOut  : slv(MASTER_WIDTH_G-1 downto 0);
   signal gearboxValidOut : sl;
   signal gearboxReadyOut : sl;
   signal gearboxSlip     : sl;
   signal almostFull      : sl;
   signal writeEnable     : sl;

begin

   fastClk <= slaveClk when SLAVE_FASTER_C else masterClk;
   fastRst <= slaveRst when SLAVE_FASTER_C else masterRst;

   U_SynchronizerOneShot_1 : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => fastClk,            -- [in]
         rst     => fastRst,            -- [in]
         dataIn  => slip,               -- [in]
         dataOut => gearboxSlip);       -- [out]

   SLAVE_FIFO_GEN : if (not SLAVE_FASTER_C) generate
      U_FifoAsync_1 : entity surf.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            FWFT_EN_G     => true,
            DATA_WIDTH_G  => SLAVE_WIDTH_G,
            MEMORY_TYPE_G => FIFO_MEMORY_TYPE_G,
            PIPE_STAGES_G => INPUT_PIPE_STAGES_G,
            ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G
            )
         port map (
            rst         => slaveRst,         -- [in]
            wr_clk      => slaveClk,         -- [in]
            wr_en       => writeEnable,      -- [in]
            din         => slaveData,        -- [in]
            almost_full => almostFull,       -- [out]
            rd_clk      => fastClk,          -- [in]
            rd_en       => gearboxReadyIn,   -- [in]
            dout        => gearboxDataIn,    -- [out]
            valid       => gearboxValidIn);  -- [out]
      slaveReady  <= not(almostFull);
      writeEnable <= slaveValid and not(almostFull);
   end generate SLAVE_FIFO_GEN;

   NO_SLAVE_FIFO_GEN : if (SLAVE_FASTER_C) generate
      U_Input : entity surf.FifoOutputPipeline
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => SLAVE_WIDTH_G,
            PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
         port map (
            -- Clock and Reset
            clk    => slaveClk,
            rst    => slaveRst,
            -- Slave Port
            sData  => slaveData,
            sValid => slaveValid,
            sRdEn  => slaveReady,
            -- Master Port
            mData  => gearboxDataIn,
            mValid => gearboxValidIn,
            mRdEn  => gearboxReadyIn);
   end generate NO_SLAVE_FIFO_GEN;

   U_Gearbox_1 : entity surf.Gearbox
      generic map (
         TPD_G                => TPD_G,
         SLAVE_WIDTH_G        => SLAVE_WIDTH_G,
         SLAVE_BIT_REVERSE_G  => SLAVE_BIT_REVERSE_G,
         MASTER_WIDTH_G       => MASTER_WIDTH_G,
         MASTER_BIT_REVERSE_G => MASTER_BIT_REVERSE_G)
      port map (
         clk         => fastClk,          -- [in]
         rst         => fastRst,          -- [in]
         slaveData   => gearboxDataIn,    -- [in]
         slaveValid  => gearboxValidIn,   -- [in]
         slaveReady  => gearboxReadyIn,   -- [out]
         masterData  => gearboxDataOut,   -- [out]
         masterValid => gearboxValidOut,  -- [out]
         masterReady => gearboxReadyOut,  -- [in]
         slip        => gearboxSlip);     -- [in]

   MASTER_FIFO_GEN : if (SLAVE_FASTER_C) generate
      U_FifoAsync_1 : entity surf.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            FWFT_EN_G     => true,
            DATA_WIDTH_G  => MASTER_WIDTH_G,
            MEMORY_TYPE_G => FIFO_MEMORY_TYPE_G,
            PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G,
            ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G)
         port map (
            rst         => fastRst,          -- [in]
            wr_clk      => fastClk,          -- [in]
            wr_en       => writeEnable,      -- [in]
            din         => gearboxDataOut,   -- [in]
            almost_full => almostFull,       -- [out]
            rd_clk      => masterClk,        -- [in]
            rd_en       => masterReady,      -- [in]
            dout        => masterData,       -- [out]
            valid       => masterValid);     -- [out]
      gearboxReadyOut <= not(almostFull);
      writeEnable     <= gearboxValidOut and not(almostFull);
   end generate MASTER_FIFO_GEN;

   NO_MASTER_FIFO_GEN : if (not SLAVE_FASTER_C) generate
      U_Output : entity surf.FifoOutputPipeline
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => MASTER_WIDTH_G,
            PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
         port map (
            -- Clock and Reset
            clk    => masterClk,
            rst    => masterRst,
            -- Slave Port
            sData  => gearboxDataOut,
            sValid => gearboxValidOut,
            sRdEn  => gearboxReadyOut,
            -- Master Port
            mData  => masterData,
            mValid => masterValid,
            mRdEn  => masterReady);
   end generate NO_MASTER_FIFO_GEN;

end mapping;
