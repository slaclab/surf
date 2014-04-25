-------------------------------------------------------------------------------
-- Title      : AXI Stream FIFO / Re-sizer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamFifo.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-04-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to serve as an async FIFO for AXI Streams. This block also allows the
-- bus to be compress/expanded, allowing different standard sizes on each side
-- of the FIFO. Re-sizing is always little endian. 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamFifo is
   generic (

      -- General Configurations
      TPD_G              : time                       := 1 ns;

      -- FIFO configurations
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";
      USE_BUILT_IN_G      : boolean                    := false;
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      FIFO_FIXED_THRESH_G : boolean                    := true;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 500;

      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType        := AXI_STREAM_CONFIG_INIT_C
   );
   port (

      -- Slave Port
      slvAxiClk          : in  sl;
      slvAxiRst          : in  sl;
      slvAxiStreamMaster : in  AxiStreamMasterType;
      slvAxiStreamSlave  : out AxiStreamSlaveType;

      -- Master Port
      mstAxiClk          : in  sl;
      mstAxiRst          : in  sl;
      mstAxiStreamMaster : out AxiStreamMasterType;
      mstAxiStreamSlave  : in  AxiStreamSlaveType;

      -- FIFO status & config , synchronous to slvAxiClk
      fifoOverflow       : out sl;
      fifoPause          : out sl;
      fifoPauseThresh    : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1')
   );
begin
   assert ((SLAVE_AXI_CONFIG_G.TDATA_BYTES_C  >= MASTER_AXI_CONFIG_G.TDATA_BYTES_C and 
            SLAVE_AXI_CONFIG_G.TDATA_BYTES_C mod MASTER_AXI_CONFIG_G.TDATA_BYTES_C = 0) or
           (MASTER_AXI_CONFIG_G.TDATA_BYTES_C >= SLAVE_AXI_CONFIG_G.TDATA_BYTES_C and
            MASTER_AXI_CONFIG_G.TDATA_BYTES_C mod SLAVE_AXI_CONFIG_G.TDATA_BYTES_C = 0))
      report "Data widths must be even number multiples of each other" severity failure;

   assert (SLAVE_AXI_CONFIG_G.TSTRB_EN_C = MASTER_AXI_CONFIG_G.TSTRB_EN_C )
      report "TSTRB_EN_C of master and slave ports must match" severity failure;

   assert (SLAVE_AXI_CONFIG_G.TDEST_BITS_C = MASTER_AXI_CONFIG_G.TDEST_BITS_C )
      report "TDEST_BITS_C of master and slave ports must match" severity failure;

   assert (SLAVE_AXI_CONFIG_G.TID_BITS_C = MASTER_AXI_CONFIG_G.TID_BITS_C )
      report "TID_BITS_C of master and slave ports must match" severity failure;

   assert (SLAVE_AXI_CONFIG_G.TUSER_BITS_PER_BYTE_C = MASTER_AXI_CONFIG_G.TUSER_BITS_PER_BYTE_C )
      report "TUSER_BITS_PER_BYTE_C of master and slave ports must match" severity failure;

   assert (MASTER_AXI_CONFIG_G.TKEEP_EN_C = true or 
           ( (MASTER_AXI_CONFIG_G.TDATA_BYTES_C <= SLAVE_AXI_CONFIG_G.TDATA_BYTES_C) and
             (SLAVE_AXI_CONFIG_G.TKEEP_EN_C = false) ) ) 
      report "TKEEP_EN_C of master must be enabled if master is wider than slave or slave has TKEEP_EN_C set" severity failure;

end AxiStreamFifo;

