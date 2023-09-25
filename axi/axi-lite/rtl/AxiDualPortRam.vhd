-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A wrapper of StdLib DualPortRam that places an AxiLite
-- interface on the read/write port.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiDualPortRam is
   generic (
      TPD_G               : time                       := 1 ns;
      RST_ASYNC_G         : boolean                    := false;
      SYNTH_MODE_G        : string                     := "inferred";
      MEMORY_TYPE_G       : string                     := "block";
      MEMORY_INIT_FILE_G  : string                     := "none";  -- Used for MEMORY_TYPE_G="XPM only
      MEMORY_INIT_PARAM_G : string                     := "0";  -- Used for MEMORY_TYPE_G="XPM only
      READ_LATENCY_G      : natural range 0 to 3       := 2;
      AXI_WR_EN_G         : boolean                    := true;
      SYS_WR_EN_G         : boolean                    := false;
      SYS_BYTE_WR_EN_G    : boolean                    := false;
      COMMON_CLK_G        : boolean                    := false;
      ADDR_WIDTH_G        : integer range 1 to (2**24) := 5;
      DATA_WIDTH_G        : integer                    := 32;
      INIT_G              : slv                        := "0");
   port (
      -- Axi Port
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Standard Port
      clk            : in  sl                                         := '0';
      en             : in  sl                                         := '1';
      we             : in  sl                                         := '0';
      weByte         : in  slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0) := (others => '0');
      rst            : in  sl                                         := '0';
      addr           : in  slv(ADDR_WIDTH_G-1 downto 0)               := (others => '0');
      din            : in  slv(DATA_WIDTH_G-1 downto 0)               := (others => '0');
      dout           : out slv(DATA_WIDTH_G-1 downto 0);
      axiWrValid     : out sl;
      axiWrStrobe    : out slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0);
      axiWrAddr      : out slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData      : out slv(DATA_WIDTH_G-1 downto 0));
end entity AxiDualPortRam;

architecture rtl of AxiDualPortRam is

   -- Number of Axi address bits that need to be manually decoded
   constant AXI_DEC_BITS_C : integer := ite(DATA_WIDTH_G <= 32, 0, log2((DATA_WIDTH_G-1)/32));

   constant AXI_DEC_ADDR_HIGH_C : integer := 1+AXI_DEC_BITS_C;
   constant AXI_DEC_ADDR_LOW_C  : integer := 2;
   subtype AXI_DEC_ADDR_RANGE_C is integer range AXI_DEC_ADDR_HIGH_C downto AXI_DEC_ADDR_LOW_C;

   constant AXI_RAM_ADDR_HIGH_C : integer := ADDR_WIDTH_G+AXI_DEC_ADDR_RANGE_C'high;
   constant AXI_RAM_ADDR_LOW_C  : integer := AXI_DEC_ADDR_RANGE_C'high+1;
   subtype AXI_RAM_ADDR_RANGE_C is integer range AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C;

   constant ADDR_AXI_WORDS_C : natural := wordCount(DATA_WIDTH_G, 32);
   constant ADDR_AXI_BYTES_C : natural := wordCount(DATA_WIDTH_G, 8);
   constant RAM_WIDTH_C      : natural := ADDR_AXI_WORDS_C*32;
   constant STRB_WIDTH_C     : natural := minimum(4, ADDR_AXI_BYTES_C);

   type StateType is (
      IDLE_S,
      RD_S);

   type RegType is record
      axiWriteSlave : AxiLiteWriteSlaveType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiAddr       : slv(ADDR_WIDTH_G-1 downto 0);
      axiWrStrobe   : slv(ADDR_AXI_WORDS_C*4-1 downto 0);
      rdLatecy      : natural range 0 to 4;
      state         : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiAddr       => (others => '0'),
      axiWrStrobe   => (others => '0'),
      rdLatecy      => 0,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiWrDataFanout : slv(RAM_WIDTH_C-1 downto 0);
   signal axiDout         : slv(RAM_WIDTH_C-1 downto 0) := (others => '0');

   signal axiSyncWrEn : sl;
   signal axiSyncIn   : slv(DATA_WIDTH_G + ADDR_WIDTH_G + ADDR_AXI_BYTES_C - 1 downto 0);
   signal axiSyncOut  : slv(DATA_WIDTH_G + ADDR_WIDTH_G + ADDR_AXI_BYTES_C - 1 downto 0);

   signal weByteMask : slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0);
   signal doutInt    : slv(DATA_WIDTH_G-1 downto 0);

