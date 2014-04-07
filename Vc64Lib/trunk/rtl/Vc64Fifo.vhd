-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-07
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64Fifo is
   generic (
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      XIL_DEVICE_G       : string                     := "7SERIES";--Xilinx only generic parameter    
      BRAM_EN_G          : boolean                    := true;
      USE_BUILT_IN_G     : boolean                    := true;     --if set to true, this module is only Xilinx compatible only!!!
      GEN_SYNC_FIFO_G    : boolean                    := false;
      BYPASS_FIFO_G      : boolean                    := false;    -- If GEN_SYNC_FIFO_G = true, BYPASS_FIFO_G = true will reduce FPGA resources
      PIPE_STAGES_G      : integer range 0 to 16      := 0;        -- Used to add pipeline stages to the output ports to help with meeting timing
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 256);
   port (
      -- Streaming Write Data Interface (vcWrClk domain)
      vcWrIn  : in  Vc64DataType;
      vcWrOut : out Vc64CtrlType;
      -- Streaming Read Data Interface (vcRdClk domain)
      vcRdIn  : in  Vc64CtrlType;
      vcRdOut : out Vc64DataType;
      -- Clocks and resets
      vcWrClk : in  sl;
      vcWrRst : in  sl := '0';
      vcRdClk : in  sl;
      vcRdRst : in  sl := '0');      
end Vc64Fifo;

architecture rtl of Vc64Fifo is
   
   constant BYPASS_FIFO_C : boolean := ((GEN_SYNC_FIFO_G = true) and (BYPASS_FIFO_G = true));
   constant PIPE_STAGES_C : integer := ite((BYPASS_FIFO_C = true), 1, PIPE_STAGES_G);

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal rdEn,
      valid,
      progFull,
      overflow,
      ready : sl;
   
   type RegType is record
      ready    : sl;
      rdBuffer : Vc64DataType;
      rdOut    : Vc64DataArray(0 to PIPE_STAGES_C);
   end record RegType;
   constant REG_INIT_C : RegType := (
      '0',
      VC64_DATA_INIT_C,
      (others => VC64_DATA_INIT_C));
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal readOut  : Vc64DataType;
   signal writeOut : Vc64CtrlType;
   signal rdOut    : Vc64DataArray(0 to PIPE_STAGES_C) := (others => VC64_DATA_INIT_C);
   
begin

   -- Outputs
   vcWrOut <= writeOut;
   vcRdOut <= rdOut(PIPE_STAGES_C);

   GEN_FIFO : if ((GEN_SYNC_FIFO_G = false) or (BYPASS_FIFO_C = false)) generate

      -- Convert the input data into a input SLV bus
      din <= toSlv(vcWrIn);

      -- Update the writing status flags
      writeOut.ready      <= not(progFull);
      writeOut.almostFull <= progFull;
      writeOut.overflow   <= overflow;

      Fifo_Inst : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
            BRAM_EN_G       => BRAM_EN_G,
            FWFT_EN_G       => true,
            ALTERA_SYN_G    => ALTERA_SYN_G,
            ALTERA_RAM_G    => ALTERA_RAM_G,
            USE_BUILT_IN_G  => USE_BUILT_IN_G,
            XIL_DEVICE_G    => XIL_DEVICE_G,
            SYNC_STAGES_G   => FIFO_SYNC_STAGES_G,
            DATA_WIDTH_G    => 72,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            FULL_THRES_G    => FIFO_AFULL_THRES_G)
         port map (
            -- Resets
            rst       => vcWrRst,
            --Write Ports (wr_clk domain)
            wr_clk    => vcWrClk,
            wr_en     => din(72),
            din       => din(71 downto 0),
            prog_full => progFull,
            overflow  => overflow,
            --Read Ports (rd_clk domain)
            rd_clk    => vcRdClk,
            rd_en     => rdEn,
            dout      => dout,
            valid     => valid);

      -- Check if we are ready to read the FIFO
      rdEn <= valid and ready;

      -- Convert the output SLV into the output data bus
      readOut <= toVc64Data(rdEn & dout);
      
   end generate;

   BYPASS_FIFO : if (BYPASS_FIFO_C = true) generate
      valid               <= vcWrIn.valid;
      readOut             <= vcWrIn;
      writeOut.ready      <= vcRdIn.ready;
      writeOut.almostFull <= not(vcRdIn.ready);
      writeOut.overflow   <= '0';
      
   end generate;

   ZERO_LATENCY : if (PIPE_STAGES_C = 0) generate

      rdOut(0) <= readOut;
      ready    <= vcRdIn.ready;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_C > 0) generate
      
      comb : process (r, readOut, valid, vcRdIn, vcRdRst) is
         variable i : integer;
         variable j : integer;
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Check the external ready signal
         if vcRdIn.ready = '1' then
            -- Check that we have cleared out the rdBuffer
            if r.rdBuffer.valid = '1' then
               -- Reset the ready flag
               v.ready    := '0';
               -- Pipeline the readout records
               v.rdOut(0) := r.rdBuffer;
               for i in 1 to PIPE_STAGES_C loop
                  v.rdOut(i) := r.rdOut(i-1);
               end loop;
               -- Check for a FIFO read
               if (r.ready = '1') and (valid = '1') then
                  -- Latch the data value
                  v.rdBuffer := readOut;
               else
                  -- Clear the buffer
                  v.rdBuffer.valid := '0';
               end if;
            else
               -- Set the ready flag
               v.ready    := '1';
               -- Pipeline the readout records
               v.rdOut(0) := readOut;
               for i in 1 to PIPE_STAGES_C loop
                  v.rdOut(i) := r.rdOut(i-1);
               end loop;
            end if;
         else
            -- Check if we need to advance the pipeline
            for i in PIPE_STAGES_C downto 1 loop
               if r.rdOut(i).valid = '0' then
                  -- Shift the data up the pipeline
                  v.rdOut(i)   := r.rdOut(i-1);
                  -- Clear the cell that the data was shifted from
                  v.rdOut(i-1) := VC64_DATA_INIT_C;
               end if;
            end loop;
            -- Check if we need to advance the lowest stage
            if r.rdOut(0).valid = '0' then
               -- Shift the data up the pipeline
               v.rdOut(0)       := r.rdBuffer;
               -- Clear the buffer
               v.rdBuffer.valid := '0';
            end if;
            -- Check if last cycle was pulling the FIFO
            if r.ready = '1' then
               -- Reset the ready flag
               v.ready := '0';
               -- Check for a FIFO read
               if valid = '1' then
                  -- Check where we need to write the data
                  if r.rdOut(0).valid = '0' then
                     -- Shift the data up the pipeline
                     v.rdOut(0) := readOut;
                  else
                     -- Save the value in the buffer
                     v.rdBuffer := readOut;
                  end if;
               end if;
            else
               -- Check that we cleared the buffers
               if (r.rdOut(0).valid = '0') and (r.rdBuffer.valid = '0') then
                  -- Set the ready flag
                  v.ready := '1';
               end if;
            end if;
         end if;

         -- Reset
         if (vcRdRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         ready <= r.ready;
         rdOut <= r.rdOut;
         
      end process comb;

      seq : process (vcRdClk) is
      begin
         if rising_edge(vcRdClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
