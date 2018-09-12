-------------------------------------------------------------------------------
-- File       : AxiStreamFifo.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2016-08-31
-------------------------------------------------------------------------------
-- Description:
-- Block to serve as an async FIFO for AXI Streams. This block also allows the
-- bus to be compress/expanded, allowing different standard sizes on each side
-- of the FIFO. Re-sizing is always little endian. 
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamFifo is
   generic (

      -- General Configurations
      TPD_G               : time                       := 1 ns;
      INT_PIPE_STAGES_G   : natural range 0 to 16      := 0;  -- Internal FIFO setting
      PIPE_STAGES_G       : natural range 0 to 16      := 1;
      SLAVE_READY_EN_G    : boolean                    := true;
      VALID_THOLD_G       : integer range 0 to (2**24) := 1;  -- =1 = normal operation
                                                              -- =0 = only when frame ready
                                                              -- >1 = only when frame ready or # entries
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
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 1;

      -- If VALID_THOLD_G /=1, FIFO that stores on tLast txns can be smaller.
      -- Set to 0 for same size as primary fifo (default)
      -- Set >4 for custom size.
      -- Use at own risk. Overflow of tLast fifo is not checked      
      LAST_FIFO_ADDR_WIDTH_G : integer range 0 to 48 := 0;

      -- Index = 0 is output, index = n is input
      CASCADE_PAUSE_SEL_G : integer range 0 to (2**24) := 0;

      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
      );
   port (

      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

      -- FIFO status & config , synchronous to sAxisClk
      fifoPauseThresh : in slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      mTLastTUser : out slv(127 downto 0));  -- when VALID_THOLD_G /= 1, used to look ahead at tLast's tUser
end AxiStreamFifo;

