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
      TAP_SIZE_G     : positive;        -- Number of programmable taps
      WIDTH_G        : positive;        -- Number of bits per data word
      COEFFICIENTS_G : IntegerArray);   -- Tap Coefficients Init Constants
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl := not(RST_POLARITY_G);
      -- Inbound Interface
      ibValid         : in  sl := '1';
      ibReady         : out sl;
      din             : in  slv(WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid         : out sl;
      obReady         : in  sl := '1';
      dout            : out slv(WIDTH_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end FirFilterSingleChannel;

architecture mapping of FirFilterSingleChannel is

   type CoeffArray is array (TAP_SIZE_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
   type CascArray is array (TAP_SIZE_G-1 downto 0) of slv(2*WIDTH_G downto 0);

   impure function InitCoeffArray return CoeffArray is
      variable retValue : CoeffArray := (others => (others => '0'));
   begin
      for i in 0 to TAP_SIZE_G-1 loop
         retValue(i) := std_logic_vector(to_signed(COEFFICIENTS_G(i), WIDTH_G));
      end loop;
      return(retValue);
   end function;

   constant COEFFICIENTS_C : CoeffArray := InitCoeffArray;

   constant NUM_ADDR_BITS_C : positive := bitSize(TAP_SIZE_G-1)+2;

   type RegType is record
      cnt        : natural range 0 to TAP_SIZE_G-1;
      datain     : slv(WIDTH_G-1 downto 0);
      cascin     : CascArray;
      coeffin    : CoeffArray;
      ibReady    : sl;
      tValid     : sl;
      tdata      : slv(WIDTH_G-1 downto 0);
      readSlave  : AxiLiteReadSlaveType;
      writeSlave : AxiLiteWriteSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt        => 0,
      datain     => (others => '0'),
      cascin     => (others => (others => '0')),
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

   signal datain : slv(WIDTH_G-1 downto 0);
   signal tReady : sl;

   signal readMaster  : AxiLiteReadMasterType;
   signal readSlave   : AxiLiteReadSlaveType;
   signal writeMaster : AxiLiteWriteMasterType;
   signal writeSlave  : AxiLiteWriteSlaveType;

begin

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         NUM_ADDR_BITS_G => NUM_ADDR_BITS_C)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => clk,
         mAxiClkRst      => rst,
         mAxiReadMaster  => readMaster,
         mAxiReadSlave   => readSlave,
         mAxiWriteMaster => writeMaster,
         mAxiWriteSlave  => writeSlave);

   comb : process (cascout, din, ibValid, r, readMaster, rst, tReady,
                   writeMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, writeMaster, readMaster, v.writeSlave, v.readSlave);

      -- Map the registers
      for i in TAP_SIZE_G-1 downto 0 loop
         axiSlaveRegister (axilEp, toSlv((4*i), NUM_ADDR_BITS_C), 0, v.coeffin(i));
      end loop;

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      -- Flow Control
      v.ibReady := '0';
      if (tReady = '1') then
         v.tValid := '0';
      end if;

      -- Check for new data
      if (ibValid = '1') and (v.tValid = '0') then

         -- Accept the data
         v.ibReady := '1';

         -- Latch the value
         v.datain := din;

         -- Load zero into the 1st tap's cascaded input
         v.cascin(0) := (others => '0');

         -- Map to the cascaded input
         for i in TAP_SIZE_G-2 downto 0 loop

            -- Use the previous cascade out values
            v.cascin(i+1) := cascout(i);

         end loop;

         -- Truncating the LSBs
         v.tData := cascout(TAP_SIZE_G-1)(2*WIDTH_G-2 downto WIDTH_G-1);

         -- Check the latency init counter
         if (r.cnt = TAP_SIZE_G-1) then
            -- Output data now valid
            v.tValid := '1';
         else
            -- Increment the count
            v.cnt := r.cnt + 1;
         end if;

      end if;

      -- Outputs
      writeSlave <= r.writeSlave;
      readSlave  <= r.readSlave;
      ibReady    <= v.ibReady;
      datain     <= v.datain;
      cascin     <= v.cascin;

      -- Reset
      if (rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_TAP :
   for i in TAP_SIZE_G-1 downto 0 generate

      U_Tap : entity surf.FirFilterTap
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => WIDTH_G)
         port map (
            -- Clock Only (Infer into DSP)
            clk     => clk,
            -- Data and tap coefficient Interface
            datain  => datain,  -- Common data input because Transpose Multiply-Accumulate architecture
            coeffin => r.coeffin(TAP_SIZE_G-1-i),  -- Reversed order because Transpose Multiply-Accumulate architecture
            -- Cascade Interface
            cascin  => cascin(i),
            cascout => cascout(i));

   end generate GEN_TAP;

   U_Pipe : entity surf.FifoOutputPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         DATA_WIDTH_G   => WIDTH_G,
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
