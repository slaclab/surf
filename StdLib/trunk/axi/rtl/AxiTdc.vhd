-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-11-03
-- Last update: 2014-11-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible TDC
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;
--use work.TextUtilPkg.all;

entity AxiTdc is
   generic (
      TPD_G              : time    := 1 ns;
      AXI_ERROR_RESP_G   : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      N_TDC_CHANNELS_G   : integer range 1 to 64 := 1;
      TDC_COARSE_WIDTH_G : integer range 2 to 32 := 1
   );
   port (
      -- AXI clock domain
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- TDC clock domain
      tdcClk    : in sl;
      -- Asynchronous start/stop
      -- Widths must be at least 1 TDC clock period!
      tdcStart  : in slv(N_TDC_CHANNELS_G-1 downto 0);
      tdcStop   : in slv(N_TDC_CHANNELS_G-1 downto 0)
   );
end AxiTdc;

architecture rtl of AxiTdc is

   signal tdcCalStart   : sl;
   signal tdcCalStop    : sl;
   signal tdcCalCount   : slv(TDC_COARSE_WIDTH_G-1 downto 0);
   signal tdcOrCalStart : slv(N_TDC_CHANNELS_G-1 downto 0);
   signal tdcOrCalStop  : slv(N_TDC_CHANNELS_G-1 downto 0);
   signal tdcCalTrigger : sl;
   signal tdcCalDelay   : slv(TDC_COARSE_WIDTH_G-1 downto 0);
   signal tdcRst        : sl;
   
   type CalStateType is (IDLE_S, COUNTING_S);
   signal tdcCalState : CalStateType;
  

   subtype TdcValue  is slv(TDC_COARSE_WIDTH_G-1 downto 0);
   type TdcValues is array (N_TDC_CHANNELS_G-1 downto 0) of TdcValue;
   signal coarseTdcValid  : slv(N_TDC_CHANNELS_G-1 downto 0);
   signal coarseTdcValues : TdcValues := (others => (others => '0'));
   signal coarseTdcValuesSynced : TdcValues := (others => (others => '0'));
   
   type RegType is record
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      calEnable     : sl;
      calTrigger    : sl;
      calDelay      : slv(TDC_COARSE_WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      calEnable     => '0',
      calTrigger    => '0',
      calDelay      => (others => '0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   comb : process (axiRst, axiReadMaster, axiWriteMaster, r) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Clear pulsed signals
      v.calTrigger := '0';
      
      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(11 downto 2)) is
            when X"00" =>
               v.calTrigger := '1';
            when X"01" =>
               v.calDelay  := axiWriteMaster.wdata(TDC_COARSE_WIDTH_G-1 downto 0);
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         if conv_integer(axiReadMaster.araddr(11 downto 2)) >= N_TDC_CHANNELS_G+2 then
            axiReadResp := AXI_ERROR_RESP_G;
         elsif conv_integer(axiReadMaster.araddr(11 downto 2)) = 1 then
            v.axiReadSlave.rdata(TDC_COARSE_WIDTH_G-1 downto 0) := r.calDelay;
         else
            v.axiReadSlave.rdata(TDC_COARSE_WIDTH_G-1 downto 0) := coarseTdcValuesSynced(conv_integer(axiReadMaster.araddr(11 downto 2))+2);
         end if;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v             := REG_INIT_C;
      end if;

      rin <= v;

      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Generate calibration signal
   process(tdcClk) begin
      if rising_edge(tdcClk) then
         if tdcRst = '1' then
            tdcCalState <= IDLE_S;
            tdcCalStart <= '0';
            tdcCalStop  <= '0';
            tdcCalCount <= (others => '0');
         else
            -- Echo the trigger as start signal
            tdcCalStart <= tdcCalTrigger;
            tdcCalStop  <= '0';
            -- Simple state machine to generate stop
            case (tdcCalState) is
               when IDLE_S =>
                  tdcCalCount <= (others => '0');
                  if (tdcCalTrigger = '1') then
                     tdcCalCount    <= tdcCalCount + 1;
                     if (tdcCalDelay = 0) then
                        tdcCalStop <= tdcCalTrigger;
                     else 
                        tdcCalState <= COUNTING_S;
                     end if;
                  end if;
               when COUNTING_S =>
                  if (tdcCalCount = tdcCalDelay) then
                     tdcCalStop  <= '1';
                     tdcCalState <= IDLE_S;
                  else
                     tdcCalCount <= tdcCalCount + 1;
                  end if;
               when others =>
                  tdcCalState <= IDLE_S;
            end case;
         end if;
      end if;
   end process;
   
   -- Instantiate TDCs
   G_CoarseTdcs : for i in 0 to N_TDC_CHANNELS_G-1 generate
      -- Coarse TDC module
      U_CoarseTdc : entity work.TdcCoarse
         generic map (
            TPD_G        => TPD_G,
            TDC_WIDTH_G  => TDC_COARSE_WIDTH_G
         )
         port map (
            -- Clock and registered data
            -- This clock is used to run the counter.
            clk         => tdcClk,
            sRst        => tdcRst,
            coarseOut   => coarseTdcValues(i),
            coarseValid => coarseTdcValid(i),
            -- Asynchronous start and stop (must be > 1 clk period)
            start       => tdcOrCalStart(i),
            stop        => tdcOrCalStop(i)
         );
      -- Synchronizer for coarse data
      U_CoarseSync : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => TDC_COARSE_WIDTH_G
         )
         port map (
            clk     => axiClk,
            rst     => axiRst,
            dataIn  => coarseTdcValues(i),
            dataOut => coarseTdcValuesSynced(i)
         );
      -- Mix in calibration signals
      tdcOrCalStart(i) <= tdcCalStart or tdcStart(i);
      tdcOrCalStop(i)  <= tdcCalStop  or tdcStop(i);
   end generate;
   
   -- Synchronizer calibration signals to tdc clock domain
   U_CalDelaySync : entity work.SynchronizerVector
      generic map (
         WIDTH_G => TDC_COARSE_WIDTH_G
      )
      port map (
         clk     => tdcClk,
         dataIn  => r.calDelay,
         dataOut => tdcCalDelay
      );   
   U_CalTriggerSync : entity work.SynchronizerEdge
      port map (
         clk        => tdcClk,
         dataIn     => r.calTrigger,
         risingEdge => tdcCalTrigger
      );         
   -- Synchronizer for reset signal
   U_TdcRstSync : entity work.RstSync
      port map (
         clk      => tdcClk,
         asyncRst => axiRst,
         syncRst  => tdcRst
      );

end architecture rtl;
