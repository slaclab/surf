-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-Channel Finite Impulse Response (FIR) Filter
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity FirFilterMultiChannel is
   generic (
      TPD_G              : time     := 1 ns;
      TAP_SIZE_G         : positive := 21;      -- Number of programmable taps
      CH_SIZE_G          : positive := 128;     -- Number of data channels
      PARALLEL_G         : positive := 4;  -- Number of parallel channel processing
      WIDTH_G            : positive := 12;      -- Number of bits per data word
      MEMORY_INIT_FILE_G : string   := "none";  -- Used to load tap coefficients into RAM at boot up
      MEMORY_TYPE_G      : string   := "distributed";
      SYNTH_MODE_G       : string   := "inferred");
   port (
      -- AXI Stream Interface (axilClk domain)
      axisClk         : in  sl;
      axisRst         : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end FirFilterMultiChannel;

architecture mapping of FirFilterMultiChannel is

   constant WORD_PER_FRAME   : positive := CH_SIZE_G/PARALLEL_G;
   constant RAM_ADDR_WIDTH_C : positive := bitSize(WORD_PER_FRAME-1);

   type DataArray is array (PARALLEL_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
   type CoeffArray is array (TAP_SIZE_G-1 downto 0, PARALLEL_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
   type CascArray is array (TAP_SIZE_G-1 downto 0, PARALLEL_G-1 downto 0) of slv(2*WIDTH_G downto 0);

   function toSlv (din : CascArray) return slv is
      variable retValue : slv((2*WIDTH_G+1)*TAP_SIZE_G*PARALLEL_G-1 downto 0) := (others => '0');
      variable idx      : integer                                             := 0;
   begin
      for i in 0 to TAP_SIZE_G-1 loop
         for j in 0 to PARALLEL_G-1 loop
            assignSlv(idx, retValue, din(i, j));
         end loop;
      end loop;
      return(retValue);
   end function;

   function toCascArray (din : slv) return CascArray is
      variable retValue : CascArray := (others => (others => (others => '0')));
      variable idx      : integer   := 0;
   begin
      for i in 0 to TAP_SIZE_G-1 loop
         for j in 0 to PARALLEL_G-1 loop
            assignRecord(idx, din, retValue(i, j));
         end loop;
      end loop;
      return(retValue);
   end function;

   function toCoeffArray (din : slv) return CoeffArray is
      variable retValue : CoeffArray := (others => (others => (others => '0')));
      variable idx      : integer    := 0;
   begin
      for j in 0 to PARALLEL_G-1 loop
         for i in 0 to TAP_SIZE_G-1 loop
            assignRecord(idx, din, retValue(i, j));
         end loop;
      end loop;
      return(retValue);
   end function;

   type RegType is record
      ramWe       : sl;
      addr        : slv(RAM_ADDR_WIDTH_C-1 downto 0);
      datain      : DataArray;
      cascin      : CascArray;
      sAxisSlave  : AxiStreamSlaveType;
      axisMeta    : AxiStreamMasterType;
      mAxisMaster : AxiStreamMasterType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      ramWe       => '0',
      addr        => (others => '0'),
      datain      => (others => (others => '0')),
      cascin      => (others => (others => (others => '0'))),
      sAxisSlave  => AXI_STREAM_SLAVE_INIT_C,
      axisMeta    => AXI_STREAM_MASTER_INIT_C,
      mAxisMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal datain  : DataArray;
   signal coeffin : CoeffArray;

   signal cascin    : CascArray;
   signal cascout   : CascArray;
   signal cascCache : CascArray;

   signal ramWe      : sl;
   signal raddr      : slv(RAM_ADDR_WIDTH_C-1 downto 0);
   signal waddr      : slv(RAM_ADDR_WIDTH_C-1 downto 0);
   signal coeffinSlv : slv(WIDTH_G*TAP_SIZE_G*PARALLEL_G-1 downto 0);
   signal ramDin     : slv((2*WIDTH_G+1)*TAP_SIZE_G*PARALLEL_G-1 downto 0);
   signal ramDout    : slv((2*WIDTH_G+1)*TAP_SIZE_G*PARALLEL_G-1 downto 0);

begin

   assert (CH_SIZE_G mod PARALLEL_G = 0)
      report "PARALLEL_G must be even number multiples of CH_SIZE_G" severity failure;

   assert (CH_SIZE_G >= PARALLEL_G)
      report "CH_SIZE_G must be >= PARALLEL_G" severity failure;

   U_TapCoeff : entity surf.AxiDualPortRam
      generic map (
         TPD_G              => TPD_G,
         SYNTH_MODE_G       => ite(MEMORY_INIT_FILE_G /= "none", "xpm", SYNTH_MODE_G),
         MEMORY_INIT_FILE_G => MEMORY_INIT_FILE_G,
         MEMORY_TYPE_G      => MEMORY_TYPE_G,
         READ_LATENCY_G     => 1,
         ADDR_WIDTH_G       => RAM_ADDR_WIDTH_C,
         DATA_WIDTH_G       => WIDTH_G*TAP_SIZE_G*PARALLEL_G)
      port map (
         -- Axi Port
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Standard Port
         clk            => axisClk,
         addr           => raddr,
         dout           => coeffinSlv);

   coeffin <= toCoeffArray(coeffinSlv);

   GEN_CACHE : if (WORD_PER_FRAME > 1) generate

      U_Cache : entity surf.DualPortRam
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            ADDR_WIDTH_G  => RAM_ADDR_WIDTH_C,
            DATA_WIDTH_G  => (2*WIDTH_G+1)*TAP_SIZE_G*PARALLEL_G)
         port map (
            -- Port A
            clka  => axisClk,
            wea   => ramWe,
            addra => waddr,
            dina  => ramDin,
            -- Port B
            clkb  => axisClk,
            addrb => raddr,
            doutb => ramDout);

      ramDin    <= toSlv(cascout);
      cascCache <= toCascArray(ramDout);

   end generate;

   comb : process (axisRst, cascCache, cascout, mAxisSlave, r, sAxisMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.ramWe := '0';

      -- AXI Stream Flow Control
      v.sAxisSlave.tReady := '0';
      if (mAxisSlave.tReady = '1') then
         v.mAxisMaster.tValid := '0';
      end if;

      -- Check for new data
      if (sAxisMaster.tValid = '1') and (r.axisMeta.tValid = '0') then

         -- Accept the data
         v.sAxisSlave.tReady := '1';

         for j in PARALLEL_G-1 downto 0 loop

            -- Map to the TAPs' data inputs
            v.datain(j) := sAxisMaster.tData(j*WIDTH_G+WIDTH_G-1 downto j*WIDTH_G);

            -- Load zero into the 1st tap's cascaded input
            v.cascin(0, j) := (others => '0');

         end loop;

         -- Map to the cascaded input
         for i in TAP_SIZE_G-2 downto 0 loop
            for j in PARALLEL_G-1 downto 0 loop

               -- Check for 1 word per frame
               if (WORD_PER_FRAME = 1) then

                  -- Use the previous cascade out values
                  v.cascin(i+1, j) := cascout(i, j);

               else

                  -- Use the cached values
                  v.cascin(i+1, j) := cascCache(i, j);

               end if;

            end loop;
         end loop;

         -- Cache the AXI stream meta data
         v.axisMeta := sAxisMaster;

      end if;

      --- Check if we can move data
      if (v.mAxisMaster.tValid = '0') and (r.axisMeta.tValid = '1') then

         -- Set the flags
         v.axisMeta.tValid := '0';
         v.ramWe           := '1';
         v.mAxisMaster     := r.axisMeta;

         -- Map to the TAPs' data outputs
         for j in PARALLEL_G-1 downto 0 loop

            -- Truncating the LSBs
            v.mAxisMaster.tData(j*WIDTH_G+WIDTH_G-1 downto j*WIDTH_G) := cascout(TAP_SIZE_G-1, j)(2*WIDTH_G-2 downto WIDTH_G-1);

         end loop;

         -- Check for tLast
         if (r.axisMeta.tLast = '1') then
            -- Reset the counter
            v.addr := (others => '0');
         else
            -- Increment the counter
            v.addr := r.addr + 1;
         end if;

      end if;

      -- AXI stream Outputs
      sAxisSlave  <= v.sAxisSlave;      -- Comb output
      mAxisMaster <= r.mAxisMaster;

      -- RAM Outputs
      ramWe <= v.ramWe;                 -- Comb output
      waddr <= r.addr;
      raddr <= v.addr;                  -- Comb output

      -- FIR TAP Outputs
      datain <= v.datain;               -- Comb output
      cascin <= v.cascin;               -- Comb output

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_TAP :
   for i in TAP_SIZE_G-1 downto 0 generate

      GEN_PARALLEL :
      for j in PARALLEL_G-1 downto 0 generate

         U_Tap : entity surf.FirFilterTap
            generic map (
               TPD_G   => TPD_G,
               WIDTH_G => WIDTH_G)
            port map (
               -- Clock Only (Infer into DSP)
               clk     => axisClk,
               -- Data and tap coefficient Interface
               datain  => datain(j),  -- Common data input because Transpose Multiply-Accumulate architecture
               coeffin => coeffin(TAP_SIZE_G-1-i, j),  -- Reversed order because Transpose Multiply-Accumulate architecture
               -- Cascade Interface
               cascin  => cascin(i, j),
               cascout => cascout(i, j));

      end generate GEN_PARALLEL;

   end generate GEN_TAP;

end mapping;
