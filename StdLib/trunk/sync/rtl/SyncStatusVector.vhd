-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SyncStatusVector.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-11
-- Last update: 2014-04-12
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity SyncStatusVector is
   generic (
      TPD_G           : time                  := 1 ns; -- Simulation FF output delay
      COMMON_CLK_G    : boolean               := false;-- True if wrClk and rdClk are the same clock
      RELEASE_DELAY_G : positive              := 3;    -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   : slv                   := "1";  -- 0 for active LOW, 1 for active HIGH (for statusIn port)
      OUT_POLARITY_G  : sl                    := '1';  -- 0 for active LOW, 1 for active HIGH (for irqOut port)
      USE_DSP48_G     : string                := "no";
      SYNTH_CNT_G     : slv                   := "1";  -- Set to 1 for synthesising counter RTL
      CNT_WIDTH_G     : natural range 1 to 48 := 32;
      WIDTH_G         : integer               := 16);
   port (
      -- Input Status bit Signals (wrClk domain)      
      statusIn       : in  slv(WIDTH_G-1 downto 0);-- Data to be 'synced'
      -- Output Status bit Signals (rdClk domain)      
      statusOut      : out slv(WIDTH_G-1 downto 0);-- Synced data
      -- Status Bit Counters Signals (rdClk domain)      
      rollOverMaskIn : in  slv(WIDTH_G-1 downto 0) := (others => '0');  -- No roll over for all counters by default
      raddrIn        : in  slv(bitSize(WIDTH_G)-1 downto 0) := (others => '0');
      muxOut         : out slv(CNT_WIDTH_G-1 downto 0);-- mux'd counter data with respect to raddrIn
      cntOut         : out SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);
      -- Interrupt Signals (rdClk domain)         
      irqMaskIn      : in  slv(WIDTH_G-1 downto 0) := (others => '0');  -- All bits disabled by default
      irqOut         : out sl;
      -- Clocks and Reset Ports
      wrClk          : in  sl;
      wrRst          : in  sl := '0';
      rdClk          : in  sl;
      rdRst          : in  sl := '0');
end SyncStatusVector;

architecture rtl of SyncStatusVector is

   function CntMux (
      din  : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);
      addr : slv(bitSize(WIDTH_G)-1 downto 0)) return slv is
      variable retVar : slv(CNT_WIDTH_G-1 downto 0);
      variable i      : integer;
   begin
      -- Check the limit of the address
      if (conv_integer(addr) < WIDTH_G) then
         for i in 0 to (CNT_WIDTH_G-1) loop
            retVar(i) := din(conv_integer(addr), i);
         end loop;
      else
         retVar := (others => '0');
      end if;
      return retVar;
   end function CntMux;

   type RegType is record
      irqOut    : sl;
      maskCheck : slv(WIDTH_G-1 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      not(OUT_POLARITY_G),
      (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusStrobe : slv(WIDTH_G-1 downto 0);
   signal cnt          : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);
   
begin

   SyncFifo_Inst : entity work.SynchronizerFifo
      generic map (
         TPD_G               => TPD_G,
         BYPASS_FIFO_ASYNC_G => COMMON_CLK_G,
         SYNC_STAGES_G       => RELEASE_DELAY_G,
         DATA_WIDTH_G        => WIDTH_G)
      port map (
         -- Asynchronous Reset
         rst    => wrRst,
         --Write Ports (wr_clk domain)
         wr_clk => wrClk,
         din    => statusIn,
         --Read Ports (rd_clk domain)
         rd_clk => rdClk,
         dout   => statusOut);

   SyncOneShotCntVec_Inst : entity work.SynchronizerOneShotCntVector
      generic map (
         TPD_G             => TPD_G,
         BYPASS_RST_SYNC_G => COMMON_CLK_G,
         RELEASE_DELAY_G   => RELEASE_DELAY_G,
         IN_POLARITY_G     => IN_POLARITY_G,
         USE_DSP48_G       => USE_DSP48_G,
         CNT_WIDTH_G       => CNT_WIDTH_G,
         WIDTH_G           => WIDTH_G) 
      port map (
         clk      => rdClk,
         rst      => rdRst,             -- This is the counters' reset port 
         dataIn   => statusIn,
         rollOver => rollOverMaskIn,
         dataOut  => statusStrobe,
         cntOut   => cnt);     

   -- Ouput the MUX'd and non-MUX'd counter values
   muxOut <= CntMux(cnt, raddrIn);
   cntOut <= cnt;

   comb : process (irqMaskIn, r, rdRst, statusStrobe) is
      variable i : integer;
      variable v : RegType;
   begin
      -- Reset signals
      v := REG_INIT_C;

      -- Refresh the mask check
      for i in 0 to (WIDTH_G-1) loop
         if irqMaskIn(i) = '1' then
            v.maskCheck(i) := statusStrobe(i);
         end if;
      end loop;

      -- Check the maskCheck vector for a new interrupt
      if uOr(r.maskCheck) = '1' then
         v.irqOut := OUT_POLARITY_G;
      end if;

      -- Sync Reset
      if rdRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      irqOut <= r.irqOut;
      
   end process comb;

   seq : process (rdClk) is
   begin
      if rising_edge(rdClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
