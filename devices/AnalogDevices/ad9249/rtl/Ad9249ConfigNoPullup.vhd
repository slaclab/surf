-------------------------------------------------------------------------------
-- File       : Ad9249ConfigNoPullup.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2016-12-12
-------------------------------------------------------------------------------
-- Description: AD9249 Configuration/Status Module (no pullup version)
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity Ad9249ConfigNoPullup is
   generic (
      TPD_G           : time            := 1 ns;
      DEN_POLARITY_G  : sl              := '1';
      CLK_PERIOD_G    : real            := 8.0e-9;
      CLK_EN_PERIOD_G : real            := 16.0e-9;
      NUM_CHIPS_G     : positive        := 1;
      AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C
      );
   port (

      axilClk : in sl;
      axilRst : in sl;

      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Interface To ADC
      adcSClk  : out std_logic;
      adcSDin  : in  std_logic;
      adcSDout : out std_logic;
      adcSDEn  : out std_logic;
      adcCsb   : out std_logic_vector(NUM_CHIPS_G*2-1 downto 0);
      adcPdwn  : out std_logic_vector(NUM_CHIPS_G-1 downto 0)
      );
end Ad9249ConfigNoPullup;


-- Define architecture
architecture rtl of Ad9249ConfigNoPullup is

   constant SPI_CLK_PERIOD_DIV2_CYCLES_C : integer := integer(CLK_EN_PERIOD_G / CLK_PERIOD_G) / 2;
   constant SCLK_COUNTER_SIZE_C          : integer := bitSize(SPI_CLK_PERIOD_DIV2_CYCLES_C);

   -- Local Signals
   signal intShift   : std_logic_vector(23 downto 0);
   signal nextClk    : std_logic;
   signal nextAck    : std_logic;
   signal shiftCnt   : std_logic_vector(12 downto 0);
   signal shiftCntEn : std_logic;
   signal shiftEn    : std_logic;
   signal locSDout   : std_logic;
   signal adcSDir    : std_logic;

   signal axilClkEn   : std_logic;
   signal sclkCounter : std_logic_vector(SCLK_COUNTER_SIZE_C-1 downto 0);

   -- State Machine
   constant ST_IDLE  : std_logic_vector(1 downto 0) := "01";
   constant ST_SHIFT : std_logic_vector(1 downto 0) := "10";
   constant ST_DONE  : std_logic_vector(1 downto 0) := "11";
   signal curState   : std_logic_vector(1 downto 0);
   signal nxtState   : std_logic_vector(1 downto 0);

   signal adcWrData : std_logic_vector(7 downto 0);
   signal adcRdData : std_logic_vector(7 downto 0);
   signal adcAddr   : std_logic_vector(12 downto 0);
   signal adcWrReq  : std_logic;
   signal adcRdReq  : std_logic;
   signal adcAck    : std_logic;

   constant CHIP_SEL_WIDTH_C : integer                       := log2(NUM_CHIPS_G*2);
   constant PWDN_ADDR_BIT_C  : integer                       := 11 + CHIP_SEL_WIDTH_C;
   constant PWDN_ADDR_C      : slv(PWDN_ADDR_BIT_C downto 0) := toSlv(2**PWDN_ADDR_BIT_C, PWDN_ADDR_BIT_C+1);

   type StateType is (ADC_IDLE_S, ADC_READ_S, ADC_WRITE_S);

   -- Registers
   type RegType is record
      state          : StateType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      -- Adc Core Inputs
      chipSel        : slv(CHIP_SEL_WIDTH_C-1 downto 0);
      wrData         : slv(23 downto 0);
      adcWrReq       : sl;
      adcRdReq       : sl;
      pdwn           : slv(NUM_CHIPS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => ADC_IDLE_S,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      chipSel        => (others => '0'),
      wrData         => (others => '0'),
      adcWrReq       => '0',
      adcRdReq       => '0',
      pdwn           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin


   comb : process (adcAck, adcRdData, axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v          : RegType;
      variable axilStatus : AxiLiteStatusType;
   begin
      v := r;

      v.axilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Any other address is forwarded to the chip via SPI
      if (axilStatus.writeEnable = '1') then
         if (axilWriteMaster.awaddr(PWDN_ADDR_BIT_C) = '0') then
            v.wrData(23)           := '0';                                  -- Write bit
            v.wrData(22 downto 21) := "00";                                 -- Number of bytes (1)
            v.wrData(20 downto 17) := "0000";                               -- Unused address bits
            v.wrData(16 downto 8)  := axilWriteMaster.awaddr(10 downto 2);  -- Address
            v.wrData(7 downto 0)   := axilWriteMaster.wdata(7 downto 0);    -- Data
            v.chipSel              := axilWriteMaster.awaddr(11+CHIP_SEL_WIDTH_C-1 downto 11);  -- Bank select
            v.adcWrReq             := '1';
         elsif (axilWriteMaster.awaddr(PWDN_ADDR_BIT_C downto 0) = PWDN_ADDR_C) then
            v.pdwn := axilWriteMaster.wdata(NUM_CHIPS_G-1 downto 0);
            axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);
         else
            axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, AXIL_ERR_RESP_G);
         end if;
      end if;

      if (axilStatus.readEnable = '1') then
         if (axilReadMaster.araddr(PWDN_ADDR_BIT_C) = '0') then
            v.wrData(23)           := '1';                                 -- read bit
            v.wrData(22 downto 21) := "00";                                -- Number of bytes (1)
            v.wrData(20 downto 17) := "0000";                              -- Unused address bits
            v.wrData(16 downto 8)  := axilReadMaster.araddr(10 downto 2);  -- Address
            v.wrData(7 downto 0)   := (others => '0');
            v.chipSel              := axilReadMaster.araddr(11+CHIP_SEL_WIDTH_C-1 downto 11);  -- Bank Select
            v.adcRdReq             := '1';

         elsif (axilReadMaster.araddr(PWDN_ADDR_BIT_C downto 0) = PWDN_ADDR_C) then
            v.axilReadSlave.rdata(NUM_CHIPS_G-1 downto 0) := r.pdwn;
            axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);
         else
            axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, AXIL_ERR_RESP_G);
         end if;
      end if;


      case (r.state) is
         when ADC_IDLE_S =>
            if r.adcWrReq = '1' then
               v.state := ADC_WRITE_S;
            elsif r.adcRdReq = '1' then
               v.state := ADC_READ_S;
            end if;

         when ADC_WRITE_S =>
            v.adcWrReq := '1';
            if adcAck = '1' then
               v.adcWrReq := '0';
               v.state    := ADC_IDLE_S;
               axiSlaveWriteResponse(v.axilWriteSlave, AXI_RESP_OK_C);
            end if;

         when ADC_READ_S =>
            if adcAck = '1' then
               v.adcRdReq                        := '0';
               v.axilReadSlave.rdata(7 downto 0) := adcRdData(7 downto 0);
               v.state                           := ADC_IDLE_S;
               axiSlaveReadResponse(v.axilReadSlave, AXI_RESP_OK_C);
            end if;

         when others => null;
      end case;

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      adcPdwn        <= r.pdwn;

      adcWrReq  <= r.adcWrReq;
      adcRdReq  <= r.adcRdReq;
      adcWrData <= r.wrData(7 downto 0);
      adcAddr   <= r.wrData(20 downto 8);


   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



   -- Generate clock enable for state machine
   process(axilClk)
   begin
      if rising_edge(axilClk) then
         if axilRst = '1' then
            sclkCounter <= (others => '0');
            axilClkEn   <= '0';
         else
            if (sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               sclkCounter <= (others => '0');
               axilClkEn   <= '1';
            else
               sclkCounter <= sclkCounter + 1;
               axilClkEn   <= '0';
            end if;
         end if;
      end if;
   end process;

   -- Output Data
   adcRdData <= intShift(7 downto 0);

   -- ADC data
   adcSDout <= locSDout when adcSDir = '0' else '1';
   -- Enable for the top level tri-state
   adcSDEn  <= ite(DEN_POLARITY_G = '1', not adcSDir, adcSDir);

   -- Control shift memory register
   process (axilClk)
   begin
      if rising_edge(axilClk) then
         if axilRst = '1' then
            adcAck   <= '0' after TPD_G;
            adcSDir  <= '0' after TPD_G;
            locSDout <= '0' after TPD_G;
            adcSClk  <= '0' after TPD_G;
            adcCsb   <= (others => '1') after TPD_G;
            nextClk  <= '1' after TPD_G;
            shiftCnt <= (others => '0') after TPD_G;
            shiftCntEn <= '0' after TPD_G;
            intShift <= (others => '0') after TPD_G;
            curState <= ST_IDLE after TPD_G;
         elsif axilClkEn = '1' then

            -- Next state
            curState <= nxtState after TPD_G;
            adcAck   <= nextAck  after TPD_G;

            -- Shift count is not enabled
            if shiftCntEn = '0' then
               adcSClk  <= '0' after TPD_G;
               locSDout <= '0' after TPD_G;
               adcSDir  <= '0' after TPD_G;
               adcCsb   <= (others => '1') after TPD_G;
               nextClk <= '1' after TPD_G;

               -- Wait for shift request
               if shiftEn = '1' then
                  shiftCntEn <= '1' after TPD_G;
                  shiftCnt               <= (others => '0') after TPD_G;
                  intShift(23)           <= adcRdReq     after TPD_G;
                  intShift(22 downto 21) <= "00"         after TPD_G;
                  intShift(20 downto 8)  <= adcAddr      after TPD_G;
                  intShift(7 downto 0)   <= adcWrData    after TPD_G;
               end if;
            else
               shiftCnt                  <= shiftCnt + 1 after TPD_G;

               -- Clock 0, setup output
               if shiftCnt(7 downto 0) = 0 then

                  -- Clock goes back to zero
                  adcSClk <= '0' after TPD_G;

                  -- Shift Count 0-23, output and shift data
                  if shiftCnt(12 downto 8) < 24 then
                     locSDout <= intShift(23)                                      after TPD_G;
                     intShift <= intShift(22 downto 0) & adcSDin                   after TPD_G;
                     adcCsb   <= not (decode(r.chipSel)(NUM_CHIPS_G*2-1 downto 0)) after TPD_G;
                     nextClk  <= '1'                                               after TPD_G;

                  -- Done, Sample last value
                  else
                     intShift <= intShift(22 downto 0) & adcSDin after TPD_G;
                     locSDout <= '0'                             after TPD_G;
                     adcCsb   <= (others => '1') after TPD_G;
                     nextClk <= '0' after TPD_G;
                  end if;

               -- Clock 3, clock output
               elsif shiftCnt(7 downto 0) = 8 then
                  adcSClk <= nextClk after TPD_G;

                  -- Tristate after 16 bits if read
                  if shiftCnt(12 downto 8) = 15 and adcRdReq = '1' then
                     adcSDir <= '1' after TPD_G;
                  end if;

                  -- Stop counter
                  if shiftCnt(12 downto 8) = 24 then
                     shiftCntEn <= '0' after TPD_G;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- State machine control
   process (curState, adcWrReq, adcRdReq, shiftCntEn)
   begin
      case curState is

         -- IDLE, wait for request
         when ST_IDLE =>
            nextAck <= '0';

            -- Shift Request
            if adcWrReq = '1' or adcRdReq = '1' then
               shiftEn  <= '1';
               nxtState <= ST_SHIFT;
            else
               shiftEn  <= '0';
               nxtState <= curState;
            end if;

         -- Shifting Data
         when ST_SHIFT =>
            nextAck <= '0';
            shiftEn <= '0';

            -- Wait for shift to be done
            if shiftCntEn = '0' then
               nxtState <= ST_DONE;
            else
               nxtState <= curState;
            end if;

         -- Done
         when ST_DONE =>
            nextAck <= '1';
            shiftEn <= '0';

            -- Wait for request to go away
            if adcRdReq = '0' and adcWrReq = '0' then
               nxtState <= ST_IDLE;
            else
               nxtState <= curState;
            end if;

         when others =>
            nextAck  <= '0';
            shiftEn  <= '0';
            nxtState <= ST_IDLE;
      end case;
   end process;

end architecture rtl;