begin

   ------------------------------------------------------------
   --       Supported RAM memory configurations
   ------------------------------------------------------------
   --    SYNTH_MODE_G     |    MEMORY_TYPE_G   | READ_LATENCY_G
   ------------------------------------------------------------
   -- "XPM" or "inferred" | "block" or "ultra" |      1 ~ 3
   ------------------------------------------------------------
   --       "XPM"         |  "distributed"     |      0 ~ 3
   ------------------------------------------------------------
   --       "inferred"    |  "distributed"     |      0 ~ 1
   ------------------------------------------------------------
   assert
      (MEMORY_TYPE_G /= "distributed" and (READ_LATENCY_G >= 1 and READ_LATENCY_G      <= 3)) or
      (SYNTH_MODE_G = "xpm" and MEMORY_TYPE_G = "distributed" and (READ_LATENCY_G      <= 3)) or
      (SYNTH_MODE_G = "inferred" and MEMORY_TYPE_G = "distributed" and (READ_LATENCY_G <= 1))
      report "RAM memory configuration not supported" severity failure;

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_RAM : entity surf.TrueDualPortRamXpm
         generic map (
            TPD_G               => TPD_G,
            COMMON_CLK_G        => COMMON_CLK_G,
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE_G,
            MEMORY_INIT_PARAM_G => MEMORY_INIT_PARAM_G,
            WRITE_MODE_G        => ite(MEMORY_TYPE_G = "distributed", "read_first", "no_change"),
            READ_LATENCY_G      => READ_LATENCY_G,
            DATA_WIDTH_G        => DATA_WIDTH_G,
            BYTE_WR_EN_G        => true,
            BYTE_WIDTH_G        => 8,
            ADDR_WIDTH_G        => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka  => axiClk,
            ena   => '1',
            wea   => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
            rsta  => '0',
            addra => r.axiAddr,
            dina  => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),
            douta => axiDout(DATA_WIDTH_G-1 downto 0),
            -- Port B
            clkb  => clk,
            enb   => en,
            web   => weByteMask,
            rstb  => '0',
            addrb => addr,
            dinb  => din,
            doutb => doutInt);
   end generate;

   GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
      U_RAM : entity surf.TrueDualPortRamAlteraMf
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => COMMON_CLK_G,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => READ_LATENCY_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            BYTE_WR_EN_G   => true,
            BYTE_WIDTH_G   => 8,
            ADDR_WIDTH_G   => ADDR_WIDTH_G)
         port map (
            -- Port A
            clka  => axiClk,
            ena   => '1',
            wea   => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
            rsta  => '0',
            addra => r.axiAddr,
            dina  => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),
            douta => axiDout(DATA_WIDTH_G-1 downto 0),
            -- Port B
            clkb  => clk,
            enb   => en,
            web   => weByteMask,
            rstb  => '0',
            addrb => addr,
            dinb  => din,
            doutb => doutInt);
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate

      -- AXI read only, sys writable or read only (rom)
      AXI_R0_SYS_RW : if (not AXI_WR_EN_G and SYS_WR_EN_G) generate
         DualPortRam_1 : entity surf.DualPortRam
            generic map (
               TPD_G         => TPD_G,
               RST_ASYNC_G   => RST_ASYNC_G,
               MEMORY_TYPE_G => MEMORY_TYPE_G,
               REG_EN_G      => ite(READ_LATENCY_G >= 1, true, false),
               DOA_REG_G     => ite(READ_LATENCY_G >= 2, true, false),
               DOB_REG_G     => ite(READ_LATENCY_G >= 2, true, false),
               BYTE_WR_EN_G  => SYS_BYTE_WR_EN_G,
               DATA_WIDTH_G  => DATA_WIDTH_G,
               ADDR_WIDTH_G  => ADDR_WIDTH_G,
               INIT_G        => INIT_G)
            port map (
               clka    => clk,
               ena     => en,
               wea     => we,
               weaByte => weByte,
               rsta    => '0',
               addra   => addr,
               dina    => din,
               douta   => doutInt,

               clkb  => axiClk,
               enb   => '1',
               rstb  => '0',
               addrb => r.axiAddr,
               doutb => axiDout(DATA_WIDTH_G-1 downto 0));
      end generate;

      -- System Read only, Axi writable or read only (ROM)
      -- Logic disables axi writes if AXI_WR_EN_G=false
      AXI_RW_SYS_RO : if (not SYS_WR_EN_G) generate
         DualPortRam_1 : entity surf.DualPortRam
            generic map (
               TPD_G         => TPD_G,
               RST_ASYNC_G   => RST_ASYNC_G,
               MEMORY_TYPE_G => MEMORY_TYPE_G,
               REG_EN_G      => ite(READ_LATENCY_G >= 1, true, false),
               DOA_REG_G     => ite(READ_LATENCY_G >= 2, true, false),
               DOB_REG_G     => ite(READ_LATENCY_G >= 2, true, false),
               BYTE_WR_EN_G  => true,
               DATA_WIDTH_G  => DATA_WIDTH_G,
               BYTE_WIDTH_G  => 8,
               ADDR_WIDTH_G  => ADDR_WIDTH_G,
               INIT_G        => INIT_G)
            port map (
               clka    => axiClk,
               ena     => '1',
               weaByte => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
               rsta    => '0',
               addra   => r.axiAddr,
               dina    => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),
               douta   => axiDout(DATA_WIDTH_G-1 downto 0),
               clkb    => clk,
               enb     => en,
               rstb    => '0',
               addrb   => addr,
               doutb   => doutInt);
      end generate;

      -- Both sides writable, true dual port ram
      AXI_RW_SYS_RW : if (AXI_WR_EN_G and SYS_WR_EN_G) generate
         U_TrueDualPortRam_1 : entity surf.TrueDualPortRam
            generic map (
               TPD_G        => TPD_G,
               RST_ASYNC_G  => RST_ASYNC_G,
               BYTE_WR_EN_G => true,
               DOA_REG_G    => ite(READ_LATENCY_G >= 2, true, false),
               DOB_REG_G    => ite(READ_LATENCY_G >= 2, true, false),
               DATA_WIDTH_G => DATA_WIDTH_G,
               BYTE_WIDTH_G => 8,
               ADDR_WIDTH_G => ADDR_WIDTH_G,
               INIT_G       => INIT_G)
            port map (
               clka    => axiClk,                                    -- [in]
               ena     => '1',                                       -- [in]
               wea     => '1',
               weaByte => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
               rsta    => '0',                                       -- [in]
               addra   => r.axiAddr,                                 -- [in]
               dina    => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),  -- [in]
               douta   => axiDout(DATA_WIDTH_G-1 downto 0),          -- [out]
               clkb    => clk,                                       -- [in]
               enb     => en,                                        -- [in]
               web     => we,                                        -- [in]
               webByte => weByteMask,                                -- [in]
               rstb    => '0',                                       -- [in]
               addrb   => addr,                                      -- [in]
               dinb    => din,                                       -- [in]
               doutb   => doutInt);                                  -- [out]

      end generate;

   end generate;

   weByteMask <= (others => '0') when(not SYS_WR_EN_G) else weByte when(SYS_BYTE_WR_EN_G) else (others => we);

   axiSyncIn(DATA_WIDTH_G-1 downto 0)                         <= axiWrDataFanout(DATA_WIDTH_G-1 downto 0);
   axiSyncIn(ADDR_WIDTH_G+DATA_WIDTH_G-1 downto DATA_WIDTH_G) <= r.axiAddr;
   axiSyncIn(ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C-1 downto ADDR_WIDTH_G+DATA_WIDTH_G)
      <= r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0);
   axiSyncWrEn <= uOr(r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0));

   U_SynchronizerFifo_1 : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         COMMON_CLK_G  => COMMON_CLK_G,
         MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G  => ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C)
      port map (
         rst    => rst,                 -- [in]
         wr_clk => axiClk,              -- [in]
         wr_en  => axiSyncWrEn,         -- [in]
         din    => axiSyncIn,           -- [in]
         rd_clk => clk,                 -- [in]
         rd_en  => '1',                 -- [in]
         valid  => axiWrValid,          -- [out]
         dout   => axiSyncOut);         -- [out]

   axiWrData   <= axiSyncOut(DATA_WIDTH_G-1 downto 0);
   axiWrAddr   <= axiSyncOut(ADDR_WIDTH_G+DATA_WIDTH_G-1 downto DATA_WIDTH_G);
   axiWrStrobe <= axiSyncOut(ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C-1 downto ADDR_WIDTH_G+DATA_WIDTH_G);

   axiWrMap : for i in 0 to ADDR_AXI_WORDS_C-1 generate
      axiWrDataFanout((i+1)*32-1 downto i*32) <= axiWriteMaster.wdata;
   end generate axiWrMap;

   comb : process (axiDout, axiReadMaster, axiRst, axiWriteMaster, r) is
      variable v          : RegType;
      variable axiStatus  : AxiLiteStatusType;
      variable decAddrInt : integer;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes and shift Register
      v.axiWrStrobe := (others => '0');

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Multiplex read data onto axi bus
      if (DATA_WIDTH_G <= 32) then
         decAddrInt := 0;
      else
         decAddrInt := conv_integer(axiReadMaster.araddr(AXI_DEC_ADDR_RANGE_C));
      end if;
      v.axiReadSlave.rdata := axiDout((decAddrInt+1)*32-1 downto decAddrInt*32);

      -- Set axiAddr to read address by default
      v.axiAddr := axiReadMaster.araddr(AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for write transaction
            if (axiStatus.writeEnable = '1') then
               if (AXI_WR_EN_G) then
                  v.axiAddr        := axiWriteMaster.awaddr(AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C);
                  if (DATA_WIDTH_G <= 32) then
                     v.axiWrStrobe := axiWriteMaster.wstrb;
                  else
                     decAddrInt := conv_integer(axiWriteMaster.awaddr(AXI_DEC_ADDR_RANGE_C));
                     v.axiWrStrobe((decAddrInt+1)*4-1 downto decAddrInt*4) := axiWriteMaster.wstrb;
                  end if;
               end if;
               axiSlaveWriteResponse(v.axiWriteSlave, ite(AXI_WR_EN_G, AXI_RESP_OK_C, AXI_RESP_SLVERR_C));
            -- Check for read transaction
            elsif (axiStatus.readEnable = '1') then
               -- Set the address bus
               v.axiAddr  := axiReadMaster.araddr(AXI_RAM_ADDR_HIGH_C downto AXI_RAM_ADDR_LOW_C);
               -- Arm the wait
               v.rdLatecy := 4;
               -- Next state
               v.state    := RD_S;
            end if;
         ----------------------------------------------------------------------
         when RD_S =>
            -- Decrement the counter
            v.rdLatecy := r.rdLatecy - 1;
            -- Wait for the read transaction
            if (v.rdLatecy = 0) then
               -- Send the read response
               axiSlaveReadResponse(v.axiReadSlave, AXI_RESP_OK_C);
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (RST_ASYNC_G = false and axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Output assignment
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

   end process comb;

   seq : process (axiClk, axiRst) is
   begin
      if (RST_ASYNC_G and axiRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   OUT_REG : if((READ_LATENCY_G = 3) and (SYNTH_MODE_G /= "xpm")) generate
      REG : process (clk, rst) is
      begin
         if (RST_ASYNC_G and rst = '1') then
            dout <= (others => '0');
         elsif (rising_edge(clk)) then
            if (RST_ASYNC_G = false and rst = '1') then
               dout <= (others => '0');
            else
               dout <= doutInt;
            end if;
         end if;
      end process REG;
   end generate OUT_REG;

   NO_OUT_REG : if ((READ_LATENCY_G <= 2) or (SYNTH_MODE_G = "xpm")) generate
      dout <= doutInt;
   end generate NO_OUT_REG;

end architecture rtl;