architecture mapping of AxiStreamFifo is 

   -- Configure FIFO widths
   constant DATA_BYTES_C  : integer := ite( SLAVE_AXI_CONFIG_G.TDATA_BYTES_C > MASTER_AXI_CONFIG_G.TDATA_BYTES_C, 
                                           SLAVE_AXI_CONFIG_G.TDATA_BYTES_C, MASTER_AXI_CONFIG_G.TDATA_BYTES_C);

   constant S_KEEP_BITS_C : integer := ite(SLAVE_AXI_CONFIG_G.TKEEP_EN_C,bitSize(DATA_BYTES_C),0);
   constant M_KEEP_BITS_C : integer := ite(MASTER_AXI_CONFIG_G.TKEEP_EN_C,bitSize(DATA_BYTES_C),0);
   constant KEEP_BITS_C   : integer := ite(S_KEEP_BITS_C > M_KEEP_BITS_C,S_KEEP_BITS_C,M_KEEP_BITS_C);

   constant DATA_BITS_C : integer := (DATA_BYTES_C * 8);
   constant STRB_BITS_C : integer := ite(SLAVE_AXI_CONFIG_G.TSTRB_EN_C,DATA_BYTES_C,0);
   constant DEST_BITS_C : integer := SLAVE_AXI_CONFIG_G.TDEST_BITS_C;
   constant ID_BITS_C   : integer := SLAVE_AXI_CONFIG_G.TID_BITS_C;
   constant USER_BITS_C : integer := (DATA_BYTES_C * SLAVE_AXI_CONFIG_G.TUSER_BITS_PER_BYTE_C);

   constant FIFO_BITS_C : integer := DATA_BITS_C + USER_BITS_C + 1 + STRB_BITS_C + KEEP_BITS_C + DEST_BITS_C + ID_BITS_C;

   constant WR_BYTES_C  : integer := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant RD_BYTES_C  : integer := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   -- Convert record to slv
   function iaxiToSlv ( din : AxiStreamMasterType ) return slv is
      variable retValue : slv(FIFO_BITS_C-1 downto 0);
      variable i        : integer;
   begin
      i := 0;

      retValue(DATA_BITS_C-1 downto 0) := din.tData(DATA_BITS_C-1 downto 0);
      i := i + DATA_BITS_C;

      retValue((USER_BITS_C+i)-1 downto i) := din.tUser(USER_BITS_C-1 downto 0);
      i := i + USER_BITS_C;

      retValue(i) := din.tLast;
      i := i + 1;

      if STRB_BITS_C > 0 then
         retValue((STRB_BITS_C+i)-1 downto i) := din.tStrb(STRB_BITS_C-1 downto 0);
         i := i + STRB_BITS_C;
      end if;

      if KEEP_BITS_C > 0 then
         retValue((KEEP_BITS_C+i)-1 downto i) := onesCount(din.tKeep(DATA_BYTES_C-1 downto 0));
         i := i + KEEP_BITS_C;
      end if;

      if DEST_BITS_C > 0 then
         retValue((DEST_BITS_C+i)-1 downto i) := din.tDest(DEST_BITS_C-1 downto 0);
         i := i + DEST_BITS_C;
      end if;

      if ID_BITS_C > 0 then
         retValue((ID_BITS_C+i)-1 downto i) := din.tId(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      return(retValue);

   end function;

   -- Convert slv to record
   function islvToAxi ( din : slv(FIFO_BITS_C-1 downto 0) ) return AxiStreamMasterType is
      variable retValue : AxiStreamMasterType;
      variable i,j      : integer;
   begin
      i := 0;
      retValue := AXI_STREAM_MASTER_INIT_C;

      retValue.tData(DATA_BITS_C-1 downto 0) := din(DATA_BITS_C-1 downto 0);
      i := i + DATA_BITS_C;

      retValue.tUser(USER_BITS_C-1 downto 0) := din((USER_BITS_C+i)-1 downto i);
      i := i + USER_BITS_C;

      retValue.tLast := din(i);
      i := i + 1;

      if STRB_BITS_C > 0 then
         retValue.tStrb(STRB_BITS_C-1 downto 0) := din((STRB_BITS_C+i)-1 downto i);
         i := i + STRB_BITS_C;
      end if;

      if KEEP_BITS_C > 0 then
         for j in 0 to conv_integer(din((KEEP_BITS_C+i)-1 downto i)) loop
            retValue.tKeep(j) := '1';
         end loop;
         i := i + KEEP_BITS_C;
      end if;

      if DEST_BITS_C > 0 then
         retValue.tDest(DEST_BITS_C-1 downto 0) := din((DEST_BITS_C+i)-1 downto i);
         i := i + DEST_BITS_C;
      end if;

      if ID_BITS_C > 0 then
         retValue.tId(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := i + ID_BITS_C;
      end if;

      return(retValue);

   end function;


   ----------------
   -- Write Signals
   ----------------
   constant WR_LOGIC_EN_C : boolean := (WR_BYTES_C < RD_BYTES_C);
   constant WR_SIZE_C     : integer := ite(WR_LOGIC_EN_C, WR_BYTES_C / RD_BYTES_C, 1);

   type WrRegType is record
      count     : slv(bitSize(WR_SIZE_C)-1 downto 0);
      wrMaster  : AxiStreamMasterType;
      wrSlave   : AxiStreamSlaveType;
   end record WrRegType;

   constant WR_REG_INIT_C : WrRegType := (
      count     => (others => '0'),
      wrMaster  => AXI_STREAM_MASTER_INIT_C,
      wrSlave   => AXI_STREAM_SLAVE_INIT_C
   );

   signal wrR, wrRin : WrRegType := WR_REG_INIT_C;

   signal fifoDin   : slv(FIFO_BITS_C-1 downto 0);
   signal fifoWrite : sl;
   signal fifoCount : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal fifoAFull : sl;
   signal fifoPFull : sl;

   ---------------
   -- Read Signals
   ---------------
   constant RD_LOGIC_EN_C : boolean := (RD_BYTES_C < WR_BYTES_C);
   constant RD_SIZE_C     : integer := ite(RD_LOGIC_EN_C, RD_BYTES_C / WR_BYTES_C, 1);

   type RdRegType is record
      count    : slv(bitSize(RD_SIZE_C)-1 downto 0);
      rdMaster : AxiStreamMasterType;
      ready    : sl;
   end record RdRegType;

   constant RD_REG_INIT_C : RdRegType := (
      count    => (others => '0'),
      rdMaster => AXI_STREAM_MASTER_INIT_C,
      ready    => '0'
   );

   signal rdR, rdRin : RdRegType := RD_REG_INIT_C;

   signal fifoDout  : slv(FIFO_BITS_C-1 downto 0);
   signal fifoRead  : sl;
   signal fifoValid : sl;

begin

   -------------------------
   -- Write Logic
   -------------------------
   wrComb : process ( wrR, slvAxiStreamMaster, fifoAFull ) is
      variable v     : WrRegType;
      variable idx   : integer;
   begin
      v   := wrR;
      idx := conv_integer(wrR.count);

      v.wrSlave.tReady  := not fifoAFull;
      v.wrMaster.tValid := '0';

      -- Advance pipeline
      if fifoAFull = '0' then

         -- init when count = 0
         if (wrR.count = 0) then
            v.wrMaster.tKeep := (others=>'0');
            v.wrMaster.tData := (others=>'0');
            v.wrMaster.tStrb := (others=>'0');
            v.wrMaster.tUser := (others=>'0');
         end if;

         v.wrMaster.tData((WR_BYTES_C*8*idx)+((WR_BYTES_C*8)-1) downto (WR_BYTES_C*8*idx)) := slvAxiStreamMaster.tData((WR_BYTES_C*8)-1 downto 0);
         v.wrMaster.tStrb((WR_BYTES_C*idx)+(WR_BYTES_C-1) downto (WR_BYTES_C*idx))         := slvAxiStreamMaster.tStrb(WR_BYTES_C-1 downto 0);
         v.wrMaster.tKeep((WR_BYTES_C*idx)+(WR_BYTES_C-1) downto (WR_BYTES_C*idx))         := slvAxiStreamMaster.tKeep(WR_BYTES_C-1 downto 0);

         -- tUser needs to be optmized for some FIFO modes... TBD
         v.wrMaster.tUser((USER_BITS_C*idx)+(USER_BITS_C-1) downto (USER_BITS_C*idx)) := slvAxiStreamMaster.tUser(USER_BITS_C-1 downto 0);

         v.wrMaster.tDest := slvAxiStreamMaster.tDest;
         v.wrMaster.tId   := slvAxiStreamMaster.tId;
         v.wrMaster.tLast := slvAxiStreamMaster.tLast;

         -- Determine end mode, valid and ready
         if slvAxiStreamMaster.tValid = '1' then
            if (wrR.count = (WR_SIZE_C-1) or slvAxiStreamMaster.tLast = '1') then
               v.wrMaster.tValid := '1';
               v.count           := (others=>'0');
            else
               v.wrMaster.tvalid := '0';
               v.count           := wrR.count + 1;
            end if;
         end if;

      end if;

      wrRin <= v;

      -- Write logic enabled
      if WR_LOGIC_EN_C then
         slvAxiStreamSlave <= v.wrSlave;
         fifoDin           <= iaxiToSlv(wrR.wrMaster);
         fifoWrite         <= wrR.wrMaster.tValid;

      -- Bypass write logic
      else
         slvAxiStreamSlave.tReady <= not fifoAFull;
         fifoDin                  <= iaxiToSlv(slvAxiStreamMaster);
         fifoWrite                <= slvAxiStreamMaster.tValid;
      end if;

   end process wrComb;

   wrSeq : process (slvAxiClk) is
   begin
      if (rising_edge(slvAxiClk)) then
         if slvAxiRst = '1' then
            wrR <= WR_REG_INIT_C after TPD_G;
         else
            wrR <= wrRin after TPD_G;
         end if;
      end if;
   end process wrSeq;


   -------------------------
   -- FIFO
   -------------------------

   -- Pause generation
   process (slvAxiClk, fifoPFull) is
   begin
      if FIFO_FIXED_THRESH_G then
         fifoPause <= fifoPFull after TPD_G;
      elsif (rising_edge(slvAxiClk)) then
         if slvAxiRst = '1' or fifoCount > fifoPauseThresh then
            fifoPause <= '1' after TPD_G;
         else
            fifoPause <= '0' after TPD_G;
         end if;
      end if;
   end process;

   U_Fifo : entity work.FifoCascade 
      generic map (
         TPD_G               => TPD_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G  => true,
         RST_POLARITY_G      => '1',
         RST_ASYNC_G         => false,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         BRAM_EN_G           => BRAM_EN_G,
         FWFT_EN_G           => true,
         USE_DSP48_G         => "no",
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         USE_BUILT_IN_G      => USE_BUILT_IN_G,
         XIL_DEVICE_G        => XIL_DEVICE_G,
         SYNC_STAGES_G       => 3,
         DATA_WIDTH_G        => FIFO_BITS_C,
         ADDR_WIDTH_G        => FIFO_ADDR_WIDTH_G,
         INIT_G              => "0",
         FULL_THRES_G        => FIFO_PAUSE_THRESH_G,
         EMPTY_THRES_G       => 1
      ) port map (
         rst           => slvAxiRst,
         wr_clk        => slvAxiClk,
         wr_en         => fifoWrite,
         din           => fifoDin,
         wr_data_count => fifoCount,
         wr_ack        => open,
         overflow      => fifoOverflow,
         prog_full     => fifoPFull,
         almost_full   => fifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => mstAxiClk,
         rd_en         => fifoRead,
         dout          => fifoDout,
         rd_data_count => open,
         valid         => fifoValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
      );


   -------------------------
   -- Read Logic
   -------------------------

   rdComb : process ( rdR, fifoDout, fifoValid, mstAxiStreamSlave ) is
      variable v          : RdRegType;
      variable idx        : integer;
      variable fifoMaster : AxiStreamMasterType;
   begin
      v          := rdR;
      fifoMaster := islvToAxi ( fifoDout );
      idx        := conv_integer(rdR.count);

      -- Advance pipeline
      if mstAxiStreamSlave.tReady = '1' then
         v.rdMaster   := AXI_STREAM_MASTER_INIT_C;

         v.rdMaster.tData((RD_BYTES_C*8)-1 downto 0) := fifoMaster.tData((RD_BYTES_C*8*idx)+((RD_BYTES_C*8)-1) downto (RD_BYTES_C*8*idx));
         v.rdMaster.tStrb(RD_BYTES_C-1 downto 0)     := fifoMaster.tStrb((RD_BYTES_C*idx)+(RD_BYTES_C-1) downto (RD_BYTES_C*idx));
         v.rdMaster.tKeep(RD_BYTES_C-1 downto 0)     := fifoMaster.tKeep((RD_BYTES_C*idx)+(RD_BYTES_C-1) downto (RD_BYTES_C*idx));

         -- tUser needs to be optmized for some FIFO modes... TBD
         v.rdMaster.tUser(USER_BITS_C-1 downto 0) := fifoMaster.tUser((USER_BITS_C*idx)+(USER_BITS_C-1) downto (USER_BITS_C*idx));

         v.rdMaster.tDest  := fifoMaster.tDest;
         v.rdMaster.tId    := fifoMaster.tId;
         v.rdMaster.tValid := fifoValid;

         -- Reached end of fifo data or no more valid bits in last word
         if (rdR.count = (RD_SIZE_C-1) ) or (v.rdMaster.tKeep = 0 and fifoMaster.tLast = '1') then
            v.count          := (others=>'0');
            v.ready          := '1';
            v.rdMaster.tLast := fifoMaster.tLast;
         else
            v.count          := rdR.count + 1;
            v.ready          := '0';
            v.rdMaster.tLast := '0';
         end if;
      end if;

      rdRin <= v;

      -- Read logic enabled
      if RD_LOGIC_EN_C then
         mstAxiStreamMaster <= v.rdMaster;
         fifoRead           <= v.ready;

      -- Bypass read logic
      else
         mstAxiStreamMaster <= islvToAxi ( fifoDout );
         fifoRead           <= mstAxiStreamSlave.tReady;
      end if;
      
   end process rdComb;

   -- If fifo is asynchronous, must use async reset on rd side.
   rdSeq : process (mstAxiClk) is
   begin
      if (rising_edge(mstAxiClk)) then
         if mstAxiRst = '1' then
            rdR <= RD_REG_INIT_C after TPD_G;
         else
            rdR <= rdRin after TPD_G;
         end if;
      end if;
   end process rdSeq;

end mapping;

