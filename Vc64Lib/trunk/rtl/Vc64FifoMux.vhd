-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoMux.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoMux is
   generic (
      TPD_G              : time                       := 1 ns;
      RX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
      TX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
      LITTLE_ENDIAN_G    : boolean                    := false;
      RST_ASYNC_G        : boolean                    := false;
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      BRAM_EN_G          : boolean                    := true;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 256);
   port (
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData : in  Vc64DataType;
      vcRxCtrl : out Vc64CtrlType;
      vcRxClk  : in  sl;
      vcRxRst  : in  sl := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl : in  Vc64CtrlType;
      vcTxData : out Vc64DataType;
      vcTxClk  : in  sl;
      vcTxRst  : in  sl := '0');
end Vc64FifoMux;

architecture rtl of Vc64FifoMux is

   constant WR_DATA_WIDTH_C : integer := 24*RX_LANES_G;
   constant RD_DATA_WIDTH_C : integer := 24*TX_LANES_G;

   signal din  : slv(WR_DATA_WIDTH_C-1 downto 0);
   signal dout : slv(RD_DATA_WIDTH_C-1 downto 0);
   signal rdEn,
      valid,
      progFull,
      overflow,
      ready : sl;
   
   type RegType is record
      ready    : sl;
      rdBuffer : Vc64DataType;
      rdOut    : Vc64DataArray(0 to PIPE_STAGES_G);
   end record RegType;
   constant REG_INIT_C : RegType := (
      '0',
      VC64_DATA_INIT_C,
      (others => VC64_DATA_INIT_C));
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal readOut  : Vc64DataType;
   signal writeOut : Vc64CtrlType;
   signal rdOut    : Vc64DataArray(0 to PIPE_STAGES_G) := (others => VC64_DATA_INIT_C);
   
begin

   -- Outputs
   vcRxCtrl <= writeOut;
   vcTxData <= rdOut(PIPE_STAGES_G);

   -- Assign data based on lane generics
   STATUS_HDR : process (vcRxData) is
      variable i : integer;
   begin
      din <= (others => '0');           -- Default everything to zero
      for i in (RX_LANES_G-1) downto 0 loop
         -- Map the upper word flags
         if (i = (RX_LANES_G-1)) then
            din(i*24+23)                    <= vcRxData.size;
            din((i*24+22) downto (i*24+19)) <= vcRxData.vc;
            din(i*24+18)                    <= vcRxData.sof;
         end if;
         -- Map the lower word flags
         if (i = 0) then
            din(i*24+17) <= vcRxData.eof;
            din(i*24+16) <= vcRxData.eofe;
         end if;
         -- Map the data bus
         din(i*24+15 downto i*24) <= vcRxData.data(i*16+15 downto i*16);
      end loop;
   end process STATUS_HDR;

   -- Update the writing status flags
   writeOut.ready      <= not(progFull);
   writeOut.almostFull <= progFull;
   writeOut.overflow   <= overflow;

   FifoMux_Inst : entity work.FifoMux
      generic map (
         TPD_G           => TPD_G,
         WR_DATA_WIDTH_G => WR_DATA_WIDTH_C,
         RD_DATA_WIDTH_G => RD_DATA_WIDTH_C,
         LITTLE_ENDIAN_G => LITTLE_ENDIAN_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         BRAM_EN_G       => BRAM_EN_G,
         FWFT_EN_G       => true,
         ALTERA_SYN_G    => ALTERA_SYN_G,
         ALTERA_RAM_G    => ALTERA_RAM_G,
         USE_BUILT_IN_G  => false,
         SYNC_STAGES_G   => FIFO_SYNC_STAGES_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         FULL_THRES_G    => FIFO_AFULL_THRES_G)
      port map (
         -- Resets
         rst       => vcTxRst,
         --Write Ports (wr_clk domain)
         wr_clk    => vcTxClk,
         wr_en     => vcRxData.valid,
         din       => din,
         prog_full => progFull,
         overflow  => overflow,
         --Read Ports (rd_clk domain)
         rd_clk    => vcRxClk,
         rd_en     => rdEn,
         dout      => dout,
         valid     => valid);

   -- Check if we are ready to read the FIFO
   rdEn <= valid and ready;

   -- Pass the FIFO's valid signal
   readOut.valid <= valid;

   -- upper word flags
   readOut.size <= dout((TX_LANES_G-1)*24+23);
   readOut.vc   <= dout(((TX_LANES_G-1)*24+22) downto ((TX_LANES_G-1)*24+19));
   readOut.sof  <= dout((TX_LANES_G-1)*24+18);

   -- lower word flags
   readOut.eof  <= dout(17);
   readOut.eofe <= dout(16);

   -- Assign data based on lane generics
   dataLoop : for i in (TX_LANES_G-1) downto 0 generate
      readOut.data(i*16+15 downto i*16) <= dout(i*24+15 downto i*24);
   end generate dataLoop;

   maxLaneCheck : if (TX_LANES_G /= 4) generate
      zeroLoop : for i in 3 downto TX_LANES_G generate
         readOut.data(i*16+15 downto i*16) <= (others => '0');
      end generate zeroLoop;
   end generate;

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      rdOut(0) <= readOut;
      ready    <= vcTxCtrl.ready;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate
      
      comb : process (r, readOut, valid, vcRxRst, vcTxCtrl) is
         variable i : integer;
         variable j : integer;
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Check the external ready signal
         if vcTxCtrl.ready = '1' then
            -- Check that we have cleared out the rdBuffer
            if r.rdBuffer.valid = '1' then
               -- Reset the ready flag
               v.ready    := '0';
               -- Pipeline the readout records
               v.rdOut(0) := r.rdBuffer;
               for i in 1 to PIPE_STAGES_G loop
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
               for i in 1 to PIPE_STAGES_G loop
                  v.rdOut(i) := r.rdOut(i-1);
               end loop;
            end if;
         else
            -- Check if we need to advance the pipeline
            for i in PIPE_STAGES_G downto 1 loop
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
         if (vcRxRst = '1') then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         ready <= r.ready;
         rdOut <= r.rdOut;
         
      end process comb;

      seq : process (vcRxClk) is
      begin
         if rising_edge(vcRxClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;
   
end rtl;