architecture rtl of AxiStreamFifo is

   constant FIFO_AXIS_CONFIG_C : AxiStreamConfigType := ite(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C > MASTER_AXI_CONFIG_G.TDATA_BYTES_C, SLAVE_AXI_CONFIG_G, MASTER_AXI_CONFIG_G);

   constant LAST_FIFO_ADDR_WIDTH_C : integer range 4 to 48 :=
      ite(LAST_FIFO_ADDR_WIDTH_G < 4, FIFO_ADDR_WIDTH_G, LAST_FIFO_ADDR_WIDTH_G);

   constant WR_BYTES_C : integer := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant RD_BYTES_C : integer := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   -- Use wider of two interfaces
   constant DATA_BYTES_C : integer := maximum(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C, MASTER_AXI_CONFIG_G.TDATA_BYTES_C);
   constant DATA_BITS_C  : integer := (DATA_BYTES_C * 8);

   -- Use SLAVE TKEEP Mode
   constant KEEP_MODE_C : TKeepModeType := SLAVE_AXI_CONFIG_G.TKEEP_MODE_C;
   constant KEEP_BITS_C : integer := ite(KEEP_MODE_C = TKEEP_NORMAL_C, DATA_BYTES_C,
                                         ite(KEEP_MODE_C = TKEEP_COMP_C, bitSize(DATA_BYTES_C-1), 0));

   -- User user bit mode of slave
   constant USER_MODE_C : TUserModeType := ite(((WR_BYTES_C = 1) or (RD_BYTES_C = 1)), TUSER_NORMAL_C, SLAVE_AXI_CONFIG_G.TUSER_MODE_C);

   -- Use whichever interface has the least number of user bits
   constant SLAVE_USER_BITS_C  : integer := SLAVE_AXI_CONFIG_G.TUSER_BITS_C;
   constant MASTER_USER_BITS_C : integer := MASTER_AXI_CONFIG_G.TUSER_BITS_C;
   constant FIFO_USER_BITS_C   : integer := minimum(SLAVE_USER_BITS_C, MASTER_USER_BITS_C);

   constant FIFO_USER_TOT_C : integer := ite(USER_MODE_C = TUSER_FIRST_LAST_C, FIFO_USER_BITS_C*2,
                                             ite(USER_MODE_C = TUSER_LAST_C, FIFO_USER_BITS_C,
                                                 ite(USER_MODE_C = TUSER_NORMAL_C, DATA_BYTES_C * FIFO_USER_BITS_C,
                                                     1)));

   -- Use SLAVE settings for strobe, dest and ID bit values
   constant STRB_BITS_C : integer := ite(SLAVE_AXI_CONFIG_G.TSTRB_EN_C, DATA_BYTES_C, 0);
   constant DEST_BITS_C : integer := SLAVE_AXI_CONFIG_G.TDEST_BITS_C;
   constant ID_BITS_C   : integer := SLAVE_AXI_CONFIG_G.TID_BITS_C;

   constant FIFO_BITS_C : integer := 1 + DATA_BITS_C + KEEP_BITS_C + FIFO_USER_TOT_C + STRB_BITS_C + DEST_BITS_C + ID_BITS_C;



   -- Convert record to slv
   function iAxiToSlv (din : AxiStreamMasterType) return slv is
      variable retValue : slv(FIFO_BITS_C-1 downto 0) := (others => '0');
      variable i        : integer                     := 0;
   begin

      -- init, pass last
      assignSlv(i, retValue, din.tLast);

      -- Pack data
      assignSlv(i, retValue, din.tData(DATA_BITS_C-1 downto 0));

      -- Pack keep
      if KEEP_MODE_C = TKEEP_NORMAL_C then
         assignSlv(i, retValue, din.tKeep(KEEP_BITS_C-1 downto 0));
      elsif KEEP_MODE_C = TKEEP_COMP_C then
         assignSlv(i, retValue, toSlv(getTKeep(din.tKeep(DATA_BYTES_C-1 downto 1)), KEEP_BITS_C));  -- Assume lsb is present
      end if;

      -- Pack user bits
      if USER_MODE_C = TUSER_FIRST_LAST_C then
         assignSlv(i, retValue, resize(axiStreamGetUserField(FIFO_AXIS_CONFIG_C, din, 0), FIFO_USER_BITS_C));  -- First byte
         assignSlv(i, retValue, resize(axiStreamGetUserField(FIFO_AXIS_CONFIG_C, din, -1), FIFO_USER_BITS_C));  -- Last valid byte

      elsif USER_MODE_C = TUSER_LAST_C then
         assignSlv(i, retValue, resize(axiStreamGetUserField(FIFO_AXIS_CONFIG_C, din, -1), FIFO_USER_BITS_C));  -- Last valid byte

      else
         for j in 0 to DATA_BYTES_C-1 loop
            assignSlv(i, retValue, resize(axiStreamGetUserField(FIFO_AXIS_CONFIG_C, din, j), FIFO_USER_BITS_C));
         end loop;
      end if;

      -- Strobe is optional
      if STRB_BITS_C > 0 then
         assignSlv(i, retValue, din.tStrb(STRB_BITS_C-1 downto 0));
      end if;

      -- Dest is optional
      if DEST_BITS_C > 0 then
         assignSlv(i, retValue, din.tDest(DEST_BITS_C-1 downto 0));
      end if;

      -- Id is optional
      if ID_BITS_C > 0 then
         assignSlv(i, retValue, din.tId(ID_BITS_C-1 downto 0));
      end if;

      return(retValue);

   end function;

   -- Convert slv to record
   procedure iSlvToAxi (din     : in    slv(FIFO_BITS_C-1 downto 0);
                        valid   : in    sl;
                        master  : inout AxiStreamMasterType;
                        byteCnt : inout integer) is
      variable i    : integer                          := 0;
      variable user : slv(FIFO_USER_BITS_C-1 downto 0) := (others => '0');
   begin

      master := axiStreamMasterInit(MASTER_AXI_CONFIG_G);

      -- Set valid, 
      master.tValid := valid;

      -- Set last
      assignRecord(i, din, master.tLast);

      -- Get data
      assignRecord(i, din, master.tData(DATA_BITS_C-1 downto 0));

      -- Get keep bits
      if KEEP_MODE_C = TKEEP_NORMAL_C then
         assignRecord(i, din, master.tKeep(KEEP_BITS_C-1 downto 0));
         byteCnt := getTKeep(master.tKeep);
      elsif KEEP_MODE_C = TKEEP_COMP_C then
         byteCnt      := conv_integer(din((KEEP_BITS_C+i)-1 downto i))+1;
         master.tKeep := genTKeep(byteCnt);
         i            := i + KEEP_BITS_C;
      else                              -- KEEP_MODE_C = TKEEP_FIXED_C
         master.tKeep := genTKeep(DATA_BYTES_C);
         byteCnt      := DATA_BYTES_C;
         i            := i + KEEP_BITS_C;
      end if;

      -- get user bits
      if USER_MODE_C = TUSER_FIRST_LAST_C then
         assignRecord(i, din, user);
         axiStreamSetUserField (MASTER_AXI_CONFIG_G, master, resize(user, MASTER_USER_BITS_C), 0);  -- First byte

         assignRecord(i, din, user);
         axiStreamSetUserField (MASTER_AXI_CONFIG_G, master, resize(user, MASTER_USER_BITS_C), -1);  -- Last valid byte

      elsif USER_MODE_C = TUSER_LAST_C then
         assignRecord(i, din, user);
         axiStreamSetUserField (MASTER_AXI_CONFIG_G, master, resize(user, MASTER_USER_BITS_C), -1);  -- Last valid byte

      else
         for j in 0 to DATA_BYTES_C-1 loop
            assignRecord(i, din, user);
            axiStreamSetUserField (MASTER_AXI_CONFIG_G, master, resize(user, MASTER_USER_BITS_C), j);
         end loop;
      end if;

      -- Strobe is optional
      if STRB_BITS_C > 0 then
         assignRecord(i, din, master.tStrb(STRB_BITS_C-1 downto 0));
      else
         master.tStrb := master.tKeep;  -- Strobe follows keep if unused
      end if;

      -- Dest is optional
      if DEST_BITS_C > 0 then
         assignRecord(i, din, master.tDest(DEST_BITS_C-1 downto 0));
      end if;

      -- ID is optional
      if ID_BITS_C > 0 then
         assignRecord(i, din, master.tId(ID_BITS_C-1 downto 0));
      end if;

   end iSlvToAxi;

   ----------------
   -- Write Signals
   ----------------
   constant WR_LOGIC_EN_C : boolean := (WR_BYTES_C < RD_BYTES_C);
   constant WR_SIZE_C     : integer := ite(WR_LOGIC_EN_C, RD_BYTES_C / WR_BYTES_C, 1);

   type WrRegType is record
      count    : slv(bitSize(WR_SIZE_C)-1 downto 0);
      wrMaster : AxiStreamMasterType;
   end record WrRegType;

   constant WR_REG_INIT_C : WrRegType := (
      count    => (others => '0'),
      wrMaster => axiStreamMasterInit(SLAVE_AXI_CONFIG_G)
      );

   signal wrR   : WrRegType := WR_REG_INIT_C;
   signal wrRin : WrRegType;

   ----------------
   -- FIFO Signals
   ----------------
   signal fifoDin       : slv(FIFO_BITS_C-1 downto 0);
   signal fifoWrite     : sl;
   signal fifoWriteLast : sl;
   signal fifoWriteUser : slv(FIFO_USER_TOT_C-1 downto 0);
   signal fifoWrCount   : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal fifoRdCount   : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal fifoAFull     : sl;
   signal fifoReady     : sl;
   signal fifoPFull     : sl;
   signal fifoPFullVec  : slv(CASCADE_SIZE_G-1 downto 0);
   signal fifoDout      : slv(FIFO_BITS_C-1 downto 0);
   signal fifoRead      : sl;
   signal fifoReadLast  : sl;
   signal fifoReadUser  : slv(FIFO_USER_TOT_C-1 downto 0) := (others => '0');
   signal fifoValidInt  : sl;
   signal fifoValid     : sl;
   signal fifoValidLast : sl;
   signal fifoInFrame   : sl;

   ---------------
   -- Read Signals
   ---------------
   constant RD_LOGIC_EN_C : boolean := (RD_BYTES_C < WR_BYTES_C);
   constant RD_SIZE_C     : integer := ite(RD_LOGIC_EN_C, WR_BYTES_C / RD_BYTES_C, 1);

   type RdRegType is record
      count    : slv(bitSize(RD_SIZE_C)-1 downto 0);
      bytes    : slv(bitSize(DATA_BYTES_C)-1 downto 0);
      rdMaster : AxiStreamMasterType;
      ready    : sl;
   end record RdRegType;

   constant RD_REG_INIT_C : RdRegType := (
      count    => (others => '0'),
      bytes    => conv_std_logic_vector(RD_BYTES_C, bitSize(DATA_BYTES_C)),
      rdMaster => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      ready    => '0'
      );

   signal rdR   : RdRegType := RD_REG_INIT_C;
   signal rdRin : RdRegType;

   ---------------
   -- Sync Signals
   ---------------
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

   ---------------
   -- Debug Signals
   ---------------

