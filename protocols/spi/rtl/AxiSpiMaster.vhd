-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Axi lite interface for a single chip "generic SPI master"
--                For multiple chips on single bus connect multiple cores
--                to multiple AXI crossbar slaves and use Chip select outputs
--                (coreCsb) to multiplex select the addressed outputs (coreSDout and
--                coreSclk).
--                The coreCsb is active low. And active only if the corresponding
--                Axi Crossbar Slave is addressed.
--                DATA_SIZE_G - Corresponds to total read or write command size (not just data size).
--                              Example: DATA_SIZE_G = 24
--                                       1-bit command, 15-bit address word and 8-bit data
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

library unisim;
use unisim.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiSpiMaster is
   generic (
      TPD_G             : time     := 1 ns;
      ADDRESS_SIZE_G    : natural  := 15;
      DATA_SIZE_G       : natural  := 8;
      MODE_G            : string   := "RW";  -- Or "WO" (write only),  "RO" (read only)
      SHADOW_EN_G       : boolean  := false;
      SHADOW_MEM_TYPE_G : string   := "block";
      CPHA_G            : sl       := '0';
      CPOL_G            : sl       := '0';
      CLK_PERIOD_G      : real     := 6.4E-9;
      SPI_SCLK_PERIOD_G : real     := 100.0E-6;
      SPI_NUM_CHIPS_G   : positive := 1);
   port (
      -- AXI-Lite Interface
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Copy of the shadow memory (SHADOW_EN_G=true)
      shadowAddr     : in  slv(ADDRESS_SIZE_G-1 downto 0) := (others => '0');
      shadowData     : out slv(DATA_SIZE_G-1 downto 0)    := (others => '0');
      -- SPI Interface
      coreSclk       : out sl;
      coreSDin       : in  sl;
      coreSDout      : out sl;
      coreCsb        : out sl;  -- coreCsb is for legacy firmware without SPI_NUM_CHIPS_G generic
      coreMCsb       : out slv(SPI_NUM_CHIPS_G-1 downto 0));
end entity AxiSpiMaster;

architecture rtl of AxiSpiMaster is

   -- AdcCore Outputs
   constant PACKET_SIZE_C : positive := ite(MODE_G = "RW", 1, 0) + ADDRESS_SIZE_G + DATA_SIZE_G;  -- "1+" For R/W command bit
   constant CHIP_BITS_C   : integer  := log2(SPI_NUM_CHIPS_G);

   signal rdData : slv(PACKET_SIZE_C-1 downto 0);
   signal rdEn   : sl;

   type StateType is (WAIT_AXI_TXN_S, WAIT_CYCLE_S, WAIT_CYCLE_SHADOW_S, WAIT_SPI_TXN_DONE_S, SHADOW_READ_DONE_S);


   signal memData : slv(DATA_SIZE_G-1 downto 0) := (others => '0');

   -- Registers
   type RegType is record
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      -- Adc Core Inputs
      wrData        : slv(PACKET_SIZE_C-1 downto 0);
      chipSel       : slv(CHIP_BITS_C-1 downto 0);
      wrEn          : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state         => WAIT_AXI_TXN_S,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      wrData        => (others => '0'),
      chipSel       => (others => '0'),
      wrEn          => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   signal csb : slv(SPI_NUM_CHIPS_G-1 downto 0);

