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
      TPD_G             : time         := 1 ns;
      COMMON_CLK_G      : boolean      := false;
      NUM_TAPS_G        : positive;     -- Number of filter taps
      SIDEBAND_WIDTH_G  : positive     := 1;
      IBREADY_DEFAULT_G : sl           := '1';
      DATA_WIDTH_G      : positive;     -- Number of bits per data word
      COEFF_WIDTH_G     : positive range 1 to 32;  -- Number of bits per coefficient word
      COEFFICIENTS_G    : IntegerArray := (0 => 0));  -- Tap Coefficients Init Constants
   port (
      -- Clock and Reset
      clk : in sl;
      rst : in sl;

      -- Inbound Interface (clk domain)
      ibValid : in  sl                               := '1';
      ibReady : out sl;
      din     : in  slv(DATA_WIDTH_G-1 downto 0);
      sbIn    : in  slv(SIDEBAND_WIDTH_G-1 downto 0) := (others => '0');

      -- Outbound Interface (clk domain)
      obValid : out sl;
      obReady : in  sl := '1';
      dout    : out slv(DATA_WIDTH_G-1 downto 0);
      sbOut   : out slv(SIDEBAND_WIDTH_G-1 downto 0);

      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end FirFilterSingleChannel;

architecture mapping of FirFilterSingleChannel is

   constant CASC_WIDTH_C : integer := COEFF_WIDTH_G + DATA_WIDTH_G + log2(NUM_TAPS_G);

   type CoeffArray is array (NUM_TAPS_G-1 downto 0) of slv(COEFF_WIDTH_G-1 downto 0);
   type CascArray is array (NUM_TAPS_G-1 downto 0) of slv(CASC_WIDTH_C-1 downto 0);
   type DinArray is array (NUM_TAPS_G-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);

   impure function initCoeffArray return CoeffArray is
      variable retValue : CoeffArray := (others => (others => '0'));
   begin
      for i in COEFFICIENTS_G'range loop
         retValue(i) := std_logic_vector(to_signed(COEFFICIENTS_G(i), COEFF_WIDTH_G));
      end loop;
      return(retValue);
   end function;

   constant COEFFICIENTS_C : CoeffArray := initCoeffArray;

   constant NUM_ADDR_BITS_C : positive := bitSize(NUM_TAPS_G-1);

   constant FILTER_DELAY_C : integer := (NUM_TAPS_G-1)/2;

   type SidebandPipelineArray is array (FILTER_DELAY_C-1 downto 0) of slv(SIDEBAND_WIDTH_G-1 downto 0);

   type RegType is record
      coeffin    : CoeffArray;
      coeffce    : slv(NUM_TAPS_G-1 downto 0);
      ibReady    : sl;
      din        : DinArray;
      tdata      : slv(DATA_WIDTH_G-1 downto 0);
      sideband   : SidebandPipelineArray;
      tValid     : slv(FILTER_DELAY_C-1 downto 0);
      readSlave  : AxiLiteReadSlaveType;
      writeSlave : AxiLiteWriteSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      coeffin    => COEFFICIENTS_C,
      coeffce    => (others => '1'),  -- Load the COEFFICIENTS_C right after reset
      ibReady    => IBREADY_DEFAULT_G,
      din        => (others => (others => '0')),
      tdata      => (others => '0'),
      tValid     => (others => '0'),
      sideband   => (others => (others => '0')),
      readSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal writeMaster : AxiLiteWriteMasterType;
   signal readMaster  : AxiLiteReadMasterType;

   signal cascin    : CascArray;
   signal cascout   : CascArray;
   signal cascTapEn : sl;

begin

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         NUM_ADDR_BITS_G => NUM_ADDR_BITS_C+2)
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
         mAxiReadSlave   => r.readSlave,
         mAxiWriteMaster => writeMaster,
         mAxiWriteSlave  => r.writeSlave);

   comb : process (cascout, din, ibValid, obReady, r, readMaster, rst, sbIn,
                   writeMaster) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
      variable wrAddrInt : integer;
      variable rdAddrInt : integer;
   begin
      -- Latch the current value
      v := r;

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Reset strobes
      v.coeffce := (others => '0');

      -- Convert write/read address into integers
      wrAddrInt := to_integer(unsigned(writeMaster.awaddr(NUM_ADDR_BITS_C-1 downto 2)));
      rdAddrInt := to_integer(unsigned(readMaster.araddr(NUM_ADDR_BITS_C-1 downto 2)));

      -- Determine the transaction type
      axiSlaveWaitTxn(writeMaster, readMaster, v.writeSlave, v.readSlave, axiStatus);

      -- Check for write transaction
      if (axiStatus.writeEnable = '1') then

         -- Check that the address within bounds
         if (wrAddrInt < NUM_TAPS_G) then

            -- Update the coeff
            v.coeffce            := (others => '1');
            v.coeffin(wrAddrInt) := writeMaster.wdata(COEFF_WIDTH_G-1 downto 0);

            -- Respond without error
            axiSlaveWriteResponse(v.writeSlave, AXI_RESP_OK_C);

         else
            -- Respond with error
            axiSlaveWriteResponse(v.writeSlave, AXI_RESP_SLVERR_C);

         end if;

      end if;

      -- Check for read transaction
      if (axiStatus.readEnable = '1') then

         -- Check that the address within bounds
         if (rdAddrInt < NUM_TAPS_G) then

            -- Read the coeff
            v.readSlave.rdata(COEFF_WIDTH_G-1 downto 0) := r.coeffin(rdAddrInt);

            -- Respond without error
            axiSlaveReadResponse(v.readSlave, AXI_RESP_OK_C);

         else
            -- Respond with error
            axiSlaveReadResponse(v.readSlave, AXI_RESP_SLVERR_C);

         end if;

      end if;

      ------------------------
      -- Data Flow Logic
      ------------------------

      -- Flow Control
      v.ibReady := '0';
      if (obReady = '1') then
         v.tValid(0) := '0';
      end if;

      -- Check for new data
      if (ibValid = '1') and (v.tValid(0) = '0') then

         -- Accept the data
         v.ibReady := '1';

         -- Move the data/sideband and valid pipelines
         v.tValid(0)   := '1';
         v.din         := (others => din);  -- Using array to help with fanout
         v.sideband(0) := sbIn;

         v.tValid(FILTER_DELAY_C-1 downto 1)   := r.tValid(FILTER_DELAY_C-2 downto 0);
         v.sideband(FILTER_DELAY_C-1 downto 1) := r.sideband(FILTER_DELAY_C-2 downto 0);

         -- Truncate the fractional bits (COEFF_WIDTH_G-1) and overflow bits for output
         v.tData := cascout(NUM_TAPS_G-1)(DATA_WIDTH_G-1+COEFF_WIDTH_G-1 downto COEFF_WIDTH_G-1);

      end if;

      -- Outputs
      cascTapEn <= v.ibReady;
      ibReady   <= v.ibReady;
      dout      <= r.tdata;
      obValid   <= r.tValid(FILTER_DELAY_C-1);
      sbOut     <= r.sideband(FILTER_DELAY_C-1);

      -- Reset
      if (rst = '1') then
         v          := REG_INIT_C;
         -- Allow sideband to use SRL
         v.sideband := r.sideband;
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

   -------------------------------------------------------------------------------------------------
   -- Cascade glue Logic
   -------------------------------------------------------------------------------------------------
   -- Load zero into the 1st tap's cascaded input
   cascin(0) <= (others => '0');
   -- Map to the cascaded input
   CASC : for i in NUM_TAPS_G-2 downto 0 generate
      -- Use the previous cascade out values
      cascin(i+1) <= cascout(i);
   end generate;

   GEN_TAP : for i in NUM_TAPS_G-1 downto 0 generate
      U_Tap : entity surf.FirFilterTap
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => DATA_WIDTH_G,
            COEFF_WIDTH_G => COEFF_WIDTH_G,
            COEFF_INIT_G  => COEFFICIENTS_C(NUM_TAPS_G-1-i),
            CASC_WIDTH_G  => CASC_WIDTH_C)
         port map (
            -- Clock Only (Infer into DSP)
            clk     => clk,
            en      => cascTapEn,
            -- Data and tap coefficient Interface
            datain  => r.din(i),  -- Common data input because Transpose Multiply-Accumulate architecture
            coeffin => r.coeffin(NUM_TAPS_G-1-i),
            coeffce => r.coeffce(NUM_TAPS_G-1-i),  -- Reversed order because Transpose Multiply-Accumulate architecture
            -- Cascade Interface
            cascin  => cascin(i),
            cascout => cascout(i));

   end generate GEN_TAP;

end mapping;
