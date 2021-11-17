-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Single Channel Finite Impulse Response (FIR) Filter
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
use surf.AxiLitePkg.all;

entity FirFilterSingleChannel is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active high rst, '0' for active low
      PIPE_STAGES_G  : natural := 0;
      COMMON_CLK_G   : boolean := false;
      NUM_TAPS_G     : positive;        -- Number of programmable taps
      DATA_WIDTH_G   : positive;        -- Number of bits per data word
      COEFF_WIDTH_G  : positive;
      COEFFICIENTS_G : IntegerArray);   -- Tap Coefficients Init Constants
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl := not(RST_POLARITY_G);
      -- Inbound Interface
      ibValid         : in  sl := '1';
      ibReady         : out sl;
      din             : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid         : out sl;
      obReady         : in  sl := '1';
      dout            : out slv(DATA_WIDTH_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end FirFilterSingleChannel;

architecture mapping of FirFilterSingleChannel is

   constant CASC_WIDTH_C : integer := COEFF_WIDTH_G + DATA_WIDTH_G + log2(NUM_TAPS_G);

   type CoeffArray is array (NUM_TAPS_G-1 downto 0) of slv(COEFF_WIDTH_G-1 downto 0);
   type CascArray is array (NUM_TAPS_G-1 downto 0) of slv(CASC_WIDTH_C-1 downto 0);

   impure function InitCoeffArray return CoeffArray is
      variable retValue : CoeffArray := (others => (others => '0'));
   begin
      for i in 0 to NUM_TAPS_G-1 loop
         retValue(i) := std_logic_vector(to_signed(COEFFICIENTS_G(i), COEFF_WIDTH_G));
      end loop;
      return(retValue);
   end function;

   constant COEFFICIENTS_C : CoeffArray := InitCoeffArray;

   constant NUM_ADDR_BITS_C : positive := bitSize(NUM_TAPS_G-1);

   type RegType is record
      cnt        : natural range 0 to NUM_TAPS_G-1;
      coeffin    : CoeffArray;
      ibReady    : sl;
      tValid     : sl;
      tdata      : slv(DATA_WIDTH_G-1 downto 0);
      readSlave  : AxiLiteReadSlaveType;
      writeSlave : AxiLiteWriteSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt        => 0,
      coeffin    => COEFFICIENTS_C,
      ibReady    => '0',
      tValid     => '0',
      tdata      => (others => '0'),
      readSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal cascin  : CascArray;
   signal cascout : CascArray;

   signal tReady    : sl;
   signal ibReadyFb : sl;

   signal axiWrValid : sl;
   signal axiWrAddr  : slv(NUM_ADDR_BITS_C-1 downto 0);
   signal axiWrData  : slv(31 downto 0);

begin

   U_AxiDualPortRam_1 : entity surf.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         SYNTH_MODE_G     => "inferred",
         MEMORY_TYPE_G    => "distributed",
         READ_LATENCY_G   => 0,
         AXI_WR_EN_G      => true,
         SYS_WR_EN_G      => false,
         SYS_BYTE_WR_EN_G => false,
         COMMON_CLK_G     => COMMON_CLK_G,
         ADDR_WIDTH_G     => NUM_ADDR_BITS_C,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => axilClk,          -- [in]
         axiRst         => axilRst,          -- [in]
         axiReadMaster  => axilReadMaster,   -- [in]
         axiReadSlave   => axilReadSlave,    -- [out]
         axiWriteMaster => axilWriteMaster,  -- [in]
         axiWriteSlave  => axilWriteSlave,   -- [out]
         clk            => clk,              -- [in]
         rst            => rst,              -- [in]
         axiWrValid     => axiWrValid,       -- [out]
         axiWrAddr      => axiWrAddr,        -- [out]
         axiWrData      => axiWrData);       -- [out]

   comb : process (axiWrAddr, axiWrData, axiWrValid, cascout, ibReadyFb, ibValid, r, rst, tReady) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      if (axiWrValid = '1') then
         v.coeffin(to_integer(unsigned(axiWrAddr))) := axiWrData(COEFF_WIDTH_G-1 downto 0);
      end if;

      -- Flow Control
      v.ibReady := '0';
      if (tReady = '1') then
         v.tValid := '0';
      end if;

      -- Check for new data
      if (ibValid = '1') and (v.tValid = '0') then

         -- Accept the data
         v.ibReady := '1';

         -- Truncate the fractional bits (COEFF_WIDTH_G-1) and overflow bits
         v.tData := cascout(NUM_TAPS_G-1)(DATA_WIDTH_G-1+COEFF_WIDTH_G-1 downto COEFF_WIDTH_G-1);

         -- Check the latency init counter
         if (r.cnt = NUM_TAPS_G-1) then
            -- Output data now valid
            v.tValid := '1';
         else
            -- Increment the count
            v.cnt := r.cnt + 1;
         end if;

      end if;

      -- Outputs
--       writeSlave <= r.writeSlave;
--       readSlave  <= r.readSlave;
      ibReadyFb <= v.ibReady;
      ibReady   <= ibReadyFb;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -- Load zero into the 1st tap's cascaded input
   cascin(0) <= (others => '0');
   -- Map to the cascaded input
   CASC : for i in NUM_TAPS_G-2 downto 0 generate
      -- Use the previous cascade out values
      cascin(i+1) <= cascout(i);
   end generate;


   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_TAP :
   for i in NUM_TAPS_G-1 downto 0 generate

      U_Tap : entity surf.FirFilterTap
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => DATA_WIDTH_G,
            COEFF_WIDTH_G => COEFF_WIDTH_G,
            CASC_WIDTH_G  => CASC_WIDTH_C)
         port map (
            -- Clock Only (Infer into DSP)
            clk     => clk,
            en      => ibReadyFb,
            -- Data and tap coefficient Interface
            datain  => din,  -- Common data input because Transpose Multiply-Accumulate architecture
            coeffin => r.coeffin(NUM_TAPS_G-1-i),  -- Reversed order because Transpose Multiply-Accumulate architecture
            -- Cascade Interface
            cascin  => cascin(i),
            cascout => cascout(i));

   end generate GEN_TAP;

   U_Pipe : entity surf.FifoOutputPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DATA_WIDTH_G   => DATA_WIDTH_G,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         -- Slave Port
         sData  => r.tdata,
         sValid => r.tValid,
         sRdEn  => tReady,
         -- Master Port
         mData  => dout,
         mValid => obValid,
         mRdEn  => obReady,
         -- Clock and Reset
         clk    => clk,
         rst    => rst);

end mapping;
