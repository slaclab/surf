-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-15
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used as a mux'd FIFO interface 
--                for a VC64 channel.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of virtual channels during the middle of a frame transfer.
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
      -- General Configurations
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      RST_POLARITY_G     : sl                         := '1';  -- '1' for active HIGH reset, '0' for active LOW reset    
      -- Cascading FIFO Configurations
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      LAST_STAGE_ASYNC_G : boolean                    := true;  -- if set to true, the last stage will be the ASYNC FIFO      
      -- RX Configurations
      EN_FRAME_FILTER_G  : boolean                    := true;
      -- TX Configurations
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      -- Xilinx Specific Configurations
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G     : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      -- Altera Specific Configurations
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      -- FIFO Configurations
      BRAM_EN_G          : boolean                    := true;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_FIXED_THES_G  : boolean                    := true;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 2**24;
      -- Note: If FIFO_FIXED_THES_G = true, then the fixed FIFO_AFULL_THRES_G is used.
      --       If FIFO_FIXED_THES_G = false, then the programmable threshold (vcRxThreshold) is used.      
      LITTLE_ENDIAN_G    : boolean                    := true;
      -- RX Configurations
      RX_WIDTH_G        : integer range 8  to 64  := 16;   -- Bits: 8, 16, 32 or 64
      TX_WIDTH_G        : integer range 8  to 64  := 16);  -- Bits: 8, 16, 32 or 64
   port (
      vcRxAlignError : out sl;
      -- RX Frame Filter Status (vcRxClk domain) 
      vcRxDropWrite  : out sl;
      vcRxTermFrame  : out sl;
      -- Programmable RX Flow Control (vcRxClk domain)
      vcRxThreshold  : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData       : in  Vc64DataType;
      vcRxCtrl       : out Vc64CtrlType;
      vcRxClk        : in  sl;
      vcRxRst        : in  sl := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl       : in  Vc64CtrlType;
      vcTxData       : out Vc64DataType;
      vcTxClk        : in  sl;
      vcTxRst        : in  sl := '0');
begin
   assert (RX_WIDTH_G = 8 or RX_WIDTH_G = 16 or RX_WIDTH_G = 32 or RX_WIDTH_G = 64 ) 
      report "RX_WIDTH_G must not be = 8, 16, 32 or 64" severity failure;
   assert (TX_WIDTH_G = 8 or TX_WIDTH_G = 16 or TX_WIDTH_G = 32 or TX_WIDTH_G = 64 ) 
      report "TX_WIDTH_G must not be = 8, 16, 32 or 64" severity failure;
   assert ((RX_WIDTH_G >= TX_WIDTH_G and RX_WIDTH_G mod TX_WIDTH_G = 0) or
           (TX_WIDTH_G > RX_WIDTH_G and TX_WIDTH_G mod RX_WIDTH_G = 0))
      report "Data widths must be even number multiples of each other" severity failure;
end Vc64FifoMux;

architecture mapping of Vc64FifoMux is

   constant FIFO_WIDTH_C : integer := ite(RX_WIDTH_G > TX_WIDTH_G, RX_WIDTH_G, TX_WIDTH_G);

   ----------------
   -- Write Signals
   ----------------
   constant WR_LOGIC_EN_C : boolean := (RX_WIDTH_G < TX_WIDTH_G);
   constant WR_SIZE_C     : integer := ite(WR_LOGIC_EN_C, TX_WIDTH_G / RX_WIDTH_G, 1);

   type WrRegType is record
      count    : slv(2 downto 0);
      wrData   : Vc64DataType;
      alignErr : sl;
   end record WrRegType;

   constant WR_REG_INIT_C : WrRegType := (
      count    => (others => '0'),
      wrData   => VC64_DATA_INIT_C,
      alignErr => '0');

   signal wrR, wrRin : WrRegType := WR_REG_INIT_C;

   signal fifoRxData : Vc64DataType;
   signal fifoRxCtrl : Vc64CtrlType;

   ---------------
   -- Read Signals
   ---------------
   constant RD_LOGIC_EN_C : boolean := (TX_WIDTH_G < RX_WIDTH_G);
   constant RD_SIZE_C     : integer := ite(RD_LOGIC_EN_C, RX_WIDTH_G / TX_WIDTH_G, 1);

   type RdRegType is record
      count  : slv(2 downto 0);
      rdData : Vc64DataType;
      rdCtrl : Vc64CtrlType;
   end record RdRegType;

   constant RD_REG_INIT_C : RdRegType := (
      count  => (others => '0'),
      rdData => VC64_DATA_INIT_C,
      rdCtrl => VC64_CTRL_INIT_C);

   signal rdR, rdRin   : RdRegType := RD_REG_INIT_C;

   signal fifoTxData : Vc64DataType;
   signal fifoTxCtrl : Vc64CtrlType;