begin

   assert ((SLAVE_AXI_CONFIG_G.TDATA_BYTES_C >= MASTER_AXI_CONFIG_G.TDATA_BYTES_C and
            SLAVE_AXI_CONFIG_G.TDATA_BYTES_C mod MASTER_AXI_CONFIG_G.TDATA_BYTES_C = 0)
           or
           (MASTER_AXI_CONFIG_G.TDATA_BYTES_C >= SLAVE_AXI_CONFIG_G.TDATA_BYTES_C and
            MASTER_AXI_CONFIG_G.TDATA_BYTES_C mod SLAVE_AXI_CONFIG_G.TDATA_BYTES_C = 0))
      report "Data widths must be even number multiples of each other" severity failure;

   -- Cant use tkeep_fixed on master side when resizing or if not on slave side
   assert (not (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_FIXED_C and
                SLAVE_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_FIXED_C))
      report "AxiStreamFifo: Can't have TKEEP_MODE = TKEEP_FIXED on master side if not on slave side"
      severity error;

   -------------------------
   -- Write Logic
   -------------------------
   wrComb : process (fifoReady, sAxisMaster, wrR) is
      variable v   : WrRegType;
      variable idx : integer;
   begin
      v   := wrR;
      idx := conv_integer(wrR.count);

      -- Advance pipeline
      if fifoReady = '1' then

         -- init when count = 0
         if (wrR.count = 0) then
            v.wrMaster.tKeep := (others => '0');
            v.wrMaster.tData := (others => '0');
            v.wrMaster.tStrb := (others => '0');
            v.wrMaster.tUser := (others => '0');
         end if;

         v.wrMaster.tData((WR_BYTES_C*8*idx)+((WR_BYTES_C*8)-1) downto (WR_BYTES_C*8*idx)) := sAxisMaster.tData((WR_BYTES_C*8)-1 downto 0);
         v.wrMaster.tStrb((WR_BYTES_C*idx)+(WR_BYTES_C-1) downto (WR_BYTES_C*idx))         := sAxisMaster.tStrb(WR_BYTES_C-1 downto 0);
         v.wrMaster.tKeep((WR_BYTES_C*idx)+(WR_BYTES_C-1) downto (WR_BYTES_C*idx))         := sAxisMaster.tKeep(WR_BYTES_C-1 downto 0);

         v.wrMaster.tUser((WR_BYTES_C*SLAVE_USER_BITS_C*idx)+((WR_BYTES_C*SLAVE_USER_BITS_C)-1) downto (WR_BYTES_C*SLAVE_USER_BITS_C*idx))
            := sAxisMaster.tUser((WR_BYTES_C*SLAVE_USER_BITS_C)-1 downto 0);

         v.wrMaster.tDest := sAxisMaster.tDest;
         v.wrMaster.tId   := sAxisMaster.tId;
         v.wrMaster.tLast := sAxisMaster.tLast;

         -- Determine end mode, valid and ready
         if sAxisMaster.tValid = '1' then
            if (wrR.count = (WR_SIZE_C-1) or sAxisMaster.tLast = '1') then
               v.wrMaster.tValid := '1';
               v.count           := (others => '0');
            else
               v.wrMaster.tValid := '0';
               v.count           := wrR.count + 1;
            end if;
         else
            v.wrMaster.tValid := '0';
         end if;
      end if;

      wrRin <= v;

      -- Write logic enabled
      if WR_LOGIC_EN_C then
         fifoDin       <= iAxiToSlv(wrR.wrMaster);
         fifoWrite     <= wrR.wrMaster.tValid and fifoReady;
         fifoWriteLast <= wrR.wrMaster.tValid and fifoReady and wrR.wrMaster.tLast;
         fifoWriteUser <= wrR.wrMaster.tUser(FIFO_USER_TOT_C-1 downto 0);
      -- Bypass write logic
      else
         fifoDin       <= iAxiToSlv(sAxisMaster);
         fifoWrite     <= sAxisMaster.tValid and fifoReady;
         fifoWriteLast <= sAxisMaster.tValid and fifoReady and sAxisMaster.tLast;
         fifoWriteUser <= sAxisMaster.tUser(FIFO_USER_TOT_C-1 downto 0);
      end if;

      sAxisSlave.tReady <= fifoReady;

   end process wrComb;

   wrSeq : process (sAxisClk) is
   begin
      if (rising_edge(sAxisClk)) then
         if sAxisRst = '1' or WR_LOGIC_EN_C = false then
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
   process (fifoPFullVec, sAxisClk) is
   begin
      if FIFO_FIXED_THRESH_G then
         sAxisCtrl.pause <= fifoPFullVec(CASCADE_PAUSE_SEL_G) after TPD_G;
      elsif (rising_edge(sAxisClk)) then
         if sAxisRst = '1' or fifoWrCount >= fifoPauseThresh then
            sAxisCtrl.pause <= '1' after TPD_G;
         else
            sAxisCtrl.pause <= '0' after TPD_G;
         end if;
      end if;
   end process;

   -- Is ready enabled?
   fifoReady <= (not fifoAFull) when SLAVE_READY_EN_G else '1';

   U_Fifo : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         PIPE_STAGES_G      => INT_PIPE_STAGES_G,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => FIFO_BITS_C,
         ADDR_WIDTH_G       => FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => FIFO_PAUSE_THRESH_G,
         EMPTY_THRES_G      => 1
         )
      port map (
         rst           => sAxisRst,
         wr_clk        => sAxisClk,
         wr_en         => fifoWrite,
         din           => fifoDin,
         wr_data_count => fifoWrCount,
         wr_ack        => open,
         overflow      => sAxisCtrl.overflow,
         prog_full     => fifoPFull,
         progFullVec   => fifoPFullVec,
         almost_full   => fifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => mAxisClk,
         rd_en         => fifoRead,
         dout          => fifoDout,
         rd_data_count => fifoRdCount,
         valid         => fifoValidInt,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
         );

   U_LastFifoEnGen : if VALID_THOLD_G /= 1 generate

      U_LastFifo : entity work.FifoCascade
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => CASCADE_SIZE_G,
            LAST_STAGE_ASYNC_G => true,
            PIPE_STAGES_G      => INT_PIPE_STAGES_G,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => false,
            GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
            BRAM_EN_G          => false,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => false,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => FIFO_USER_TOT_C,
            ADDR_WIDTH_G       => LAST_FIFO_ADDR_WIDTH_C,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1
            )
         port map (
            rst           => sAxisRst,
            wr_clk        => sAxisClk,
            wr_en         => fifoWriteLast,
            din           => fifoWriteUser(FIFO_USER_TOT_C-1 downto 0),
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            not_full      => open,
            rd_clk        => mAxisClk,
            rd_en         => fifoReadLast,
            dout          => fifoReadUser(FIFO_USER_TOT_C-1 downto 0),
            rd_data_count => open,
            valid         => fifoValidLast,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      process (mAxisClk) is
      begin
         if (rising_edge(mAxisClk)) then
            if mAxisRst = '1' or fifoReadLast = '1' then
               fifoInFrame <= '0' after TPD_G;
            elsif fifoValidLast = '1' or (VALID_THOLD_G /= 0 and fifoRdCount >= VALID_THOLD_G) then
               fifoInFrame <= '1' after TPD_G;
            end if;
         end if;
      end process;

      fifoValid <= fifoValidInt and fifoInFrame;

   end generate;

   U_LastFifoDisGen : if VALID_THOLD_G = 1 generate
      fifoValidLast <= '0';
      fifoValid     <= fifoValidInt;
      fifoInFrame   <= '0';
   end generate;

   mTLastTUser(FIFO_USER_TOT_C-1 downto 0) <= fifoReadUser;

   -------------------------
   -- Read Logic
   -------------------------

   rdComb : process (axisSlave, fifoDout, fifoValid, rdR) is
      variable v          : RdRegType;
      variable idx        : integer;
      variable byteCnt    : integer;
      variable fifoMaster : AxiStreamMasterType;
   begin
      v   := rdR;
      idx := conv_integer(rdR.count);

      iSlvToAxi (fifoDout, fifoValid, fifoMaster, byteCnt);

      -- Advance pipeline
      if axisSlave.tReady = '1' or rdR.rdMaster.tValid = '0' then
         v.rdMaster := axiStreamMasterInit(MASTER_AXI_CONFIG_G);

         v.rdMaster.tData((RD_BYTES_C*8)-1 downto 0) := fifoMaster.tData((RD_BYTES_C*8*idx)+((RD_BYTES_C*8)-1) downto (RD_BYTES_C*8*idx));
         v.rdMaster.tStrb(RD_BYTES_C-1 downto 0)     := fifoMaster.tStrb((RD_BYTES_C*idx)+(RD_BYTES_C-1) downto (RD_BYTES_C*idx));
         v.rdMaster.tKeep(RD_BYTES_C-1 downto 0)     := fifoMaster.tKeep((RD_BYTES_C*idx)+(RD_BYTES_C-1) downto (RD_BYTES_C*idx));

         v.rdMaster.tUser((RD_BYTES_C*MASTER_USER_BITS_C)-1 downto 0)
            := fifoMaster.tUser((RD_BYTES_C*MASTER_USER_BITS_C*idx)+((RD_BYTES_C*MASTER_USER_BITS_C)-1) downto (RD_BYTES_C*MASTER_USER_BITS_C*idx));

         v.rdMaster.tDest := fifoMaster.tDest;
         v.rdMaster.tId   := fifoMaster.tId;

         -- Reached end of fifo data or no more valid bytes in last word
         if fifoMaster.tValid = '1' then
            if (rdR.count = (RD_SIZE_C-1)) or ((rdR.bytes >= byteCnt) and (fifoMaster.tLast = '1')) then
               v.count          := (others => '0');
               v.bytes          := conv_std_logic_vector(RD_BYTES_C, bitSize(DATA_BYTES_C));
               v.ready          := '1';
               v.rdMaster.tLast := fifoMaster.tLast;
            else
               v.count          := rdR.count + 1;
               v.bytes          := rdR.bytes + RD_BYTES_C;
               v.ready          := '0';
               v.rdMaster.tLast := '0';
            end if;
         end if;

         -- Drop transfers with no tKeep bits set, except on tLast
         v.rdMaster.tValid := fifoMaster.tValid and
                              (uOr(v.rdMaster.tKeep(RD_BYTES_C-1 downto 0)) or
                               v.rdMaster.tLast);

      else
         v.ready := '0';
      end if;

      rdRin <= v;

      -- Read logic enabled
      if RD_LOGIC_EN_C then
         axisMaster   <= rdR.rdMaster;
         fifoRead     <= v.ready and fifoValid;
         fifoReadLast <= v.ready and fifoValid and fifoMaster.tLast;

      -- Bypass read logic
      else
         axisMaster   <= fifoMaster;
         fifoRead     <= axisSlave.tReady and fifoValid;
         fifoReadLast <= axisSlave.tReady and fifoValid and fifoMaster.tLast;
      end if;

   end process rdComb;

   -- If fifo is asynchronous, must use async reset on rd side.
   rdSeq : process (mAxisClk) is
   begin
      if (rising_edge(mAxisClk)) then
         if mAxisRst = '1' or RD_LOGIC_EN_C = false then
            rdR <= RD_REG_INIT_C after TPD_G;
         else
            rdR <= rdRin after TPD_G;
         end if;
      end if;
   end process rdSeq;

   -- Synchronize master side tvalid back to slave side ctrl.idle
   -- This is a total hack
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0')         -- invert
      port map (
         clk     => sAxisClk,
         rst     => sAxisRst,
         dataIn  => axisMaster.tValid,
         dataOut => sAxisCtrl.idle);


   -------------------------
   -- Pipeline Logic
   -------------------------

   U_Pipe : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G
         )
      port map (
         -- Clock and Reset
         axisClk     => mAxisClk,
         axisRst     => mAxisRst,
         -- Slave Port
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;


