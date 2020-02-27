-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for multiple SynchronizerOneShotCnt modules
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

entity SynchronizerOneShotCntVector is
   generic (
      TPD_G          : time     := 1 ns;  -- Simulation FF output delay
      RST_POLARITY_G : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean  := false;  -- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G   : boolean  := false;  -- True if wrClk and rdClk are the same clock
      IN_POLARITY_G  : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (dataIn port)
      OUT_POLARITY_G : slv      := "1";  -- 0 for active LOW, 1 for active HIGH (dataOut port)
      USE_DSP_G      : string   := "no";  -- "no" for no DSP implementation, "yes" to use DSP slices
      SYNTH_CNT_G    : slv      := "1";  -- Set to 1 for synthesising counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G : boolean  := true;  -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G    : positive := 16;
      WIDTH_G        : positive := 16);
   port (

      -- Write Ports (wrClk domain)          
      wrClk      : in  sl;
      wrRst      : in  sl := not RST_POLARITY_G;
      dataIn     : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      -- Read Ports (rdClk domain)
      rdClk      : in  sl;              -- clock to be SYNC'd to
      rdRst      : in  sl := not RST_POLARITY_G;
      rollOverEn : in  slv(WIDTH_G-1 downto 0);   -- '1' allows roll over of the counter
      cntRst     : in  sl := not RST_POLARITY_G;  -- Optional counter reset
      dataOut    : out slv(WIDTH_G-1 downto 0);   -- Synced data
      cntOut     : out SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0));  -- Synced counter
end SynchronizerOneShotCntVector;