begin

   -------------------------
   -- Write Logic
   -------------------------
   wrComb : process (vcRxData, wrR) is
      variable v     : WrRegType;
      variable idx   : integer;
   begin
      v := wrR;

      v.wrData.valid := '0';
      v.alignErr     := '0';

      if LITTLE_ENDIAN_G then
         idx := conv_integer(wrR.count);
      else
         idx := (WR_SIZE_C-1)-conv_integer(wrR.count);
      end if;

      v.wrData.data((RX_WIDTH_G*idx)+(RX_WIDTH_G-1) downto (RX_WIDTH_G*idx)) := vcRxData.data(RX_WIDTH_G-1 downto 0);

      v.wrData.vc   := vcRxData.vc;
      v.wrData.eof  := vcRxData.eof;
      v.wrData.eofe := vcRxData.eofe;

      -- SOF only on first word
      if ( wrR.count = 0 ) then
         v.wrData.sof := vcRxData.sof;
      end if;

      if vcRxData.valid = '1' then
         v.count := wrR.count + 1;

         -- Ready for write
         if (wrR.count = WR_SIZE_C-1) then
            v.count        := (others => '0');
            v.wrData.valid := '1';
            v.wrData.size  := ite(TX_WIDTH_G=64,'1','0');

         -- Early EOF at unaligned boundary
         elsif vcRxData.eof = '1' then
            v.count        := (others => '0');
            v.wrData.valid := '1';
            v.wrData.size  := '0';

            -- Early EOF allowed for RX = 32 and TX = 64, otherwise error
            if RX_WIDTH_G /= 32 or TX_WIDTH_G /= 64 then
               v.wrData.eofe := '1';
               v.alignErr    := '1';
            end if;
         end if;
      end if;

      wrRin          <= v;
      vcRxAlignError <= wrR.alignErr;

      -- Write logic enabled
      if WR_LOGIC_EN_C then
         fifoRxData <= wrR.wrData;

      -- Bypass write logic
      else
         fifoRxData <= vcRxData;
      end if;

   end process wrComb;

   wrSeq : process (vcRxClk, vcRxRst) is
   begin
      if (RST_ASYNC_G and vcRxRst = RST_POLARITY_G) then
         wrR <= WR_REG_INIT_C after TPD_G;
      elsif (rising_edge(vcRxClk)) then
         if (RST_ASYNC_G = false and vcRxRst = RST_POLARITY_G) then
            wrR <= WR_REG_INIT_C after TPD_G;
         else
            wrR <= wrRin after TPD_G;
         end if;
      end if;
   end process wrSeq;

   -- Output control directly
   vcRxCtrl <= fifoRxCtrl;

   -------------------------
   -- FIFO
   -------------------------

   U_Vc64Fifo : entity work.Vc64Fifo
      generic map (
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         VC_WIDTH_G          => FIFO_WIDTH_C,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G  => LAST_STAGE_ASYNC_G,
         EN_FRAME_FILTER_G   => EN_FRAME_FILTER_G,
         IGNORE_TX_READY_G   => false,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         BRAM_EN_G           => BRAM_EN_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_SYNC_STAGES_G  => FIFO_SYNC_STAGES_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THES_G   => FIFO_FIXED_THES_G,
         FIFO_AFULL_THRES_G  => FIFO_AFULL_THRES_G
      ) port map (
         vcRxDropWrite       => vcRxDropWrite,
         vcRxTermFrame       => vcRxTermFrame,
         vcRxThreshold       => vcRxThreshold,
         vcRxData            => fifoRxData,
         vcRxCtrl            => fifoRxCtrl,
         vcRxClk             => vcRxClk,
         vcRxRst             => vcRxRst,
         vcTxCtrl            => fifoTxCtrl,
         vcTxData            => fifoTxData,
         vcTxClk             => vcTxClk,
         vcTxRst             => vcTxRst
      );

   -------------------------
   -- Read Logic
   -------------------------

   rdComb : process (fifoTxData, rdR, vcTxCtrl) is
      variable v        : RdRegType;
      variable idx      : integer;
      variable fifoRdEn : boolean;
   begin
      v   := rdR;

      v.rdCtrl.overflow   := vcTxCtrl.overflow;
      v.rdCtrl.almostFull := vcTxCtrl.almostFull;
      v.rdCtrl.ready      := '0';

      if LITTLE_ENDIAN_G then
         idx := conv_integer(rdR.count);
      else
         idx := (RD_SIZE_C-1)-conv_integer(rdR.count);
      end if;

      v.rdData.data(TX_WIDTH_G-1 downto 0) := fifoTxData.data((TX_WIDTH_G*idx)+(TX_WIDTH_G-1) downto (TX_WIDTH_G*idx));

      v.rdData.vc    := fifoTxData.vc;
      v.rdData.size  := '0'; -- Always zero since tx size is not 64
      v.rdData.valid := fifoTxData.valid;

      -- First value
      if rdR.count = 0 then
         v.rdData.sof := fifoTxData.sof;
      else
         v.rdData.sof := '0';
      end if;

      -- Last value when RX = 64 and TX = 32 and size = '0' or reached aligned count
      if (rdR.count = (RD_SIZE_C-1) ) or (RX_WIDTH_G = 64 and TX_WIDTH_G = 32 and fifoTxData.size = '0') then
         fifoRdEn       := true;
         v.rdData.eof   := fifoTxData.eof;
         v.rdData.eofe  := fifoTxData.eofe;
      else
         fifoRdEn       := false;
         v.rdData.eof   := '0';
         v.rdData.eofe  := '0';
      end if;

      -- Advance
      if fifoTxData.valid = '1' and vcTxCtrl.ready = '1' then
         v.count := rdR.count + 1;

         if fifoRdEn then
            v.rdCtrl.ready := '1';
            v.count        := (others => '0');
         end if;
      end if;

      rdRin <= v;

      -- Read logic enabled
      if RD_LOGIC_EN_C then
         vcTxData   <= v.rdData;
         fifoTxCtrl <= v.rdCtrl;

      -- Bypass read logic
      else
         vcTxData   <= fifoTxData;
         fifoTxCtrl <= vcTxCtrl;
      end if;
      
   end process rdComb;

   -- If fifo is asynchronous, must use async reset on rd side.
   rdSeq : process (vcTxClk, vcTxRst) is
   begin
      if (GEN_SYNC_FIFO_G = false and vcTxRst = RST_POLARITY_G) then
         rdR <= RD_REG_INIT_C after TPD_G;
      elsif (rising_edge(vcTxClk)) then
         if (GEN_SYNC_FIFO_G and RST_ASYNC_G = false and vcTxRst = RST_POLARITY_G) then
            rdR <= RD_REG_INIT_C after TPD_G;
         else
            rdR <= rdRin after TPD_G;
         end if;
      end if;
   end process rdSeq;

end mapping;

