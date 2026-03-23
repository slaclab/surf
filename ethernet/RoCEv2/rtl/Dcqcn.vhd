-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: DCQCN top
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity Dcqcn is

  generic (
    TPD_G          : time                := 1 ns;
    LINE_RATE_G    : integer             := 1_250_000_000;  -- 1.25 GB/s = 10 Gb/s
    CLK_FREQ_G     : real                := 156.25E+6;
    AXIS_CONFIG_G  : AxiStreamConfigType := SSI_CONFIG_INIT_C;
    RST_ASYNC_G    : boolean             := false;
    RST_POLARITY_G : sl                  := '1'
    );
  port (
    axisClk         : in  sl;
    axisRst         : in  sl;
    -- CNP
    cnp             : in  sl;
    -- AXI-Lite Interface
    axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    -- AXI-Stream Interface
    sAxisMaster     : in  AxiStreamMasterType;
    sAxisSlave      : out AxiStreamSlaveType;
    mAxisMaster     : out AxiStreamMasterType;
    mAxisSlave      : in  AxiStreamSlaveType
    );

end entity Dcqcn;

architecture rtl of Dcqcn is

  type StateType is (
    IDLE_S,
    THE_CNP_AFTERMATH_S
    );

  type RegType is record
    Rc                 : slv(31 downto 0);  -- Current rate, int
    Rt                 : slv(31 downto 0);  --  Target rate, int
    alpha              : slv(9 downto 0);  -- alpha, int
    alphaG             : slv(9 downto 0);  -- (1-g), axil
    dec_gain           : slv(3 downto 0);  -- Rc=Rc(1-alpha/2^dec_gain), axil
    Rai                : slv(31 downto 0);  -- Additive step, axil
    Rhai               : slv(31 downto 0);  -- Hyper step, axil
    clampTgtRate       : sl;            -- Clamp target rate step, axil
    Rmin               : slv(31 downto 0);  -- Minimum rate, axil
    cnpDecDetected     : sl;            -- CNP detected for decrement process
    cnpAlphaDetected   : sl;            -- CNP detected for alpha process
    incReset           : sl;            -- Reset increment process timers
    incEn              : sl;            -- Enable Increase process
    decEn              : sl;            -- Enbale decrease process
    alphaUpdEn         : sl;            -- Enable alpha update process
    rateIncInterval    : slv(31 downto 0);  -- Interval for increase stage, axil
    rateDecInterval    : slv(15 downto 0);  -- Interval for decrease stage, axil
    alphaUpdInterval   : slv(15 downto 0);  -- Interval for alpha update, axil
    timeStageThreshold : slv(7 downto 0);  -- Threshold for increase stage, axil
    firstCnp           : boolean;
    axilReadSlave      : AxiLiteReadSlaveType;
    axilWriteSlave     : AxiLiteWriteSlaveType;
    state              : StateType;
  end record RegType;

  constant CLK_PERIOD_C                         : real             := 1.0/CLK_FREQ_G;  -- sec
  constant LINE_RATE_SLV_C                      : slv(31 downto 0) := conv_std_logic_vector(LINE_RATE_G, 32);
  -- Time intervals in sec
  constant RATE_INC_INTERVAL_INIT_C             : real             := 1.5E-3;  -- sec
  constant RATE_DEC_INTERVAL_INIT_C             : real             := 4.0E-6;  -- sec
  constant ALPHA_UPD_INTERVAL_INIT_C            : real             := 55.0E-6;  -- sec
  -- Time interval in clk periods
  constant RATE_INC_INTERVAL_CLK_CYCLES_INIT_C  : slv(31 downto 0) := toSlv(getTimeRatio(RATE_INC_INTERVAL_INIT_C, CLK_PERIOD_C), 32);
  constant RATE_DEC_INTERVAL_CLK_CYCLES_INIT_C  : slv(15 downto 0) := toSlv(getTimeRatio(RATE_DEC_INTERVAL_INIT_C, CLK_PERIOD_C), 16);
  constant ALPHA_UPD_INTERVAL_CLK_CYCLES_INIT_C : slv(15 downto 0) := toSlv(getTimeRatio(ALPHA_UPD_INTERVAL_INIT_C, CLK_PERIOD_C), 16);

  constant REG_INIT_C : RegType := (
    Rc                 => LINE_RATE_SLV_C,  -- 1250 GB/s = 10 Gb/s
    Rt                 => LINE_RATE_SLV_C,
    alpha              => (others => '1'),  -- Q0.10 => 1
    alphaG             => "1111111100",     -- Q0.10 => (1-2^8)
    dec_gain           => x"1",             -- Rt=Rc(1-alpha/2)
    Rai                => x"005B8D80",      -- 6 MB/s
    Rhai               => x"00B71B00",      -- 12 MB/s
    clampTgtRate       => '0',              -- false
    Rmin               => x"00989680",      -- 10 MB/s
    cnpDecDetected     => '0',
    cnpAlphaDetected   => '0',
    incReset           => '0',
    incEn              => '0',
    decEn              => '0',
    alphaUpdEn         => '0',
    rateIncInterval    => RATE_INC_INTERVAL_CLK_CYCLES_INIT_C,
    rateDecInterval    => RATE_DEC_INTERVAL_CLK_CYCLES_INIT_C,
    alphaUpdInterval   => ALPHA_UPD_INTERVAL_CLK_CYCLES_INIT_C,
    timeStageThreshold => x"05",
    firstCnp           => true,
    axilReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C,
    state              => IDLE_S);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal timeStage : slv(7 downto 0);
  signal cnpRe     : sl;

  signal newDecRc : slv(31 downto 0);
  signal newDecRt : slv(31 downto 0);
  signal newIncRc : slv(31 downto 0);
  signal newIncRt : slv(31 downto 0);
  signal newAlpha : slv(9 downto 0);

  signal decValid   : sl;
  signal incValid   : sl;
  signal alphaValid : sl;

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- CNP rising edge
  -----------------------------------------------------------------------------
  CnpEdge_1 : entity surf.SynchronizerEdge
    generic map (
      TPD_G    => TPD_G,
      STAGES_G => 3
      )
    port map (
      clk        => axisClk,
      rst        => axisRst,
      dataIn     => cnp,
      risingEdge => cnpRe
      );

  -----------------------------------------------------------------------------
  -- Rate decrease process
  -----------------------------------------------------------------------------
  RateDecProc_1 : entity surf.RateDecProc
    generic map (
      TPD_G          => TPD_G,
      RST_ASYNC_G    => RST_ASYNC_G,
      RST_POLARITY_G => RST_POLARITY_G)
    port map (
      clk             => axisClk,
      rst             => axisRst,
      start           => r.decEn,
      cnpDetected     => r.cnpDecDetected,
      clampTgtRate    => r.clampTgtRate,
      alpha           => r.alpha,
      dec_gain        => r.dec_gain,
      Rmin            => r.Rmin,
      rateDecInterval => r.rateDecInterval,
      timeStage       => timeStage,
      curRc           => r.Rc,
      curRt           => r.Rt,
      newRc           => newDecRc,
      newRt           => newDecRt,
      valid           => decValid
      );

  -----------------------------------------------------------------------------
  -- Rate increase process
  -----------------------------------------------------------------------------
  RateIncProc_1 : entity surf.RateIncProc
    generic map (
      TPD_G          => TPD_G,
      LINE_RATE_G    => LINE_RATE_G,
      RST_ASYNC_G    => RST_ASYNC_G,
      RST_POLARITY_G => RST_POLARITY_G)
    port map (
      clk                => axisClk,
      rst                => axisRst,
      start              => r.incEn,
      rstTimers          => r.incReset,
      rateIncInterval    => r.rateIncInterval,
      Rai                => r.Rai,
      Rhai               => r.Rhai,
      curRc              => r.Rc,
      curRt              => r.Rt,
      timeStageThreshold => r.timeStageThreshold,
      timeStage          => timeStage,
      newRc              => newIncRc,
      newRt              => newIncRt,
      valid              => incValid
      );

  -----------------------------------------------------------------------------
  -- Alpha update process
  -----------------------------------------------------------------------------
  AlphaUpdate_1 : entity surf.AlphaUpdate
    generic map (
      TPD_G          => TPD_G,
      RST_ASYNC_G    => RST_ASYNC_G,
      RST_POLARITY_G => RST_POLARITY_G)
    port map (
      clk              => axisClk,
      rst              => axisRst,
      start            => r.alphaUpdEn,
      curAlpha         => r.alpha,
      alphaG           => r.alphaG,
      cnpDetected      => r.cnpAlphaDetected,
      alphaUpdInterval => r.alphaUpdInterval,
      newAlpha         => newAlpha,
      valid            => alphaValid);

  -----------------------------------------------------------------------------
  -- Token Bucket
  -----------------------------------------------------------------------------
  TokenBucket_1 : entity surf.TokenBucket
    generic map (
      TPD_G         => TPD_G,
      CLK_FREQ_G    => CLK_FREQ_G,
      FRAC_BITS_G   => 16,
      AXIS_CONFIG_G => AXIS_CONFIG_G)
    port map (
      axisClk     => axisClk,
      axisRst     => axisRst,
      sAxisMaster => sAxisMaster,
      sAxisSlave  => sAxisSlave,
      Rc          => r.Rc,
      mAxisMaster => mAxisMaster,
      mAxisSlave  => mAxisSlave);

  -----------------------------------------------------------------------------
  -- DCQCN
  -----------------------------------------------------------------------------
  comb : process (alphaValid, axilReadMaster, axilWriteMaster, axisRst, cnpRe,
                  decValid, incValid, newAlpha, newDecRc, newDecRt, newIncRc,
                  newIncRt, r) is
    variable v      : RegType;
    variable axilEp : AxiLiteEndPointType;
  begin  -- process comb
    -- Latch the current value
    v := r;
    ---------------------------------------------------------------------------
    -- Axi-Lite interface
    ---------------------------------------------------------------------------
    -- Determine the transaction type
    axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    -- Gen registers
    axiSlaveRegister(axilEp, x"000", 0, v.alphaG);
    axiSlaveRegister(axilEp, x"000", 10, v.dec_gain);
    axiSlaveRegister(axilEp, x"000", 14, v.timeStageThreshold);
    axiSlaveRegister(axilEp, x"000", 22, v.clampTgtRate);
    axiSlaveRegister(axilEp, x"004", 0, v.Rai);
    axiSlaveRegister(axilEp, x"008", 0, v.Rhai);
    axiSlaveRegister(axilEp, x"00C", 0, v.Rmin);
    axiSlaveRegister(axilEp, x"010", 0, v.rateIncInterval);
    axiSlaveRegister(axilEp, x"014", 0, v.rateDecInterval);
    axiSlaveRegister(axilEp, x"014", 16, v.alphaUpdInterval);
    axiSlaveRegisterR(axilEp, x"018", 0, r.Rc);
    axiSlaveRegisterR(axilEp, x"01C", 0, r.Rt);
    axiSlaveRegisterR(axilEp, x"020", 0, r.alpha);
    -- Closeout the transaction
    axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

    ---------------------------------------------------------------------------
    -- DCQCN Overseer
    ---------------------------------------------------------------------------
    -- CNP effect
    case r.state is
      -------------------------------------------------------------------------
      when IDLE_S =>
        -----------------------------------------------------------------------
        if cnpRe = '1' then
          v.cnpAlphaDetected := '1';
          v.cnpDecDetected   := '1';
          v.alphaUpdEn       := '1';
          v.decEn            := '1';
          v.incEn            := '1';
          v.incReset         := '1';
          v.state            := THE_CNP_AFTERMATH_S;
          if r.firstCnp then
            v.alpha            := (others => '1');
            v.cnpAlphaDetected := '0';
            v.firstCnp         := false;
          end if;
        end if;
      -----------------------------------------------------------------------
      when THE_CNP_AFTERMATH_S =>
        v.incReset := '0';
        v.state    := IDLE_S;
    -----------------------------------------------------------
    end case;
    -- Update value for inc process
    if incValid = '1' then
      v.Rc := newIncRc;
      v.Rt := newIncRt;
    end if;
    -- Update value and rst CNP for dec process
    if decValid = '1' then
      v.cnpDecDetected := '0';
      v.Rc             := newDecRc;
      v.Rt             := newDecRt;
    end if;
    -- Update value and rst CNP for alpha process
    if alphaValid = '1' then
      v.cnpAlphaDetected := '0';
      v.alpha            := newAlpha;
    end if;

    -- Outputs
    axilWriteSlave <= r.axilWriteSlave;
    axilReadSlave  <= r.axilReadSlave;

    -- Reset
    if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
      v := REG_INIT_C;
    end if;

    -- Register update
    rin <= v;

  end process comb;

  seq : process (axisClk, axisRst) is
  begin
    if (RST_ASYNC_G and axisRst = RST_POLARITY_G) then
      r <= REG_INIT_C after TPD_G;
    elsif rising_edge(axisClk) then
      r <= rin after TPD_G;
    end if;
  end process seq;


end architecture rtl;