begin

   SHADOW_RAM_GEN : if (SHADOW_EN_G) generate
      U_DualPortRam_1 : entity surf.DualPortRam
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => SHADOW_MEM_TYPE_G,
            REG_EN_G      => false,
            DATA_WIDTH_G  => DATA_SIZE_G,
            ADDR_WIDTH_G  => ADDRESS_SIZE_G)
         port map (
            clka  => axiClk,                                                     -- [in]
            ena   => '1',                                                        -- [in]
            wea   => r.wrEn,                                                     -- [in]
            rsta  => axiRst,                                                     -- [in]
            addra => r.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G),  -- [in]
            dina  => r.wrData(DATA_SIZE_G-1 downto 0),                           -- [in]
            douta => memData,                                                    -- [out]
            clkb  => axiClk,                                                     -- [in]
            enb   => '1',                                                        -- [in]
            rstb  => axiRst,                                                     -- [in]
            addrb => shadowAddr,                                                 -- [in]
            doutb => shadowData);                                                -- [out]

   end generate SHADOW_RAM_GEN;


   comb : process (axiReadMaster, axiRst, axiWriteMaster, memData, r, rdData, rdEn) is
      variable v         : RegType;
      variable axiStatus : AxiLiteStatusType;
   begin
      v := r;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      case (r.state) is
         when WAIT_AXI_TXN_S =>

            if (axiStatus.readEnable = '1') then
               if (SHADOW_EN_G) then
                  v.state                   := WAIT_CYCLE_SHADOW_S;  -- just go to wait a cycle for memData to update
                  v.wrData(PACKET_SIZE_C-1) := '1';  -- indicate axi lite read in WAIT_SPI_TXN_DONE_S checking
                  if (ADDRESS_SIZE_G > 0) then
                     v.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G) := axiReadMaster.araddr(2+ADDRESS_SIZE_G-1 downto 2);  -- setup memAddr
                  end if;
               elsif (MODE_G = "WO") then
                  axiSlaveReadResponse(v.axiReadSlave, AXI_RESP_DECERR_C);
               else
                  -- No read bit when mode is read-only
                  if (MODE_G /= "RO") then
                     v.wrData(PACKET_SIZE_C-1) := '1';
                  end if;

                  -- Address
                  if (ADDRESS_SIZE_G > 0) then
                     v.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G) := axiReadMaster.araddr(2+ADDRESS_SIZE_G-1 downto 2);
                     -- Setting data segment to all 1 allows it to float so that slave side can drive it
                     -- in shared sdio configurations
                     v.wrData(DATA_SIZE_G-1 downto 0)                          := (others => '1');
                  end if;

                  -- If there are no address bits, readback will reuse the last wrData when shifting
                  v.chipSel := axiReadMaster.araddr(CHIP_BITS_C+ADDRESS_SIZE_G+1 downto 2+ADDRESS_SIZE_G);
                  v.wrEn    := '1';
                  v.state   := WAIT_CYCLE_S;
               end if;

            elsif (axiStatus.writeEnable = '1') then
               if (MODE_G = "RO") then
                  axiSlaveWriteResponse(v.axiWriteSlave, AXI_RESP_DECERR_C);
               else
                  -- No write bit when mode is write-only
                  if (MODE_G /= "WO") then
                     v.wrData(PACKET_SIZE_C-1) := '0';
                  end if;

                  -- Address (make sure that the assigned AXI address in the crossbar is big enough)
                  if (ADDRESS_SIZE_G > 0) then
                     v.wrData(DATA_SIZE_G+ADDRESS_SIZE_G-1 downto DATA_SIZE_G) := axiWriteMaster.awaddr(2+ADDRESS_SIZE_G-1 downto 2);
                  end if;
                  -- Data
                  v.wrData(DATA_SIZE_G-1 downto 0) := axiWriteMaster.wdata(DATA_SIZE_G-1 downto 0);
                  -- Chip select
                  v.chipSel                        := axiWriteMaster.awaddr(CHIP_BITS_C+ADDRESS_SIZE_G+1 downto 2+ADDRESS_SIZE_G);
                  v.wrEn                           := '1';
                  v.state                          := WAIT_CYCLE_S;
               end if;
            end if;

         when WAIT_CYCLE_S =>
            -- Wait for rdEn to drop
            if (rdEn = '0') then
               v.wrEn  := '0';
               v.state := WAIT_SPI_TXN_DONE_S;
            end if;

         when WAIT_CYCLE_SHADOW_S =>
            -- wait for memData
            v.state := SHADOW_READ_DONE_S;

         when WAIT_SPI_TXN_DONE_S =>

            if (rdEn = '1') then
               v.state := WAIT_AXI_TXN_S;
               if (MODE_G = "WO" or (MODE_G = "RW" and r.wrData(PACKET_SIZE_C-1) = '0')) then
                  axiSlaveWriteResponse(v.axiWriteSlave);
               else
                  v.axiReadSlave.rdata(DATA_SIZE_G-1 downto 0) := rdData(DATA_SIZE_G-1 downto 0);
                  axiSlaveReadResponse(v.axiReadSlave);
               end if;
            end if;

         when SHADOW_READ_DONE_S =>
            v.axiReadSlave.rdata(DATA_SIZE_G-1 downto 0) := memData;
            axiSlaveReadResponse(v.axiReadSlave);
            v.state                                      := WAIT_AXI_TXN_S;

         when others => null;
      end case;

      -- Check if single access
      if (SPI_NUM_CHIPS_G = 1) then
         v.chipSel := (others => '0');
      end if;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axiWriteSlave <= r.axiWriteSlave;
      axiReadSlave  <= r.axiReadSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SpiMaster_1 : entity surf.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => SPI_NUM_CHIPS_G,
         DATA_SIZE_G       => PACKET_SIZE_C,
         CPHA_G            => CPHA_G,
         CPOL_G            => CPOL_G,
         CLK_PERIOD_G      => CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G)
      port map (
         clk     => axiClk,
         sRst    => axiRst,
         chipSel => r.chipSel,
         wrEn    => r.wrEn,
         wrData  => r.wrData,
         rdEn    => rdEn,
         rdData  => rdData,
         spiCsL  => csb,
         spiSclk => coreSclk,
         spiSdi  => coreSDout,
         spiSdo  => coreSDin);

   coreCsb  <= csb(0);
   coreMCsb <= csb;

end architecture rtl;