architecture rtl of SynchronizerOneShotCntVector is

   function fillVectorArray (INPUT : slv) return slv is
   begin
      return ite(INPUT = "1", slvOne(WIDTH_G),
                 ite(INPUT = "0", slvZero(WIDTH_G),
                     INPUT));
   end function fillVectorArray;

   constant IN_POLARITY_C  : slv(WIDTH_G-1 downto 0) := fillVectorArray(IN_POLARITY_G);
   constant OUT_POLARITY_C : slv(WIDTH_G-1 downto 0) := fillVectorArray(OUT_POLARITY_G);
   constant SYNTH_CNT_C    : slv(WIDTH_G-1 downto 0) := fillVectorArray(SYNTH_CNT_G);

   type MySlvArray is array (WIDTH_G-1 downto 0) of slv(CNT_WIDTH_G-1 downto 0);
   signal cntWrDomain : MySlvArray;
   signal cntRdDomain : MySlvArray;

   constant FIFO_WIDTH_C : positive := CNT_WIDTH_G + bitSize(WIDTH_G-1);

   type RegType is record
      tValid : sl;
      tData  : slv(FIFO_WIDTH_C-1 downto 0);
      index  : natural range 0 to WIDTH_G-1;
   end record;

   constant REG_INIT_C : RegType := (
      tValid => '0',
      tData  => (others => '0'),
      index  => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal cntRstSync     : sl;
   signal rollOverEnSync : slv(WIDTH_G-1 downto 0);

   signal wrEn       : sl;
   signal tReady     : sl;
   signal almostFull : sl;
   signal rdValid    : sl;
   signal rdData     : slv(FIFO_WIDTH_C-1 downto 0);

begin

   CNT_RST_EDGE : if (CNT_RST_EDGE_G = true) generate

      SyncOneShot_1 : entity surf.SynchronizerOneShot
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            BYPASS_SYNC_G  => COMMON_CLK_G,
            IN_POLARITY_G  => RST_POLARITY_G,
            OUT_POLARITY_G => RST_POLARITY_G)
         port map (
            clk     => wrClk,
            rst     => wrRst,
            dataIn  => cntRst,
            dataOut => cntRstSync);

   end generate;

   CNT_RST_LEVEL : if (CNT_RST_EDGE_G = false) generate

      Synchronizer_0 : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            OUT_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            BYPASS_SYNC_G  => COMMON_CLK_G)
         port map (
            clk     => wrClk,
            rst     => wrRst,
            dataIn  => cntRst,
            dataOut => cntRstSync);

   end generate;


   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate

      Synchronizer_1 : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            OUT_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            BYPASS_SYNC_G  => COMMON_CLK_G)
         port map (
            clk     => wrClk,
            rst     => wrRst,
            dataIn  => rollOverEn(i),
            dataOut => rollOverEnSync(i));

      U_SyncOneShot : entity surf.SynchronizerOneShot
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            BYPASS_SYNC_G  => COMMON_CLK_G,
            IN_POLARITY_G  => IN_POLARITY_C(i),
            OUT_POLARITY_G => OUT_POLARITY_C(i))
         port map (
            clk     => rdClk,
            rst     => rdRst,
            dataIn  => dataIn(i),
            dataOut => dataOut(i));

      SyncOneShotCnt_Inst : entity surf.SynchronizerOneShotCnt
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            COMMON_CLK_G   => true,     -- status counter bus synchronization done outside
            IN_POLARITY_G  => IN_POLARITY_C(i),
            OUT_POLARITY_G => OUT_POLARITY_C(i),
            USE_DSP_G      => USE_DSP_G,
            SYNTH_CNT_G    => SYNTH_CNT_C(i),
            CNT_RST_EDGE_G => CNT_RST_EDGE_G,
            CNT_WIDTH_G    => CNT_WIDTH_G)
         port map (
            -- Write Ports (wrClk domain)
            wrClk      => wrClk,
            wrRst      => wrRst,
            dataIn     => dataIn(i),
            -- Read Ports (rdClk domain)
            rdClk      => wrClk,        -- status counter bus synchronization done outside
            rdRst      => wrRst,
            rollOverEn => rollOverEnSync(i),
            cntRst     => cntRstSync,
            dataOut    => open,
            cntOut     => cntWrDomain(i));


      GEN_MAP :
      for j in (CNT_WIDTH_G-1) downto 0 generate
         cntOut(i, j) <= cntRdDomain(i)(j);
      end generate GEN_MAP;

   end generate GEN_VEC;

   GEN_SYNC : if (COMMON_CLK_G = true) generate
      cntRdDomain <= cntWrDomain;
   end generate;

   GEN_ASYNC : if (COMMON_CLK_G = false) generate

      comb : process (cntWrDomain, r, tReady, wrRst) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Flow control
         if tReady = '1' then
            v.tValid := '0';
         end if;

         -- Check if ready to move data
         if (v.tValid = '0') then

            -- Write the DATA to the FIFO
            v.tValid                                   := '1';
            v.tData(CNT_WIDTH_G-1 downto 0)            := cntWrDomain(r.index);
            v.tData(FIFO_WIDTH_C-1 downto CNT_WIDTH_G) := toSlv(r.index, bitSize(WIDTH_G-1));

            -- Check for last word
            if (r.index = WIDTH_G-1) then
               -- Reset the counters
               v.index := 0;
            else
               -- Increment the counters
               v.index := r.index + 1;
            end if;

         end if;

         -- Outputs
         wrEn <= r.tValid and tReady;

         -- Synchronous Reset
         if (wrRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

      end process comb;

      seq : process (wrClk) is
      begin
         if (rising_edge(wrClk)) then
            r <= rin after TPD_G;
         end if;
      end process seq;

      U_FIFO : entity surf.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => "distributed",
            FWFT_EN_G     => true,
            DATA_WIDTH_G  => FIFO_WIDTH_C,
            ADDR_WIDTH_G  => 4)
         port map (
            rst         => '0',
            -- Write Interface
            wr_clk      => wrClk,
            wr_en       => wrEn,
            din         => r.tData,
            almost_full => almostFull,
            -- Read Interface
            rd_clk      => rdClk,
            rd_en       => '1',
            dout        => rdData,
            valid       => rdValid);

      tReady <= not(almostFull);

      process(rdClk)
      begin
         if rising_edge(rdClk) then
            if (rdRst = '1') then
               cntRdDomain <= (others => (others => '0')) after TPD_G;
            elsif (rdValid = '1') then
               cntRdDomain(conv_integer(rdData(FIFO_WIDTH_C-1 downto CNT_WIDTH_G))) <= rdData(CNT_WIDTH_G-1 downto 0) after TPD_G;
            end if;
         end if;
      end process;

   end generate;

end rtl;
