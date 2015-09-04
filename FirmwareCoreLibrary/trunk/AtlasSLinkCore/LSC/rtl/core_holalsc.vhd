--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : core_holalsc.vhd                                             --
--                                                                            --
-- Description : Core function for an HOLA type S-LINK Link Source            --
--               See also http://www.cern.ch/HSI/s-link/devices/hola          --
--                                                                            --
-- Authors     : Original design by Aurelio Ruiz Garcia                       --
--               Altera/Xilinx version by Jesper Moller Haee                  --
--                                                                            --
-- Notes       : Do not modify this file, if you need any modifications to    --
--               the HOLALSC core, please contact the S-LINK team at CERN.    --
--                                                                            --
-- Contact     : Stefan Haas, CERN, EP-Division                               --
--               Stefan.Haas@cern.ch                                          --
--               CERN - European Organization for Nuclear Research            --
--               CH-1211 Geneva 23                                            --
--               Switzerland                                                  --
--                                                                            --
--------------------------------------------------------------------------------
--                                                                            --
--                                COPYRIGHT CERN, 2003                        --
--                                                                            --
--                     This product includes technical information            --
--                         created and made available by CERN                 --
--                                                                            --
--               Please read and respect the Copyright statement as described --
--               in the S-LINK specification, which can be found at           --
--                           http://www.cern.ch/hsi/s-link                    --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
-- Version |    Date     |Author| Modifications                               --
--------------------------------------------------------------------------------
--    1.0  | 17-Jan-2003 |  SH  | First distribution                          --
--    1.1  | 02-May-2003 |  SH  | Incorporated latest changes to HOLA source: --
--         |             |      | changes in entities CONTROL and TEST        --
--    1.2  | 19-May-2003 |  SH  | Updated changed HOLA source files to add a  --
--         |             |      | power-up reset input to the LSC core.       --
--    1.3  | 26-May-2003 |  SH  | Changes in module RETCH for TLK link up FSM --
--    1.4  | 07-Feb-2005 |  SH  | Same code as for ATLAS ROL LSC mezzanine    --
--    1.5  | 15-Sep-2011 |  SH  | Modified Xilinx FIFO instantiation for      --
--         |             |      | current asynchronous FIFO for Virtex-4.     --
--         |             |      | Enabled internal XCLK divider for Xilinx.   --
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
-- File name   : holalsc_ent.vhd                                              --
--                                                                            --
-- Author      : Aurelio Ruiz Garcia, CERN, EP-Division                       --
--                                                                            --
-- Description : HOLA type S-LINK Link Source Card                            --
--               ENTITY                                                       --
--                                                                            --
-- Notes:        Only the active pins are in this architecture. Although      --
--               unlikely, this may limit possibilities for future upgrades.  --
--                                                                            --
--               This design needs three external global clock signals:       --
--                 UCLK, XCLK and RX_CLK                                      --
--                                                                            --
--               ------------------------------------------                   --
--                           TIMING REQUIREMENTS                              --
--               Clock                                                        --
--               ------------------------------------------                   --
--               UCLK           Typ. 40 MHz - From FEMB                       --
--               XCLK               100 MHz - external clock                  --
--               RX_CLK             100 MHz - Recovered from TLK-2501         --
--                                                                            --
--               A fourth clock (ICLK_2 -62.5 MHz) will be used, but          --
--               internally generated after XCLK (using the internal PLL of   --
--               the APEX20k30E devices).                                     --
--                                                                            --
--               It is possible to work in a simulation mode by setting the   --
--               generic SIMULATION "ON", to increase speed when simulating   --
--               on a computer (more details on generics header).             --
--                                                                            --
--               HOLA LSC includes a FIFO used to separate UCLK and ICLK_2    --
--               clock domains. Parameters for the FIFO are set by the        --
--               generics FIFODEPTH,LOG2DEPTH and FULLMARGIN (see complete    --
--               description on generics header).                             --
--                                                                            --
--               It is recommended to add a test connector on boards using    --
--               this core. This connector should carry the signals:          --
--               UCLK                      -- terminate near connector        --
--               LDOWN_N                                                      --
--               URESET_N                                                     --
--               UWEN_N                                                       --
--               UCTRL_N                                                      --
--               LFF_N                                                        --
--               UTEST_N                                                      --
--               UD0                                                          --
--               UD1                                                          --
--               UD31                                                         --
--               URL0                                                         --
--               URL4                                                         --
--                                                                            --
--                                                                            --
-- Synplify    : Warnings:                                                    --
--                                                                            --
-- Notes       : More information can be found in:                            --
--                                                                            --
--               http://hsi.web.cern.ch/HSI/s-link/devices/hola               --
--                                                                            --
-- Size        :                                                              --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
-- Version |    Date     |Author|      Modifications                          --
--------------------------------------------------------------------------------
--   0.1   | 17-Oct-2001 | ARG  |     Original version                        --
--   0.2   | 15-Apr-2002 | ARG  | Generics selection added.                   --
--   0.3   | 28-Nov-2002 | JMH  | generic selection Altera vs. Xilenx added   --
--   0.4   |  9-dec-2002 | JMH  | DLL_RESET input added                       --
--         |             |      | the signal affects only Xilinx versions     --
--   0.5   | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
--==============================================================================
entity holalsc_core is
--==============================================================================
--==============================================================================
--------------------------------------------------------------------------------
-- GENERICS                                                                   --
--                                                                            --
-- SIMULATION: 1=ON/OFF=0. It sets if user wants to use the files for software--
--             simulation (ON) or if real HOLA LDC must be synthesized (OFF)  --
--             Simulation ON : Initialitation time on each card aprox.  6 us  --
--             simulation OFF: Initialitation time on each card aprox. 25 ms  --
--                                                                            --
-- XCLK_FREQ : Reference clock oscillator frequency in MHz                    --
--             XCLK_FREQ = 100 -> 2.0 Gb/s link speed (default)               --
--             XCLK_FREQ = 125 -> 2.5 Gb/s link speed                         --
--                                                                            --
-- ACTIVITY_LENGTH : When a write operation was performed on the FIFO in the  --
--             last 2^ACTIVITY_LENGTH ICLK2 (internally generated 62.5 MHz    --
--             clock)clock cycles, the activity LED ACTIVITYLED_N will be     --
--             illuminated.                                                   --
--                                                                            --
--             Examples :                                                     --
--               ACTIVITY_LENGTH = 5 => Num. cycles = 2^5 = 32                --
--                   32 cycles x 16 ns/cycle = 512 ns.                        --
--               ACTIVITY_LENGTH = 6 => Num. cycles = 2^6 = 64                --
--                   64 cycles x 16 ns/cycle = 1.024 ms.                      --
--                                                                            --
-- FIFODEPTH : Depth of the FIFO. LFF_N will be active after                  --
--             FIFODEPTH-FULLMARGIN words have been written to the FIFO.      --
--             Maximum depth for an Altera EP20k30 device is 512 words.       --
--                                                                            --
-- LOG2DEPTH : Just your own calculation of the width of the counter that     --
--             counts how much is written. E.g. FIFODEPTH=32 => LOG2DEPTH=5;  --
--             FIFODEPTH=64 => LOG2DEPTH=6 etc.                               --
--                                                                            --
-- FULLMARGIN: Amount of words that must be guaranteed to be left before      --
--             sending the flow control signal.                               --
--                                                                            --
-- note : the above generics LOG2DEPTH and FIFODEPTH                          --
--        are only generics for the VHDL core itself - the                    --
--        Hardware specific wizzard generated files is not affected thes will --
--        need to be changes via the wizzard                                  --
--                                                                            --
-- ALTERA_XILINX :  generic selection specifying which hardware specific      --
--                  components to use. affected modules FIFO (memory) and     --
--                  PLL/DLL (clockgenerators)                                 --
--                  1 => Altera , 0 => Xilinx                                 --
--                                                                            --
--------------------------------------------------------------------------------

generic(
  SIMULATION       : integer :=    0;   -- simulation mode
  ALTERA_XILINX    : integer :=    0;   -- 1=Altera, 0=Xilinx
  XCLK_FREQ        : integer :=  100;   -- Reference clock oscillator frequency
                                        -- 100 -> 2.0 Gb/s link speed (default)
                                        -- 125 -> 2.5 Gb/s link speed
  USE_PLL          : integer :=    0;   -- instantiate intenal PLL to generate ICLK2
  USE_ICLK2        : integer :=    1;   -- use ICLK_IN instead of internally generated clock
  ACTIVITY_LENGTH  : integer :=   15;   -- ACTLED duration
  FIFODEPTH        : integer :=   64;   -- LSC FIFO depth, only powers of 2
  LOG2DEPTH        : integer :=    6;   -- 2log of depth
  FULLMARGIN       : integer :=   16    -- words left when LFF_N set
);                                       

port (
   POWER_UP_RST_N : in  std_logic;      -- Power-up reset input
   -----------------------------------------------------------------------------
   -- S-LINK signals                                                       (46)
   -----------------------------------------------------------------------------
   UD            : in  std_logic_vector(31 downto 0);
   URESET_N      : in  std_logic;
   UTEST_N       : in  std_logic;
   UCTRL_N       : in  std_logic;
   UWEN_N        : in  std_logic;
   UCLK          : in  std_logic;
   LFF_N         : out std_logic;
   LRL           : out std_logic_vector( 3 downto 0);
   LDOWN_N       : out std_logic;
   -----------------------------------------------------------------------------
   -- S-LINK LEDs                                                          ( 5)
   -----------------------------------------------------------------------------
   TESTLED_N     : out std_logic;        -- Red
   LDERRLED_N    : out std_logic;        -- Red, indicates FIFO overflow
   LUPLED_N      : out std_logic;        -- Green
   FLOWCTLLED_N  : out std_logic;        -- Red
   ACTIVITYLED_N : out std_logic;        -- Green. Activity LED.Data being sent
   -----------------------------------------------------------------------------
   -- Special signals                                                      ( 1)
   -----------------------------------------------------------------------------
   XCLK          : in std_logic;         -- 100 MHz clock
   ICLK2_IN      : in std_logic := '0';  -- 50 MHz clock derived from XCLK 
   -----------------------------------------------------------------------------
   -- Serializer/Deserializer (TLK-2501) -- general terminals              ( 1)
   -----------------------------------------------------------------------------
   ENABLE        : out std_logic;
   -----------------------------------------------------------------------------
   -- Transmitter side of TLK-2501 -- used for data transmission           (18)
   -----------------------------------------------------------------------------
   TXD           : out std_logic_vector(15 downto 0);
   -- Terminals to control the kind of data presented to the TLK-2501
   -- and their validity
   TX_EN         : out std_logic;
   TX_ER         : out std_logic;
   -----------------------------------------------------------------------------
   -- Receiver side of TLK-2501 -- return lines and flow control            (19)
   -----------------------------------------------------------------------------
   RXD           : in std_logic_vector(15 downto 0); -- Received parallel data
   RX_CLK        : in std_logic;         -- Recovered clock.
   -- Terminals to control the kind of data received from TLK-2501
   -- and their validity
   RX_ER         : in std_logic;
   RX_DV         : in std_logic;
   -----------------------------------------------------------------------------
   -- Other pins                                                             (0)
   -----------------------------------------------------------------------------
   DLL_RESET     : in std_logic := '0'    -- only affects Xilinx implementations
                                          -- and should always be low except if
                                          -- complete system is reset.
                                          -- for Altera map to GND
   );

end holalsc_core ;


--==============================================================================
--==============================================================================
--------------------------------------------------------------------------------
-- END OF ENTITY
--------------------------------------------------------------------------------
--==============================================================================
--==============================================================================
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : fifolsc.vhd                                                   --
--                                                                            --
-- Author     : Aurelio Ruiz, EP-Division, CERN                               --
--                                                                            --
-- Description: Dual clock, synchronous FIFO for the LSC.                     --
--              It is of the "show-ahead" type, which means                   --
--              that the data is shown before a read is done. Effectively,    --
--              the "not empty" flag is more like a "data available" flag.    --
--              For the rest it is a normal FIFO with an LFF_N output that    --
--              shows that only a few extra words may be written.             --
--                                                                            --
--              There are two different empty flags, each synchronised to each--
--              clock                                                         --
--                                                                            --
-- Notes      : Based on fifolsc.vhd (ODIN implementation)                    --
--              by Erik van der Bij, EP-division CERN                         --
--                                                                            --
--              Only works correctly with Altera FPGAs with dual ported       --
--              memory. APEX II, APEX 20K, Mercury and 10KE all do have this, --
--              10KA devices don't.                                           --
--                                                                            --
--              Size of shiftreg must be def. set. If necessary, add prescaler--
--                                                                            --
--------------------------------------------------------------------------------
--                            Revision History                                --
--------------------------------------------------------------------------------
-- Version |   Mod.Date  |Author| Modifications                               --
--------------------------------------------------------------------------------
--  1.0    |  1-Nov-2001 | ARG  | First version                               --
--  1.1    | 19-Dec-2001 | ARG  | ACTLED_N added                              --
--  1.2    | 26-Mar-2002 | ARG  | ACTLED_N moved to test.vhd                  --
--  1.3    | 15-May-2002 | ARG  | rdfull => open to prevent warning synplify  --
--  1.4    | 10-Jun-2002 | ARG  | Generic FULLMARGIN unused, full flag set    --
--         |             |      | when half FIFO written.                     --
--  1.4    | 16-Aug-2002 | JMH  | Reviewed - Comments added                   --
--         |             |      | rdfull=>open removed by ARG on earlier date --
--  1.5    | 02-OCT-2002 | JMH  | register removed from ACLR input            --
--  1.6    | 28-OCT-2002 | JMH  | Altera LPM put in to separate file          --
--         |             |      | now in FIFO_LPM_LSC.vhd                     --
--  1.7    | 2-dec-2002  | JMH  | support for both Altera and Xilinx          --
--         |             |      | the FIFO must now be named AFIFOLSC or      --
--         |             |      | XFIFOLSC - selected by the generic          --
--         |             |      | ALTERA_XILINX  1 is Altera and 0 is Xilinx  --
--  1.8    | 12-dec-2002 | JMH  | Altera FIFO changed to empty flag being     --
--         |             |      | sync. to read clock - now same as Xilinx ver--
--  1.9    | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity FIFOLSC is
--==============================================================================
--------------------------------------------------------------------------------
-- GENERICS                                                                   --
--                                                                            --
-- FIFODEPTH: Depth of the FIFO. LFF_N will be active after FIFODEPTH-8 words --
--            have been written to the FIFO. Recommended value 32 or higher.  --
--            With value of 16 performance will be lower as it may happen that--
--            the FIFO will be emptied before LFF_N has gone inactive. This is--
--            because the FIFO flags have a very long reaction time.          --
-- LOG2DEPTH: Just your own calculation of the width of the counter that      --
--            counts how much is written. E.g. FIFODEPTH=32 => LOG2DEPTH=5;   --
--            FIFODEPTH=64 => LOG2DEPTH=6 etc.                                --
-- FULLMARGIN:Amount of words that must be guaranteed to be left before       --
--            sending the flow control signal.                                --
-- ALTERA_XILINX:  selects the device specific wizard component to enstantiate--
--------------------------------------------------------------------------------
  generic(
    ALTERA_XILINX : integer;            -- 1=Altera 0=Xilinx
    FIFODEPTH     : integer;            -- only powers of 2
    LOG2DEPTH     : integer;            -- 2log of depth
    FULLMARGIN    : integer             -- words left when LFF_N
                                        -- set
    );

  port (
    POWER_UP_RST_N : in std_logic;
    ACLR           : in std_logic;      -- async clear
    TEST_RES       : in std_logic;      -- reset signal from
                                        -- the TEST module
    WCLK           : in std_logic;      -- write clock
    D              : in std_logic_vector(33 downto 0);  -- bit 33 marks testword
                                        -- bit 32 marks ctrlword
                                        -- 31 to 0 is input data

    WEN  : in  std_logic;               -- Write enable
    FULL : out std_logic;               -- Full Flag for testing
                                        -- synchr. to write clock

    LFF_N : out std_logic;                      -- Full Flag and XOFF
    RCLK  : in  std_logic;                      -- read clock,62.5 MHz
    Q     : out std_logic_vector(33 downto 0);  -- bit 33 marks testword
                                                -- bit 32 marks ctrlword
                                                -- 31 to 0 is output data

    REN       : in  std_logic;          -- read enable
    EMPTY     : out std_logic;          -- empty flag, synchr.
                                        -- to read clock
    WR_EMPTY  : out std_logic;          -- empty flag, synchr.
                                        -- to write clock
    DERRLED_N : out std_logic;          -- Error LED, not LSC
    LFFLED_N  : out std_logic           -- Xoff LED, flowcontrol

    );
end FIFOLSC;


--==============================================================================
architecture behavioural of FIFOLSC is
--==============================================================================


  component XFIFOLSC  -- wizard generated FIFO for Xilinx Devices
     generic(
       LOG2DEPTH     : integer);            -- 2log of depth
    port (
      din           : in  std_logic_vector(33 downto 0);
      wr_en         : in  std_logic;
      wr_clk        : in  std_logic;
      rd_en         : in  std_logic;
      rd_clk        : in  std_logic;
      rst           : in  std_logic;
      dout          : out std_logic_vector(33 downto 0);
      full          : out std_logic;    -- sync. to wr_clk
      overflow      : out std_logic;    -- sync. to wr_clk
      empty         : out std_logic;    -- sync. to rd_clk
      wr_data_count : out std_logic_vector((LOG2DEPTH - 1) downto 0));
  end component;

  component AFIFOLSC
    port (
      data    : IN  STD_LOGIC_VECTOR (33 DOWNTO 0);
      wrreq   : IN  STD_LOGIC;
      rdreq   : IN  STD_LOGIC;
      rdclk   : IN  STD_LOGIC;
      wrclk   : IN  STD_LOGIC;
      aclr    : IN  STD_LOGIC := '0';
      q       : OUT STD_LOGIC_VECTOR (33 DOWNTO 0);
      rdempty : OUT STD_LOGIC;
      wrfull  : OUT STD_LOGIC;
      wrusedw : OUT STD_LOGIC_VECTOR ((LOG2DEPTH - 1) DOWNTO 0)); 
  end component;

  signal sub_wrfull : std_logic;
  signal sub_empty  : std_logic;
  signal sub_empty1 : std_logic;
  signal overflow   : std_logic;

  signal wrusedw   : std_logic_vector((LOG2DEPTH - 1) downto 0);
  signal wrusedw_d : std_logic;


  signal sLFF_N : std_logic;
  signal sFULL  : std_logic;
  signal reset  : std_logic;
--==============================================================================
begin
--==============================================================================

  AFIFO : if ALTERA_XILINX = 1 generate

    AFIFOLSC1 : AFIFOLSC
      port map (
        data    => D,
        wrreq   => WEN,
        rdreq   => REN,
        rdclk   => RCLK,
        wrclk   => WCLK,
        aclr    => reset,
        q       => Q,
        rdempty => sub_empty,
        wrfull  => sub_wrfull,
        wrusedw => wrusedw);
        
   overflow <= sub_wrfull;
   
  end generate;

  XFIFO : if ALTERA_XILINX = 0 generate

    XFIFOLSC1 : XFIFOLSC                -- Xilinx FIFO
      generic map (
         LOG2DEPTH    => LOG2DEPTH)
      port map (
        din           => D,
        wr_en         => WEN,
        rd_en         => REN,
        rd_clk        => RCLK,
        wr_clk        => WCLK,
        rst           => reset,
        dout          => Q,
        full          => sub_wrfull,
        overflow      => overflow,
        empty         => sub_empty,
        wr_data_count => wrusedw);

  end generate;


-- empty sync process -- wr_empty
  sync_WCLK : process
  begin
    wait until WCLK'event and WCLK = '1';
    sub_empty1 <= sub_empty;
    WR_EMPTY   <= sub_empty1;
  end process;

  EMPTY <= sub_empty;

--------------------------------------------------------------------------------
-- LFF PROCESS : LFF_N is set low when only one half or fewer cells are still --
--               free to allow a response time in the write process           --
--                                                                            --
--------------------------------------------------------------------------------
  DERRLED_N <= not overflow;          -- ERR LED on when completely full
  reset     <= aclr or test_res or not POWER_UP_RST_N;

  wrusedw_proc : process
  begin
    wait until wclk'event and wclk = '1';
    wrusedw_d <= wrusedw(LOG2DEPTH-1);  -- one if equal or more than
  end process;


-- LFF changed from depending on FULLMAGIN generic
-- now LFF is activated if FIFO half full or more
-- changed by ARG, reason unknown by JMH
  lffprocess : process
  begin
    wait until (wclk'event and wclk = '1');
    sLFF_N   <= not (wrusedw_d);        -- for User (FEMB)
    sFULL    <= wrusedw_d;              -- for TEST module
    LFFLED_N <= not (wrusedw_d);        -- LED

  end process;

-- register off LFF_N and FULL signals
  out_proc : process
  begin
    wait until (wclk'event and wclk = '1');
    LFF_N <= sLFF_N;
    FULL  <= sFULL;
  end process;
end behavioural;
--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : testing_st.vhd                                               --
--                                                                            --
-- Title       : Test Pattern Generator and Input Register                    --
--                                                                            --
-- Author      : Aurelio Ruiz                                                 --
--                                                                            --
-- Description : Test mode begins with the first word having test flag high.  --
--                  Data in this first word is test word (it must be sent)    --
--               Test mode ends with the first word having test flag low.     --
--                  This word is no longer a test word (it must be discarded) --
--               After test mode, normal mode is not recovered until empty    --
--                  flag is high, in order to check the FIFO empty flag       --
--                                                                            --
--               The only case in which data are not written from user is when--
--               LFF is active.                                               --
--               That means that data can still be read from user when LDOWN_N--
--               is low, to provide the user a longer response delay, until   --
--               the FIFO is full.                                            --
--                                                                            --
--               LDOWN_N signal when testing is not set by this block, but by --
--               control block                                                --
--                                                                            --
-- Notes       : based on testing.vhd (ODIN implementation) by                --
--               Erik van der Bij, CERN, EP-Division                          --
--               Zoltan Meggyesi,  CERN, EP-Division                          --
--               Gyorgy Rubin,     CERN, EP-Division                          --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
--     Version     |    Date     |  Author  | Modifications                   --
--------------------------------------------------------------------------------
--       0.1       |  1-Nov-2001 |   ARG    | First Version                   --
--       0.2       | 29-Nov-2001 |   ARG    | Synchronisation for FULL removed--
--                 |             |          | synchr. generated in FIFO       --
--       0.3       | 17-Apr-2002 |   ARG    | UTEST input changed to active   --
--                 |             |          | low                             --
--       0.4       |  4-Jun-2002 |   ARG    | Ldown signal added              --
--       0.4       | 20-Aug-2002 |   JMH    | reviewed,                       --
--                 |             |          | comments cleaned up             --
--       0.5       | 27-Jan-2003 |   JMH    | tmode output signal now set in  --
--                 |             |          | test reset state also           --
--       0.51      | 28-jan-2003 |   JMH    | removed registor on tmode output--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--------------------------------------------------------------------------------
entity TESTING_st is
--------------------------------------------------------------------------------
   port (
      SRESET   : in  std_logic;                           -- from Control block
      POWER    : in  std_logic;
      UCLK     : in  std_logic;                           -- Clock from user
      UTEST_N  : in  std_logic;
      FULL     : in  std_logic;                           -- Full Flag from FIFO
      EF       : in  std_logic;                           -- Empty flag, test
      SHIFTR   : in  std_logic_vector(32 downto 0);
      FIFO_RES : out std_logic;
      test     : out std_logic;                           -- Device in test mode
      twen_n   : out std_logic;
      tmode    : out std_logic                            -- Output mux. control
   );
end TESTING_st;

--------------------------------------------------------------------------------
architecture behaviour of TESTING_st is
--------------------------------------------------------------------------------

type test_state_type is (NORMAL,PATTERN,MORETEST,TOFF, WTEMPTY, TFLOW,
                         TEST_RESET);

signal test_state      : test_state_type;                  -- state machine
signal next_test_state : test_state_type;

signal stest           : std_logic;
signal stmode          : std_logic;
signal stwen_n         : std_logic;

signal reset_count     : std_logic;
signal reset_counter   : std_logic_vector(4 downto 0);

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SELFTEST MACHINE                                                           --
--                                                                            --
-- NORMAL  : No test mode. Device already powered on is not guaranteed. It    --
--                is the user's responsibility not to try to write during that--
--                time                                                        --
--                                                                            --
-- PATTERN : Test pattern generation                                          --
--                                                                            --
-- MORETEST: Checks if UTEST_N signal is still held low (new test cycle       --
--                must then start).                                           --
--                                                                            --
-- TOFF    : Test Flag set low, to indicate that previous word was the last   --
--                test word.                                                  --
--                                                                            --
-- WTEMPTY : Test mode will not actually finish until the FIFO is empty       --
--                                                                            --
-- TFLOW   : Flow control. It just waits until the FIFO is not full anymore.  --
--                Flow control is only performed in test mode. In normal data --
--                mode the user must be aware of signal LFF_N from FIFO       --
--                                                                            --
--------------------------------------------------------------------------------

test_sm: process(uclk,sreset,POWER)
begin
   if((sreset or (not POWER))= '1')then
        test_state           <= NORMAL;
   elsif UCLK'event and UCLK = '1' then
        test_state           <= next_test_state;
   end if;

end process test_sm;


next_test_proc: process (reset_counter,test_state,UTEST_N,ef, shiftr, full)
begin

   case test_state is
      when NORMAL =>                                      -- Normal data tx.
         stmode              <= '0';
         stest               <= '0';
         stwen_n             <= '1';
         reset_count         <= '0';
         if(UTEST_N='0')then                              -- if test starts
            next_test_state  <= TEST_RESET;               -- wait time for reset
         else
            next_test_state  <= NORMAL;
         end if;

      when TEST_RESET =>                                  -- Normal data tx.
         stmode              <= '1';
         stest               <= '0';
         stwen_n             <= '1';
         reset_count         <= '1';
         if((reset_counter(reset_counter'high)) = '1')then-- if test start
            next_test_state  <= PATTERN;                  -- sending pattern
         else
            next_test_state  <= TEST_RESET;               -- stays for 16clocks
         end if;

      when PATTERN =>                                     -- send test
         stmode              <= '1';
         stest               <= '1';
         stwen_n             <= '0';
         reset_count         <= '0';
         if(full = '1')then
            next_test_state  <= TFLOW;
         elsif(shiftr(30)='1')then
            next_test_state  <= MORETEST;
         else
            next_test_state  <= PATTERN;
         end if;

      when MORETEST =>                                    -- new test cycle
         stmode              <= '1';
         stest               <= '1';
         stwen_n             <= '1';
         reset_count         <= '0';
         if(UTEST_N='1')then
            next_test_state  <= TOFF;
         else
            next_test_state  <= PATTERN;
         end if;

      when TOFF =>                                        --no more test pattern
         stmode              <= '1';
         stest               <= '0';
         stwen_n             <= '0';
         reset_count         <= '0';
         next_test_state     <= WTEMPTY;

      when WTEMPTY =>                                     -- wait FIFO empty
         stmode              <= '1';
         stest               <= '0';                      -- mode
         stwen_n             <= '1';
         reset_count         <= '0';
         if(ef='1')then
            next_test_state  <= NORMAL;                   -- FIFO empty
         else
            next_test_state  <= WTEMPTY;                  -- go on waiting
         end if;

      when TFLOW =>                                       -- Flow control
         stmode              <= '1';
         stest               <= '1';
         stwen_n             <= '1';
         reset_count         <= '0';
         if(full='0')then
            next_test_state  <= PATTERN;
         else
            next_test_state  <= TFLOW;
         end if;

      when others =>
         stmode              <= 'X';
         stest               <= 'X';
         stwen_n             <= 'X';
         reset_count         <= 'X';
         next_test_state     <= NORMAL;

   end case;

end process;

reset_counter_proc:process
begin
   wait until uclk'event and uclk='1';
      if(reset_count = '0')then
         reset_counter       <= (others => '0');
      else
         reset_counter       <= reset_counter + 1;
   end if;
end process;


out_proc:process
begin
   wait until uclk'event and uclk='1';
      twen_n                 <= stwen_n;
   --   tmode                  <= stmode;
      test                   <= stest;
end process;

   tmode                     <= stmode;
   FIFO_RES                  <= reset_count;
end behaviour;

--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : control.vhd                                                   --
--                                                                            --
-- Authors    : Aurelio Ruiz                                                  --
--                                                                            --
-- Description: HOLA Reset and Initialitation                                 --
--                                                                            --
--              Inputs :                                                      --
--               URESET_N_I-> Reset signal. From reglsc block.                --
--               ICLK_2    -> 62.5 internally generated clock.                --
--               LDC_RESET -> RRES (remote reset command) from LDC received.  --
--               LDOWN     -> Link Down signal. Reasons for being down:       --
--                            - TLK not working.                              --
--                            - RLDN (remote link down) command received from --
--                              LDC.                                          --
--                            Link down due to test mode is not included in   --
--                            this signal.                                    --
--               TEST_N    -> From reglsc block, test request from user.      --
--                            To set LDOWN signal down after the request.     --
--               TESTMODE  -> Test data being sent through the channel.       --
--                                                                            --
--              Outputs:                                                      --
--               SEND_RESET    -> Internal LSC reset signal.                  --
--               SEND_LDCRESET ->LDC reset request received.                  --
--               SEND_LDOWN    -> Ldown signal for other blocks.              --
--               FEMB_LDOWN_N  -> LDOWN_N S-Link output. Same as SEND_LDOWN,  --
--                            but also low during test.                       --
--                            It must be mapped to an I/O register.           --
--               LUPLED_N      -> Link up S-Link LED.                         --
--                                                                            --
--              Initialisation process:                                       --
--                  - POWER state -> Waiting for transceiver to be working    --
--                                   properly. After it, some initialisation  --
--                                   time to assure estabilisation.           --
--                  - RESET state -> Device reset. If no explicitly asked, 1  --
--                                   clock cycle. reset signal sent to other  --
--                                   blocks in the card.                      --
--                  - UP state    -> Device ready.                            --
--                                                                            --
--              Link down process -> When link down is detected, inform other --
--                                   blocks in the card. To get out, a reset  --
--                                   must be performed on either side of the  --
--                                   link. Then the initialisation process is --
--                                   repeated.                                --
--                                                                            --
-- Size       : Estimated 47 LEs (3%).                                        --
--                                                                            --
-- Notes      : Based on file link.vhd by                                     --
--              Zoltan Meggyesi                                               --
--              Erik van der Bij, EP-division CERN                            --
--                                                                            --
--              LSC Reset, signal SENDLDCRESET set for 1 clock cycle, after it--
--              set reset signal                                              --
--                                                                            --
--              Unused reset states must be removed                           --
--------------------------------------------------------------------------------
-- Version |   Mod.Date  |Author| Modifications                               --
--------------------------------------------------------------------------------
--  0.1    |  1-Nov-01   | ARG  | First Version                               --
--  0.2    | 15-Feb-01   | ARG  | ures_g to get out of reset state            --
--  0.3    | 11-Apr-02   | ARG  | Input CTRL_RX_ER removed                    --
--  0.4    |  6-Jun-02   | ARG  | Output powering added                       --
--  0.5    | 12-Jun-02   | ARG  | During reset only set link down in local    --
--         |             |      | reset. Reset machine runs at UCLK           --
--  0.6    | 28-Aug-02   | JMH  | Reviewed, linit_machine changed. two extra  --
--         |             |      | states added and coding changed to enable   --
--         |             |      | direct mapping of the output signals to the --
--         |             |      | state variable. as a result the linit_out   --
--         |             |      | process has been removed.                   --
--  0.7    |  5-sep-02   | JMH  | the time from URESET# low to LDOWN# low     --
--         |             |      | exceeded required max 4 UCLK specified in   --
--         |             |      | in the S-LINK specification                 --
--         |             |      | the resetmachine was rewritten to ICLK_2    --
--         |             |      | Instead a UCLK counter was added to ensure  --
--         |             |      | that LDOWN# is low at least 4UCLK's         --
--         |             |      | linit_machine, faster by making ures_g      --
--         |             |      | rely on both curr_res and next_res          --
--         |             |      | signal name RESET_N changed to RESET_N_I    --
--         |             |      | signal name LDC_RESET changed to LDC_RESET_I--
--  0.8    |  21-Feb-02  | JMH  | when others changed for reset machine       --
--         |             |      | fix linkup problem in simulation            --
--  0.9    |  24-Feb-02  | JMH  | after the POWER state now gomes USER_RESET  --
--         |             |      | instead of INTERNAL RESET                   --
--  1.0    | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


--==============================================================================
entity CONTROL is
--==============================================================================
--------------------------------------------------------------------------------
-- GENERIC: INIT_LENGTH -> Length of counter filt_cnt used as filter during   --
--          initialisation. If user wants to simulate LDC on a PC, it is      --
--          adviced to set SIMULATION=1 generic on top level entity holaldc,to--
--          decrease simulation duration.                                     --
--          In simulation mode INIT_LENGTH takes the value 3.                 --
--          In normal operation INIT_LENGTH takes the value 15.               --
--------------------------------------------------------------------------------

  generic (
    INIT_LENGTH : integer
    );

  port(
    POWER_UP_RST_N : in  std_logic;
    URESET_N_I     : in  std_logic;     -- FROM REG REGISTER
    ICLK_2         : in  std_logic;
    UCLK           : in  std_logic;
    LDC_RESET_I    : in  std_logic;     -- reset from RETCH
    LDOWN          : in  std_logic;     -- Link Down from
                                        -- Return Channel
    TEST_N         : in  std_logic;     -- Test req.->Set LDOWN
    TESTMODE       : in  std_logic;     -- Test mode
    SEND_RESET     : out std_logic;     -- remote reset
    SEND_LDCRESET  : out std_logic;     -- LSC reset request
    SEND_LDOWN     : out std_logic;     -- inform Link DOWN
                                        -- this signal is used
                                        -- both for LDC down and
                                        -- errors in receiver
                                        -- (equiv. to r_up)
    FEMB_LDOWN_N   : out std_logic;     -- inform FEMB that
                                        -- the Link is Down
                                        -- Link Down also set in
                                        -- test mode
    POWERING       : out std_logic;
    LUPLED_N       : out std_logic
    );

end CONTROL;


--==============================================================================
architecture behavioural of CONTROL is
--==============================================================================

--------------------------------------------------------------------------------
-- State machine states
--------------------------------------------------------------------------------

-- the values for the states have been chosen to comply with the output signals
-- bit5 = POWERING
-- bit4 = FEMB_LDOWN_N
-- bit3 = SEND_LDOWN
-- bit2 = LUPLED_N
-- bit1 = SEND_RESET
-- bit0 = SEND_LDCRESET

--  constant POWER          : std_logic_vector(4 downto 0) := "00100";
  constant POWER          : std_logic_vector(4 downto 0) := "00010";
  constant UP             : std_logic_vector(4 downto 0) := "11000";
  constant UP_TESTMODE    : std_logic_vector(4 downto 0) := "10000";
  constant INTERNAL_RESET : std_logic_vector(4 downto 0) := "11011";
  constant USER_RESET     : std_logic_vector(4 downto 0) := "10011";
  constant DOWN           : std_logic_vector(4 downto 0) := "10100";

-- states for reset machine
  constant OK : std_logic_vector(1 downto 0) := "00";
  constant R1 : std_logic_vector(1 downto 0) := "10";
  constant WT : std_logic_vector(1 downto 0) := "01";

  signal hw_ok : std_logic;             -- TLK working

  signal ures_g                : std_logic;  -- int. reset signal
-- signal used to count 4 UCLK's
  signal cnt4_U                : std_logic_vector(2 downto 0);
-- signal used to count 8 ICLK_2's
  signal cnt8_I                : std_logic_vector(3 downto 0);
  signal clr_counters          : std_logic;
  signal cnt4_U_high_to_ICLK   : std_logic;
  signal cnt4_U_high_to_ICLK_1 : std_logic;

  signal testmode_i  : std_logic;       -- sync. test mode
  signal testmode_i1 : std_logic;

  signal pre_at_max : std_logic;       -- signals used
  signal prescale    : std_logic_vector( 5 downto 0);-- := (others => '0');  -- for the init.
  signal filt_cnt    : std_logic_vector(INIT_LENGTH-1 downto 0);  -- filter

  signal curr_res : std_logic_vector(1 downto 0);  -- reset st.machine
  signal next_res : std_logic_vector(1 downto 0);

  signal curr_init : std_logic_vector(4 downto 0);  -- mode st. machine
  signal next_init : std_logic_vector(4 downto 0);

-- unused
--  signal curr_first, next_first : std_logic_vector(1 downto 0);
--  signal cnt_clr                : std_logic;

begin
--------------------------------------------------------------------------------
-- Synchronisation to ICLK_2                                                  --
-- Signal testmode   from testing block must be synchronised.                 --
--------------------------------------------------------------------------------

  syncreg_iclk : process
  begin

    wait until ICLK_2'event and ICLK_2 = '1';

    testmode_i1 <= TESTMODE;
    testmode_i  <= testmode_i1;

  end process syncreg_iclk;

--------------------------------------------------------------------------------
-- LINK INITIALISATION                                                        --
-- The cycle when powering up the machine will be:                            --
-- POWER -> RESET -> UP.                                                      --
-- When the machine has been in the DOWN state, the cycle will be also        --
-- repeated.                                                                  --
-- Device will go out of DOWN state only after a reset signal (from either    --
-- side of the link) has been received.                                       --
--                                                                            --
-- State machine, states:                                                     --
--                                                                            --
-- POWER   : Power state, wait for filtering.                                 --
-- RESET   : RESET signal sent to frame block while reset signal is set high. --
--           It also works with one clock cycle reset input signals.          --
-- UP      : Link is up, device working.                                      --
-- LDCRESET: Request frame block to send a Remote Reset (RRES) command.       --
-- WT      : One clock cycle wait so that RRES command can be properly sent.  --
-- DOWN    : Link is down, stay here until reset. Although the problem clears --
--           itself the machine must stay here until reset is requested on any--
--           side of the Link.Then POWER state is then reached to perform link--
--           initialitation.                                                  --
--                                                                            --
-- The state machine is synchronised to clock ICLK_2                          --
--------------------------------------------------------------------------------

  ures_g <= curr_res(1) or next_res(1);


-- purpose: state register
-- type   : sequential
-- inputs : ICLK_2, POWER_UP_RST_N, next_init
-- outputs: curr_init
  linit_reg : process (ICLK_2, POWER_UP_RST_N)
  begin  -- process linit_reg
    if POWER_UP_RST_N = '0' then        -- asynchronous reset (active low)
      curr_init <= POWER;
    elsif ICLK_2'event and ICLK_2 = '1' then  -- rising clock edge
      curr_init <= next_init;
    end if;
  end process linit_reg;

  linit_machine : process(curr_init, hw_ok, LDOWN, LDC_RESET_i, ures_g, testmode_i, TEST_N)
  begin
    case curr_init is
      when POWER =>
        if (((not LDOWN) and hw_ok) = '1') then  -- Get out of it only if
--            next_init <= INTERNAL_RESET;          -- Cmd. diff.from ldown rx,
          next_init <= USER_RESET;
                                                 -- TLK working and filter up
        else
          next_init <= POWER;
        end if;

      when UP =>                        -- Link UP
        if (LDOWN = '1') then           -- Link down signal rx.
          next_init <= DOWN;
        elsif ( ures_g = '1') then      -- LOCAL reset
          next_init <= USER_RESET;
        elsif (LDC_RESET_i = '1') then  -- Remote reset
          next_init <= INTERNAL_RESET;
        elsif ((TEST_N = '0' or testmode_i = '1')) then
          next_init <= UP_TESTMODE;
        else
          next_init <= UP;
        end if;

      when UP_TESTMODE =>               -- Link UP - in testmode
        if (LDOWN = '1') then           -- Link down signal rx.
          next_init <= DOWN;
        elsif ( ures_g = '1') then      -- LOCAL reset
          next_init <= USER_RESET;
        elsif (LDC_RESET_i = '1') then  -- Remote reset
          next_init <= INTERNAL_RESET;
        elsif ((TEST_N = '0' or testmode_i = '1'))then
          next_init <= UP_TESTMODE;
        else
          next_init <= UP;
        end if;

      when INTERNAL_RESET =>
        if (ures_g = '1') then           -- Remote reset
          next_init <= USER_RESET;
        elsif ( LDC_RESET_i = '1') then  -- LOCAL reset
          next_init <= INTERNAL_RESET;
        elsif ((TEST_N = '0' or testmode_i = '1'))then
          next_init <= UP_TESTMODE;
        else
          next_init <= UP;
        end if;

      when USER_RESET =>
        if (ures_g = '1') then          -- Local reset
          next_init <= USER_RESET;
        elsif (LDC_RESET_i = '1') then
          next_init <= INTERNAL_RESET;
        elsif ((TEST_N = '0' or testmode_i = '1'))then
          next_init <= UP_TESTMODE;
        else
          next_init <= UP;
        end if;

      when DOWN =>
        if (((hw_ok and LDC_RESET_i) or (ures_g)) = '1') then
          next_init <= POWER;           -- Remote or local reset
        else
          next_init <= DOWN;
        end if;

      when others =>
        next_init <= DOWN;
    end case;

  end process linit_machine;


-- since the state value 'curr_state' is now directly map-able to the output signals
-- since 'curr_init' is only updated on ICLK_2
-- all these output signals are now synchronized with ICLK_2

  POWERING      <= curr_init(4);
  FEMB_LDOWN_N  <= curr_init(3);
  SEND_LDOWN    <= curr_init(2);
  SEND_RESET    <= curr_init(1);
  SEND_LDCRESET <= curr_init(0);

-- since the timing of the Link up LED is not essential
-- and since it is always opposite FEMB_LDOWN_N
-- i bit was saved in the State registers
  LUPLED_N <= not curr_init(3);

--------------------------------------------------------------------------------
-- S-Link signals might have glitches on ms before locking to input clock
-- or serial data, mainly because of fiber vibrations when connecting
-- hw_ok goes high when all signals have been high for a number of
-- cycles specified by length of filtcnt and the prescaler.
-- Code based on the one from controller.vhd from LDC.
--------------------------------------------------------------------------------

  prescale_proc : process
  begin
    wait until ICLK_2'event and ICLK_2 = '1';
    if (LDOWN = '1' ) then
      prescale <= (others => '0');
    else
      prescale <= prescale + '1';
    end if;
    -- pre_at_max gives a pulse everytime when prescaler at maximum
    pre_at_max <= '0';
    if (prescale = (prescale'range => '1')) then
      pre_at_max <= '1';
    end if;
  end process prescale_proc;


  filter_p : process
  begin
    wait until ICLK_2'event and ICLK_2 = '1';
    if ((LDOWN) = '1' ) then
      filt_cnt <= (others => '0');
                                        -- count only when received a
                                        -- pulse and not at maximum
                                        -- otherwise keep same value

    elsif (pre_at_max = '1' and filt_cnt(filt_cnt'high) = '0') then
      filt_cnt <= filt_cnt + '1';

    end if;

  end process filter_p;

  hw_ok <= filt_cnt(filt_cnt'high);     -- used in state machine

--------------------------------------------------------------------------------
-- RESET MACHINE ---------------------------------------------------------------
-- the reset sequence needs the following:                                    --
-- LDOWN must be low no longer than 4 UCLK's after URESET went low (S-LINK spec.)
-- LDOWN must be low for at laest 4UCLK's (S-LINK spec.)                      --
-- reset cycle must be longer than 8-9 ICLK_2 (FRAMELSC to send reset to LDC) --
-- to ICLK_2's already used in REGLSC to prevent METASTABILITY                --
-- ICLK_2 is always 62.5MHz, UCLK can be from 0 to 62.5MHz (typ. 40MHZ)       --
-- when a reset sequence is started 2 counters start as well                  --
-- one counts the 4 UCLK's required as minimum by the S-LINK spec             --
-- the other the 8 ICLK_2's needed by the framelsc module.                    --
--                                                                            --
-- in total i takes 3 ICLK_2's from URESET# is activalet to a respond is seen --
-- in LDOWN#, since the ICLK_2 is 62.5MHz and the UCLK max can be 62.5MHz     --
-- the LDOWN# will be dowmn in 4UCLK's                                        --                                                                  --
--------------------------------------------------------------------------------

-- purpose: state register
-- type   : sequential
-- inputs : ICLK_2, POWER_UP_RST_N, next_res
-- outputs: curr_res
  rr : process (ICLK_2, POWER_UP_RST_N)
  begin  -- process rr
    if POWER_UP_RST_N = '0' then        -- asynchronous reset (active low)
      curr_res <= R1;
    elsif ICLK_2'event and ICLK_2 = '1' then  -- rising clock edge
      curr_res <= next_res;
    end if;
  end process rr;
  reset_machine : process(cnt4_U_high_to_ICLK, cnt8_I, curr_res, ureset_n_i)
  begin
    case curr_res is

      when OK =>                        -- No reset, URESET_N is high

        if (ureset_n_i = '0') then
          next_res     <= R1;
          clr_counters <= '0';
        else
          next_res     <= OK;
          clr_counters <= '1';
        end if;

      when R1 =>                        -- Reset pulse
        clr_counters <= '0';
        if(cnt8_I(cnt8_I'high) = '1' and cnt4_U_high_to_ICLK = '1' )then
          next_res <= WT;
        else
          next_res <= R1;
        end if;
      when WT =>                        -- Wait while URESET_N is low
        if (ureset_n_i = '1') then
          next_res     <= OK;
          clr_counters <= '1';
        else
          next_res     <= WT;
          clr_counters <= '0';
        end if;

      when others =>
        next_res     <= R1;             -- changed to R1
        clr_counters <= '1';
    end case;
  end process reset_machine;

--------------------------------------------------------------------------------
-- 8 ICLK_2 counter with async reset, stops when 8 reached                    --
--------------------------------------------------------------------------------
  cnt8_I_proc : process(clr_counters, ICLK_2,POWER_UP_RST_N)
  begin
    if (clr_counters = '1' or POWER_UP_RST_N = '0') then
      cnt8_I <= (others => '0');
    elsif (ICLK_2'event and ICLK_2 = '1') then
      if(cnt8_I(cnt8_I'high) = '0')then
        cnt8_I <= cnt8_I + '1';
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------
-- 4 UCLK cycles counter with async reset, stops when 4 reached               --
-- to do this actually 5 rising ULCK's is counted insuring 4 complete cycles  --
-- S-LINK specification requires 4 complete UCLK cycles                       --
--------------------------------------------------------------------------------
  cnt4_U_proc : process(clr_counters, UCLK, POWER_UP_RST_N )
  begin

    if (clr_counters = '1' or POWER_UP_RST_N = '0') then
      cnt4_U <= (others => '0');
    elsif (UCLK'event and UCLK = '1') then
      if(cnt4_U(cnt4_U'high) = '0')then
        cnt4_U <= cnt4_U + '1';
      end if;
    end if;
  end process;

  cnt4_U_high_to_ICLK_proc : process
  begin
    wait until ICLK_2'event and ICLK_2 = '1';
    cnt4_U_high_to_ICLK_1 <= cnt4_U(cnt4_U'high);
    cnt4_U_high_to_ICLK   <= cnt4_U_high_to_ICLK_1;
  end process;


end behavioural;
--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------

--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : framelsc.vhd                                                  --
--                                                                            --
-- Authors    : Aurelio Ruiz                                                  --
--                                                                            --
-- Description: HOLA Framing block                                            --
--                                                                            --
--              Input  : ICLK_2 -> 62.5 MHz clock                             --
--                       RESET  -> Synchronous reset                          --
--                       LSCRESET -> LSC RRES (remote reset) command must be  --
--                       sent.                                                --
--                       LDOWN  -> Link down signal from control block.       --
--                       XOFF   -> Flow control signal from control block.    --
--                       DATA_IN-> Input data from FIFO. 34 bits.             --
--                                 DATA_IN(33) : Test flag                    --
--                                 DATA_IN(32) : Control flag                 --
--                                 DATA_IN(31 downto 0) : Data.               --
--                       EMPTY  -> FIFO empty flag                            --
--                                                                            --
--              Output : TX_CMD -> 3 bit command which controls the data      --
--                                 transmission functions: Data, Idle,Control --
--                                 word, Test and internal Commands. Meaning: --
--                                                                            --
--                          000 -> Data (block CRC calculates CRC)            --
--                          001 -> Test word (do nothing)                     --
--                          010 -> Control word (next block calculates parity)--
--                          011 -> CRC Checksum	                              --
--                          100 -> Send CRC internal command                  --
--                          101 -> Internal command                           --
--                          110 -> Reserved                                   --
--                          111 -> IDLE                                       --
--                                                                            --
--                        Do not confuse this output command, wich determines --
--                        actions to be taken by other blocks, with the       --
--                        internal commands used by the link. For instance,   --
--                        on starting a test cycle the output command in      --
--                        TX_CMD identifies data sent as internal command. The--
--                        internal command sent in that case will be TON.     --
--                        In the table below some examples of actions are     --
--                        shown:                                              --
--
--                      OUT_DATA-> 32-bit data, containing data, test or      --
--                                 control words,and the internal commands    --
--                                                                            --
--              3 IDLEs are sent after a control word or a block of data      --
--              After RLDN (remote link down)and RRES (remote reset) internal --
--              commands 7 IDLEs are sent, to help the receiver side lock to  --
--              the data                                                      --
--                                                                            --
--              When starting a test cycle, 7 IDLEs are sent after the TON    --
--              command, to give some extra time on reception to reset FIFO.  --
--------------------------------------------------------------------------------
--   Action     |   State    |  Next state(s)  |  output cmd  | Data output
--------------------------------------------------------------------------------
-- Link down    |   DOWN     |        -        | 7*CMD_IDLE + | 7 IDLES +     --
--              |            |                 |    CMD_IC    |   RLDN        --
-- Reset        | SEND_RESET |        -        | 7*CMD_IDLE + | 7 IDLES +     --
--              |            |                 |    CMD_IC    |   RRES        --
-- FIFO empty   |   IDLE     |        -        |   CMD_IDLE   |   Ignore      --
-- Data word    |   DATA     |      DATA       |   CMD_DATA   |  Data in      --
-- Max.         |  COMMAND   |                 |   CMD_CRC    |   CRCC        --
-- payload      |    CRC     |    SEQ_IDLE     |   CMD_CRCC   |   Ignore      --
--              |  SEQ_IDLE  |                 | 3*CMD_IDLE   |   Ignore      --
-- Data word    |   DATA     |      DATA       |   CMD_DATA   |  Data in      --
-- Ctrl. word   |  COMMAND   |                 |   CMD_CRC    |  CRCC         --
--              |    CRC     |    SEQ_IDLE     |   CMD_CRCC   |   Ignore      --
--              |  SEQ_IDLE  |     CONTROL     | 3*CMD_IDLE   |  3*Ignore     --
--              |            |                 |    CMD_IC    |    NCW        --
--              |  CONTROL   |    SEQ_IDLE     |   CMD_CW     |  Data in      --
--              |  SEQ_IDLE  |        -        | 3*CMD_IDLE   |   Ignore      --
-- Data word    |   DATA     |      DATA       |   CMD_DATA   |  Data in      --
-- Test         |  COMMAND   |                 |   CMD_CRC    |  CRCC         --
--              |    CRC     |    SEQ_IDLE     |   CMD_CRCC   |   Ignore      --
--              |  SEQ_IDLE  |    IDLE_TON     | 3*CMD_IDLE   |   Ignore      --
--              |            |                 |    CMD_IC    |     TON       --
--              |  IDLE_TON  |      TEST       | 7*CMD_IDLE   |   Ignore      --
--              |    TEST    |                 |   CMD_TEST   |  Data in      --
-- Test ends    |    TEST    |    SEQ_IDLE     |   CMD_IC     |    TOFF       --
--              |  SEQ_IDLE  |                 | 3*CMD_IDLE   |   Ignore      --
-- No action    |   IDLE     |        -        |   CMD_IDLE   |   Ignore      --
--------------------------------------------------------------------------------
--                                                                            --
-- Notes :  if the word following the idles, is to be an internal command then--
--          the third idle in sequence idle will contain the internal command --
--                                                                            --
--------------------------------------------------------------------------------
--                            Revision History                                --
--------------------------------------------------------------------------------
-- Version |   Mod.Date  |Author| Modifications                               --
--------------------------------------------------------------------------------
--  0.1    |  1-Nov-2001 |  ARG | First Version                               --
--  0.2    | 29-Nov-2001 |  ARG | LSCRESET level dependent, wait_state removed--
--  0.3    | 26-Feb-2002 |  ARG | 7 IDLEs sent after RRES and RLDN            --
--  0.4    | 11-Apr-2002 |  ARG | States COMMAND_NCW,COMMAND_TON,COMMAND_TOFF --
--         |             |      | removed                                     --
--  0.5    | 25-May-2002 |  ARG | shiftr counter removed, only idle_cnt_7 used--
--  0.6    |  3-Jun-2002 |  ARG | SEND_RESET_OFF state added                  --
--  0.7    | 14-Jun-2002 |  ARG | Code for TON changed (no code coincident    --
--         |             |      | with IDLE code)                             --
--  0.8    |  8-sep-2002 | JMH  | unnecessary registers removed for XOFF and  --
--         |             |      | the reset signals                           --
--  0.81   |  8-nov-2002 | JMH  | changing it to read from a non-show-ahead   --
--         |             |      | FIFO - change not done                      --
--  0.9    | 25-nov-2002 | JMH  | change complete the module now reads from a --
--         |             |      | non-show ahaed FIFO                         --
--         |             |      | this has meant an increase in logic used    --
--         |             |      | since insertion of internal commands before --
--         |             |      | certain words read from the fifo is more    --
--         |             |      | when the data isn't seen until after REN    --
--  1.0    | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity FRAMELSC is
--==============================================================================

  port(
    POWER_UP_RST_N : in std_logic;
  ICLK_2             : in  std_logic;                  -- 62.5 MHz clock
  RESET              : in  std_logic;                  -- synchronous reset
  LSCRESET           : in  std_logic;                  -- LSC reset request must
                                                       -- be sent
  LDOWN              : in  std_logic;                  -- ldown from control
  XOFF               : in  std_logic;                  -- flow control,ret.
                                                       -- channel
                                                       -- must be synchronised
  DATA_IN            : in  std_logic_vector(33 downto 0);-- data from FEMB
  EMPTY              : in  std_logic;                  -- empty flag;
  REN                : out std_logic;                  -- read enable
  OUT_DATA           : out std_logic_vector(31 downto 0);
  TX_CMD             : out std_logic_vector(2 downto 0)-- output command
   );

end FRAMELSC;


--==============================================================================
architecture behavioural of FRAMELSC is
--==============================================================================
type curr_states is (IDLE,DATA,CONTROL,SEQ_IDLE,TEST,CRC,SEND_RESET,DOWN,
                     IDLES_TON,SEND_RESET_OFF,DATA_XOFF,TEST_XOFF,INT_CMD_TOFF,TEST_IDLE,INT_CMD_CRC);
-- Output commands
CONSTANT CMD_DATA    : std_logic_vector(2 downto 0) := "000"; -- Normal Data
                                                              -- Word
CONSTANT CMD_TEST    : std_logic_vector(2 downto 0) := "001"; -- Test Word
CONSTANT CMD_CW      : std_logic_vector(2 downto 0) := "010"; -- Control Word
CONSTANT CMD_CRCC    : std_logic_vector(2 downto 0) := "011"; -- CRC Checksum
CONSTANT CMD_CRC     : std_logic_vector(2 downto 0) := "100"; -- Send CRC
                                                              -- int.cmd
CONSTANT CMD_IC      : std_logic_vector(2 downto 0) := "101"; -- Int. command
CONSTANT CMD_IDLE    : std_logic_vector(2 downto 0) := "111"; -- IDLE, ignore
                                                              -- data

-- Internal commands. MSB set to zero, and ignored in following blocks
CONSTANT RRES_OFF    : std_logic_vector(2 downto 0) := "000";
CONSTANT RRES        : std_logic_vector(2 downto 0) := "001";
CONSTANT CRCC        : std_logic_vector(2 downto 0) := "010";
CONSTANT NCW         : std_logic_vector(2 downto 0) := "011";
CONSTANT TON         : std_logic_vector(2 downto 0) := "101";
CONSTANT TOFF        : std_logic_vector(2 downto 0) := "100";
CONSTANT RLDN        : std_logic_vector(2 downto 0) := "110";

signal syn_flowct_i  : std_logic;                             -- Synchr. XOFF
signal cntclr        : std_logic;                             -- Frame length
                                                              -- counter clear
signal counten       : std_logic;                             -- Frame length
                                                              -- counter flag
signal sidle         : std_logic;                             -- IDLE counters
                                                              -- flag
signal out_cmd       : std_logic_vector( 2 downto 0);         -- Register for
                                                              -- output commands
signal idle_cnt_7    : std_logic_vector( 3 downto 0);         -- for 7 IDLEs
                                                              -- after
                                                              -- RLDN or RRES

signal curr_fr       : curr_states;
signal next_fr       : curr_states;
signal cnt           : std_logic_vector(10 downto 0);         -- Frame length
                                                              -- Counter. Bit 10
                                                              -- used as counter
                                                              -- flag-1024 words
signal out_data2     : std_logic_vector(31 downto 0);

signal reset_machine : std_logic;

-- for non show-ahead fifo

--FIFO read State machine constants
-- state machine states are dicrectly mapped to outputs
-- bit1 = REN
-- bit0 = tells the output statemachine that data is valid
CONSTANT NO_READ_NO_OUTPUT   : std_logic_vector(1 downto 0):= "00";
CONSTANT NO_READ_OUTPUT      : std_logic_vector(1 downto 0):= "01";
CONSTANT READ_NO_OUTPUT      : std_logic_vector(1 downto 0):= "10";
CONSTANT READ_OUTPUT         : std_logic_vector(1 downto 0):= "11";


--------------------------------------------------------------------------------
-- Signal declarations
--------------------------------------------------------------------------------

-- for non show-ahead fifo
--state variable for read state machine
signal FIFO_READ_STATE  : std_logic_vector(1 downto 0);  -- Current State

signal data_in_reg          : std_logic_vector(33 downto 0); -- valid data_in
signal kept_data            : std_logic_vector(33 downto 0); -- kept data_in_reg

signal kept_data_empty      : std_logic;   -- indicates that the kept_data
signal kept_data_empty_reg  : std_logic;   -- register is empty


signal ok_to_read           : std_logic;   -- fifo read statemachine can read
                                           -- from the fifo - if not empty

signal no_data              : std_logic;   -- indicates that data in data_in
                                           -- is invalid

signal data_in_reg_sent     : std_logic;   -- indicates that data in data_in_reg
signal data_in_reg_sent_reg : std_logic;   -- has been sent

signal crc_sent             : std_logic;   -- indicates that CRC checksum has
signal crc_sent_reg         : std_logic;   -- been sent

begin

--------------------------------------------------------------------------------
-- Signal XOFF coming from return channel, synchronised at RXCLK (typ. 40 MHz)
-- RESET and LSCRESET i synchronous with ICLK_2 from CONTROL module already
-- XOFF is also synchronous with ICLK_2 from RETCH module
--------------------------------------------------------------------------------
syn_flowct_i      <= xoff;
reset_machine     <= RESET or LSCRESET;


-- for non show-ahead fifo
--------------------------------------------------------------------------------
-- FIFO read State machine                                                    --
-- The block will be reading data if the FIFO is not empty and flow control   --
-- was not set by the user.                                                   --
-- in this case (the FRAMLSC) the flowcontrol is called ok_to_read and comes  --
-- from the "fr_machine" which uses it for both flowcontrol and for insertion --
-- og crc and internal commands                                               --
--------------------------------------------------------------------------------

FIFO_read_state_machine: process (ICLK_2)
begin
   if (ICLK_2'event and ICLK_2 = '1') then
      if (RESET = '1' or LSCRESET = '1' ) then
         FIFO_READ_STATE <= NO_READ_NO_OUTPUT;
      else
         case FIFO_READ_STATE is
            -- Dont read from FIFO - output is not valid
            when NO_READ_NO_OUTPUT =>
               if (ok_to_read = '1' and EMPTY = '0')then  -- after this cycle
                  FIFO_READ_STATE <= READ_NO_OUTPUT;      -- fifo is read but
               end if;                                    -- data is invalid

            -- Dont read from FIFO - Output is valid
            when NO_READ_OUTPUT    =>
               if (ok_to_read = '0' or EMPTY = '1')then   -- after this cycle
                  FIFO_READ_STATE <= NO_READ_NO_OUTPUT;   -- fifo is not read
               else                                       -- data is invalid
                  FIFO_READ_STATE <= READ_NO_OUTPUT;      -- after this cycle
               end if;                       -- fifo is read but data is invalid

            -- Read from FIFO - Output is not valid
            when READ_NO_OUTPUT    =>
               FIFO_READ_STATE <= READ_OUTPUT;            -- next words is valid

            -- Read from FIFO - Output is valid
            when READ_OUTPUT       =>
               if (EMPTY = '1')then                       -- after this cycle
                  FIFO_READ_STATE <= NO_READ_NO_OUTPUT;   -- fifo FIFO is empty
               elsif(ok_to_read = '0')then                -- after this cycle
                  FIFO_READ_STATE <= NO_READ_OUTPUT;      -- FIFO is not read
               end if;                                    -- next words is valid

            when others            =>
               FIFO_READ_STATE    <= NO_READ_NO_OUTPUT;
         end case;
      end if;
   end if;
end process;

REN                  <= FIFO_READ_STATE(1);
no_data              <= not FIFO_READ_STATE(0);

input_reg_process : process (ICLK_2)
begin
   if(ICLK_2'event and ICLK_2 = '1')then
      if (RESET = '1' or LSCRESET = '1' ) then
         data_in_reg <= (others => '0');
      elsif(no_data = '0')then
         data_in_reg <= DATA_IN;
      end if;
   end if;
end process;

--------------------------------------------------------------------------------
-- STATE MACHINE                                                              --
-- The state machine can be in one of the following modes:                    --
--    DOWN      : The block receives the notification from return channel that--
--                the link is down or in reset.                               --
--                It continuosly sends LINK DOWN internal command followed by --
--                7 IDLEs to help the receiver synchr., until a reset signal  --
--                is received.                                                --
--    IDLE      : In this state always when:                                  --
--                     - Reset high                                           --
--                     - FIFO empty                                           --
--                     - Recovery from LDOWN state                            --
--                Flow control is included in this state (and in SEQ_IDLE)    --
--                because otherwise data could be lost                        --
--    SEQ_IDLE  : 3 IDLES are sent between modes (data, control, test - also  --
--                when in the same mode). Example below.                      --
--    SEND_RESET: It continuously sends RRES (remote reset) internal commands,--
--                followed by 7 IDLEs (for synchronisation on the receiver    --
--                side), until the reset signal is removed                    --
--    DATA      : Data words are read from FIFO, and delivered at the output. --
--                They are continuosly transmitted until a payload of 1024    --
--                datawords (4 KBytes) was already sent (signal cnt),         --
--                or next word from FIFO is either control or test word       --
--                (flags in 34-bit FIFO word).                                --
--    DATA_XOFF : in this state the last words read from the FIFO will be sent--
--                after that it will proceed to IDLE                          --
--    CONTROL   : Control word is sent preceeded by the internal command NCW. --
--    IDLES_TON : this ste sends 7 idles before proceeding to TEST            --
--    TEST      : Test begins always with TON, finishes with TOFF internal    --
--                command. Meanwhile, test words are sent (like normal data)  --
--    TEST_XOFF : this state does the same as the DATA_XOFF but only doesn't  --
--                proceed to IDLE -> testmode has its own TEST_IDLE state     --
--    TEST_IDLE : since the testmode needs to send TOFF at the end of the     --
--                testmode, once in testmode only the states TEST, TEST_XOFF  --
--                and TEST_IDLE can be used, if the normal idle where used the--
--                read of a testword from the FIFO would mean that a TON cmd  --
--                was sent to the LDC. so therefore a seperate IDLE state for --
--                testmode                                                    --
--  INT_CMD_TOFF: sends the HOLA link internal command TOFF to the LDC, and   --
--                and saves the 1-2 words read from FIFO but wasn't sent      --
--  INT_CMD_CRC : before a control word or before entering testmode or if 4KB --
--                of data has been sent the CRC checksum must be sent         --
--                in this state, internal command "next word is CRC" is sent  --
--                and the data read out from the FIFO is saved until the CRC  --
--                has been sent                                               --
--    CRC       : One clock cycle to allowc CRC Checksum insertion            --
--                                                                            --
--                                                                            --
--------------------------------------------------------------------------------
--          IC          |        Command        |             Meaning
--------------------------------------------------------------------------------
--          000         |      No command       |                             --
--          001         |          RRES         |           Remote reset      --
--          010         |          CRCC         |         Next CRC Checksum   --
--          011         |          NCW          |         Next Control Word   --
--          101         |          TON          |          Test mode starts   --
--          111         |       Reserved        |                 -           --
--          100         |          TOFF         |          Test mode ends     --
--          110         |          RLDN         |             Link Down       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

fr_machine_state: process(ICLK_2, POWER_UP_RST_N)
begin
   if POWER_UP_RST_N = '0' then 
     curr_fr <= DOWN;
   elsif (ICLK_2'event and ICLK_2 = '1') then
     if ldown='1' then
       curr_fr                          <= DOWN;             -- link is down
     elsif reset_machine = '1' then
       curr_fr                          <= SEND_RESET;       -- synchr. reset
     else
       curr_fr                          <= next_fr;          -- normal mode
	 end if;
   end if;


end process fr_machine_state;

--------------------------------------------------------------------------------
-- State Machine                                                              --
--------------------------------------------------------------------------------

fr_machine: process(curr_fr, syn_flowct_i, cnt, idle_cnt_7,DATA_IN, crc_sent_reg,
          data_in_reg,kept_data,no_data,kept_data_empty_reg,data_in_reg_sent_reg)
begin

   case curr_fr is

      when DOWN              =>                              -- Link is down
         cntclr                           <= '1';
         counten                          <= '0';
         ok_to_read                       <= '0';            -- don't read FIFO
         crc_sent                         <= '1';
         if( idle_cnt_7(idle_cnt_7'high) = '1') then         -- if 7 IDLEs sent
            out_cmd                       <= CMD_IC;         -- send RLDN
            out_data2( 31 downto 3)       <= (others => '0');
            out_data2( 2 downto 0)        <= RLDN;
            sidle                         <= '0';            -- reset counter
         else                                                -- if not keep
            out_cmd                       <= CMD_IDLE;       -- sending IDLEs
            out_data2                     <= (others => '0');
            sidle                         <= '1';
         end if;
         kept_data_empty                  <= '1';            -- kept_data empty
         data_in_reg_sent                 <= '1';            -- data_in_reg sent
         next_fr                          <= IDLE;

      when IDLE               =>                             -- send IDLEs
         cntclr                           <= '0';            -- until word in
         counten                          <= '0';            -- FIFO
         sidle                            <= '0';
         kept_data_empty                  <= kept_data_empty_reg;
         data_in_reg_sent                 <= data_in_reg_sent_reg;
         crc_sent                         <= crc_sent_reg;
         if (no_data = '1') then                             --
            out_cmd                       <= CMD_IDLE;       -- no data
            out_data2                     <= data_in_reg( 31 downto 0);
            if(syn_flowct_i = '1')then
               ok_to_read                 <= '0';            --stop reading FIFO
            else
               ok_to_read                 <= '1';            -- read from FIFO
            end if;
            next_fr                       <= IDLE;           -- sending IDLEs
         elsif (data_in(33)='1') then                        -- Next test word
            if(crc_sent_reg = '1')then                       -- if CRC sent
               out_cmd                    <= CMD_IC;         -- send TON
               out_data2( 31 downto 3)    <= (others => '0');
               out_data2(2 downto 0)      <= TON;            -- internal cmd
               ok_to_read                 <= '0';            --stop reading FIFO
               next_fr                    <= IDLES_TON;      -- 7 IDLES
            else
               out_cmd                    <= CMD_IDLE;       -- if CRC not sent
               out_data2                  <= data_in_reg( 31 downto 0);
               ok_to_read                 <= '0';            --stop reading FIFO
               next_fr                    <= INT_CMD_CRC;    -- send it first
            end if;
         elsif (data_in(32)='1') then                        -- Data is control
            if(crc_sent_reg = '1')then
               out_cmd                    <= CMD_IC;         -- send NCW int.cmd
               out_data2( 31 downto 3)    <= (others => '0');
               out_data2( 2 downto 0)     <= NCW;            -- Next ctrl. word
               ok_to_read                 <= '0';            --stop reading FIFO
               next_fr                    <= CONTROL;        --next is ctrl word
            else
               out_cmd                    <= CMD_IDLE;       -- this fr. is idle
               out_data2                  <= data_in_reg( 31 downto 0);
               ok_to_read                 <= '0';
               next_fr                    <= INT_CMD_CRC;    --next is ctrl word
            end if;
         elsif (syn_flowct_i = '1') then                     -- Flow control
            out_cmd                       <= CMD_IDLE;       --this frame is idle
            out_data2                     <= data_in_reg( 31 downto 0);
            ok_to_read                    <= '0';            -- stop read
            next_fr                       <= DATA_XOFF;      -- next frame data
                                                             -- with XOFF
         else
            out_cmd                       <= CMD_IDLE;       --this frame is idle
            out_data2                     <= data_in_reg( 31 downto 0);
            ok_to_read                    <= '1';            -- ok to read
            next_fr                       <= DATA;           --next frame is Data
         end if;

      when SEQ_IDLE            =>                            -- Send 3 IDLEs
         cntclr                           <= '1';            -- after control
         counten                          <= '0';            -- or CRC
         kept_data_empty                  <= kept_data_empty_reg;
         data_in_reg_sent                 <= data_in_reg_sent_reg;
         crc_sent                         <= crc_sent_reg;

         if (idle_cnt_7((idle_cnt_7'high-2)) = '1') then     -- if 3 IDLEs sent
            if (kept_data_empty_reg = '0')then
               if (kept_data(33)='1') then                   -- test word
                  out_cmd                 <= CMD_IC;         -- internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2(2 downto 0)   <= TON;            -- send TON
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '0';            -- reset idle_cnt
                  next_fr                 <= IDLES_TON;      -- flow control
               elsif (kept_data(32)='1') then                -- ctrl. word
                  out_cmd                 <= CMD_IC;         -- internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2( 2 downto 0)  <= NCW;            -- Next ctrl. word
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '1';            -- enable idle_cnt
                  next_fr                 <= CONTROL;
               else
                  out_cmd                 <= CMD_IDLE;       --
                  out_data2               <= data_in_reg( 31 downto 0);
                  ok_to_read              <= '0';            --
                  sidle                   <= '1';            -- enable idle_cnt
                  next_fr                 <= DATA;           -- next normal data
               end if;
            elsif (data_in_reg_sent_reg = '0')then
               if (data_in_reg(33)='1') then                 -- test word
                  out_cmd                 <= CMD_IC;         -- internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2(2 downto 0)   <= TON;            -- send TON
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '0';            -- reset idle_cnt
                  next_fr                 <= IDLES_TON;      -- flow control
               elsif (data_in_reg(32)='1') then              -- ctrl. word
                  out_cmd                 <= CMD_IC;         -- internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2( 2 downto 0)  <= NCW;            -- Next ctrl. word
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '1';            -- enable idle_cnt
                  next_fr                 <= CONTROL;
               else
                 out_cmd                  <= CMD_IDLE;       --
                 out_data2                <= data_in_reg( 31 downto 0);
                 ok_to_read               <= '0';            --
                 sidle                    <= '1';            -- enable idle_cnt
                 next_fr                  <= DATA;           -- next normaldata
               end if;
            else
               if (no_data = '1') then                       -- FIFO empty
                  out_cmd                 <= CMD_IDLE;       -- or no data
                  out_data2               <= data_in_reg( 31 downto 0);
                  ok_to_read              <= '1';
                  sidle                   <= '1';            -- enable idle_cnt
                  next_fr                 <= IDLE;           -- sending IDLEs
               elsif  (data_in(33)='1') then                 -- test word
                  out_cmd                 <= CMD_IC;         -- internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2(2 downto 0)   <= TON;            -- send TON
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '0';            -- reset idle_cnt
                  next_fr                 <= IDLES_TON;      --
               elsif  (data_in(32)='1') then                 -- ctrl. word
                  out_cmd                 <= CMD_IC;         --internal command
                  out_data2( 31 downto 3) <= (others => '0');
                  out_data2( 2 downto 0)  <= NCW;            -- Next ctrl. word
                  ok_to_read              <= '0';            -- don't read FIFO
                  sidle                   <= '1';            -- enable idle_cnt
                  next_fr                 <= CONTROL;
               elsif (syn_flowct_i = '1') then               -- Flow control
                 out_cmd                  <= CMD_IDLE;       -- or no data
                 out_data2                <= data_in_reg( 31 downto 0);
                 ok_to_read               <= '0';            -- stop reading
                 sidle                    <= '1';            -- enable idle_cnt
                 next_fr                  <= DATA_XOFF;      -- next data_XOFF
               else
                 out_cmd                  <= CMD_IDLE;       -- or no data
                 out_data2                <= data_in_reg( 31 downto 0);
                 ok_to_read               <= '1';            --
                 sidle                    <= '1';            -- enable idle_cnt
                 next_fr                  <= DATA;           -- next normal data
               end if;
            end if;
         else
            out_cmd                       <= CMD_IDLE;       -- idle command
            out_data2                     <= data_in_reg( 31 downto 0);
            ok_to_read                    <= '0';            -- don't read FIFO
            sidle                         <= '1';            -- enable idle_cnt
            next_fr                       <= SEQ_IDLE;
         end if;

      when SEND_RESET         =>     --state entered on either URESET or LDC_reset
         cntclr                           <= '1';            -- clear datacount
         counten                          <= '0';            -- datacount. disab
         ok_to_read                       <= '0';            -- don't read FIFO
         kept_data_empty                  <= '1';            -- clear register
         data_in_reg_sent                 <= '1';            -- clear register
         crc_sent                         <= '1';            -- clear register
         if (idle_cnt_7(idle_cnt_7'high) = '1') then         -- if 7 IDLEs sent
            out_cmd                       <= CMD_IC;         -- internal command
            out_data2(31 downto 3)        <= (others => '0');
            out_data2( 2 downto 0)        <= RRES;           -- send RRES cmd.
            sidle                         <= '0';            -- reset idle_cnt
         else
            out_cmd                       <= CMD_IDLE;
            out_data2                     <= data_in_reg( 31 downto 0);
            sidle                         <= '1';            -- enable idle_cnt
         end if;
         next_fr                          <= SEND_RESET_OFF;

      when SEND_RESET_OFF     =>
         cntclr                           <= '1';            -- clear datacount
         counten                          <= '0';            -- datacount. disab
         ok_to_read                       <= '0';            -- don't read FIFO
         out_cmd                          <= CMD_IC;         -- internal command
         out_data2(31 downto 3)           <= (others => '0');
         out_data2( 2 downto 0)           <= RRES_OFF;       -- send RRES_OFF
         sidle                            <= '0';            -- disab. idle_cnt
         kept_data_empty                  <= kept_data_empty_reg;
         data_in_reg_sent                 <= data_in_reg_sent_reg;
         crc_sent                         <= crc_sent_reg;
         next_fr                          <= SEQ_IDLE;

      when IDLES_TON           =>                            -- send 7 IDLEs
         cntclr                           <= '1';            -- after TON cmd
         counten                          <= '0';
         ok_to_read                       <= '0';
         out_cmd                          <= CMD_IDLE;
         out_data2                        <= data_in_reg( 31 downto 0);
         crc_sent                         <= '1';
         if (kept_data_empty_reg = '0' or data_in_reg_sent_reg = '0')then
            kept_data_empty               <= kept_data_empty_reg;
            data_in_reg_sent              <= data_in_reg_sent_reg;
         elsif (no_data = '0') then
            kept_data_empty               <= '0';            -- keep data if any
            data_in_reg_sent              <= '0';
         else
            kept_data_empty               <= '1';            -- keep data if any
            data_in_reg_sent              <= '0';
         end if;
         if (idle_cnt_7(idle_cnt_7'high) = '1') then         -- if 7 IDLEs sent
            sidle                         <= '0';
            next_fr                       <= TEST;           -- next test begin
         else
            sidle                         <= '1';
            next_fr                       <= IDLES_TON;      -- more idles
         end if;

      when DATA               =>                             -- this fr. is data
         cntclr                           <= '0';
         sidle                            <= '0';            -- idle cnt disable
         out_cmd                          <= CMD_DATA;       -- this fr. is data
         crc_sent                         <= '0';            -- CRC not sent for
                                                             -- this data
         if (kept_data_empty_reg = '0')then                  -- send stored data
            out_data2                     <= kept_data( 31 downto 0);-- first
            data_in_reg_sent              <= data_in_reg_sent_reg;
            kept_data_empty               <= '1';            -- kept data sent
            if (data_in_reg_sent_reg = '0')then              -- send data_in_reg
               counten                    <= '1';            -- next
               if(data_in_reg(33)= '1' or data_in_reg(32)= '1')then
                  ok_to_read              <= '0';            -- don't read
                  next_fr                 <= INT_CMD_CRC;    -- send CRC
               else
                  ok_to_read              <= '1';            -- start reading
                  next_fr                 <= DATA;           -- next is data
               end if;
            elsif (no_data ='1') then                        -- next no data
               counten                    <= '1';            -- count
               ok_to_read                 <= '1';            --read if not empty
               next_fr                    <= IDLE;           -- next no data
            elsif (cnt(cnt'HIGH) ='1') then                  -- 4 KBytes sent
               counten                    <= '0';            -- stop counting
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_CRC;    -- send CRC
            elsif (data_in(33)= '1' or data_in(32) = '1') then
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_CRC;    -- send CRC
            elsif (syn_flowct_i ='1') then                   -- flow control,
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- don't read
               next_fr                    <= DATA_XOFF;      -- next data_XOFF
            else                                             -- normal data
               counten                    <= '1';            -- count
               out_data2                  <= kept_data(31 downto 0);
               ok_to_read                 <= '1';
               next_fr                    <= DATA;           --next normal data
            end if;
         elsif (data_in_reg_sent_reg = '0')then
            out_data2                     <= data_in_reg( 31 downto 0);
            data_in_reg_sent              <= '1';
            kept_data_empty               <= '1';
            if (no_data ='1') then                           -- next no data
               counten                    <= '1';            -- count
               ok_to_read                 <= '1';            -- read if any
               next_fr                    <= IDLE;           -- next no data
            elsif (cnt(cnt'HIGH) ='1') then                  -- 4 KBytes sent
               counten                    <= '0';            -- stop count
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_CRC;    -- send CRC
            elsif (data_in(33)= '1' or data_in(32) = '1') then
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_CRC;    -- send CRC
            elsif (syn_flowct_i ='1') then                   -- flow control,
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- don't read
               next_fr                    <= DATA_XOFF;      -- next data + XOFF
            else                                             -- normal data
               counten                    <= '1';            -- count
               ok_to_read                 <= '1';            -- keep reading
               next_fr                    <= DATA;           -- next normal data
            end if;
         else
            out_data2                     <= data_in_reg( 31 downto 0);
            data_in_reg_sent              <= '1';
            kept_data_empty               <= '1';
            if (no_data ='1') then                           -- next no data
               counten                    <= '1';            -- count
               ok_to_read                 <= '1';
               next_fr                    <= IDLE;           -- next no data
            elsif (cnt(cnt'HIGH) ='1') then                  -- 4 KBytes sent
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';
               next_fr                    <= INT_CMD_CRC;    -- send CRC
            elsif (data_in(33)= '1' or data_in(32) = '1') then
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_CRC;    -- send crc
            elsif (syn_flowct_i ='1') then                   -- flow control,
               counten                    <= '1';            -- count
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= DATA_XOFF;      -- next data + xoff
            else                                             -- normal data
               counten                    <= '1';            -- count
               ok_to_read                 <= '1';            -- keep reading
               next_fr                    <= DATA;           -- next normal data
            end if;
         end if;

      when INT_CMD_CRC  =>                                   -- internal command
         cntclr                           <= '0';            -- next word is CRC
         counten                          <= '0';            -- is sent between
         sidle                            <= '0';            -- data and control
         crc_sent                         <= '0';            -- and after 4KB
         out_cmd                          <= CMD_CRC;        -- send CRC
         out_data2( 31 downto 3)          <= (others => '0');
         out_data2( 2 downto 0)           <= CRCC;           -- next word CRC
         next_fr                          <= CRC;            -- next fr. CRC
         ok_to_read                       <= '0';
         kept_data_empty                  <= '0';            --word in kept_data
         if (no_data = '0') then
            data_in_reg_sent              <= '0';            --data_in_reg not sent
         else
            data_in_reg_sent              <= '1';            --data_in_reg sent
         end if;

      when DATA_XOFF          =>                             -- Xoff but still
         cntclr                           <= '0';            -- data read
         sidle                            <= '0';
         counten                          <= '1';            -- count data
         out_cmd                          <= CMD_DATA;
         out_data2                        <= data_in_reg( 31 downto 0);
         ok_to_read                       <= '0';            -- don't read more
         kept_data_empty                  <= kept_data_empty_reg;
         data_in_reg_sent                 <= data_in_reg_sent_reg;
         crc_sent                         <= crc_sent_reg;
         if (no_data ='1') then
            next_fr                       <= IDLE;
         elsif(data_in(33) = '1' or data_in(32) = '1')then
            next_fr                       <= INT_CMD_CRC;    --send CRC
         elsif (cnt(cnt'HIGH) ='1') then                     -- 4 KBytes sent
            next_fr                       <= INT_CMD_CRC;    --send CRC
         elsif( syn_flowct_i ='0' )then
            next_fr                       <= DATA;           --back to data
         else
            next_fr                       <= DATA_XOFF;      --stay
         end if;


      when TEST               =>
         cntclr                           <= '1';            -- clear data cnt
         counten                          <= '0';            -- don't count
         sidle                            <= '0';            -- clear idle cnt
         crc_sent                         <= '1';            -- no CRC in TEST
         out_cmd                          <= CMD_TEST;       -- this fr. is TEST
         if (kept_data_empty_reg = '0')then                  -- send stored data
            out_data2                     <= kept_data(31 downto 0); -- first
            kept_data_empty               <= '1';
            data_in_reg_sent              <= data_in_reg_sent_reg;
            if (data_in_reg_sent_reg = '0')then
               ok_to_read                 <= '1';            -- start reading
               next_fr                    <= TEST;           -- next test
            elsif (no_data ='1') then                        -- next no data
               ok_to_read                 <= '1';            -- read
               next_fr                    <= TEST_IDLE;      -- next no data
            elsif (data_in(33)='0') then                     -- test mode ends
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_TOFF;   -- next TOFF
            elsif( syn_flowct_i = '1' )then                  -- XOFF
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= TEST_XOFF;      -- next TEST + XOFF
            else
               ok_to_read                 <= '1';            -- just proceed
               next_fr                    <= TEST;           -- next is test
            end if;
         elsif (data_in_reg_sent_reg = '0')then              -- data not sent
            out_data2                     <= data_in_reg(31 downto 0);-- send it
            data_in_reg_sent              <= '1';
            kept_data_empty               <= '1';
            if ( no_data = '1')then                          -- next no data
               ok_to_read                 <= '1';            -- start reading
               next_fr                    <= TEST_IDLE;      -- next no data
            elsif (data_in(33)='0') then                     -- test mode ends
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_TOFF;   -- next TOFF
            elsif( syn_flowct_i = '1' )then                  -- XOFF
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= TEST_XOFF;      -- next TEST + XOFF
            else
               ok_to_read                 <= '1';            -- just proceed
               next_fr                    <= TEST;           -- next normal TEST
            end if;
         else                                                -- normal test
            out_data2                     <= data_in_reg(31 downto 0);
            kept_data_empty               <= '1';
            data_in_reg_sent              <= '1';
            if ( no_data = '1')then                          -- next no data
               ok_to_read                 <= '1';            -- start reading
               next_fr                    <= TEST_IDLE;      -- next no data
            elsif (data_in(33)='0') then                     -- test mode ends
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= INT_CMD_TOFF;   -- next TOFF
            elsif( syn_flowct_i = '1' )then                  -- XOFF
               ok_to_read                 <= '0';            -- stop reading
               next_fr                    <= TEST_XOFF;      -- next TEST + XOFF
            else
               ok_to_read                 <= '1';            -- just proceed
               next_fr                    <= TEST;           -- next normal data
            end if;
         end if;

      when TEST_IDLE       =>
         sidle                            <= '0';            -- clear idle cnt
         cntclr                           <= '1';            -- clear data cnt
         counten                          <= '0';            -- data cnt disable
         kept_data_empty                  <= '1';            -- no data saved
         data_in_reg_sent                 <= '1';            -- no data saved
         crc_sent                         <= '1';            -- CRC not in TEST
         out_cmd                          <= CMD_IDLE;       -- this fr. is idle
         out_data2                        <= data_in_reg(31 downto 0);
         if (no_data = '1')then
            if(syn_flowct_i = '1')then
               ok_to_read                 <= '0';            -- don't read
            else
               ok_to_read                 <= '1';            -- start reading
            end if;
            next_fr                       <= TEST_IDLE;      -- next is IDLE
         elsif(data_in(33)='0') then                         -- test mode ends
            ok_to_read                    <= '0';            -- stop reading
            next_fr                       <= INT_CMD_TOFF;   -- next TOFF
         elsif( syn_flowct_i = '1' )then                     -- XOFF
            ok_to_read                    <= '0';            -- stop reading
            next_fr                       <= TEST_XOFF;      -- next TEST + XOFF
         else
            ok_to_read                    <= '1';            -- just proceed
            next_fr                       <= TEST;           -- next normal test
         end if;

      when TEST_XOFF       =>
         cntclr                           <= '1';            -- clear data cnt
         counten                          <= '0';            -- disable data cnt
         sidle                            <= '0';            -- clear idle cnt
         crc_sent                         <= '1';            -- no CRC in test
         ok_to_read                       <= '0';            -- don't read
         out_cmd                          <= CMD_TEST;       -- this fr. is TEST
         out_data2                        <= data_in_reg(31 downto 0);
         kept_data_empty                  <= '1';            -- no saved data
         data_in_reg_sent                 <= '1';            -- no saved data
         if (no_data ='1')then                               -- next no data
            next_fr                       <= TEST_IDLE;      -- next idle
         else                                                -- still one data
            next_fr                       <= TEST_XOFF;      -- next TEST + XOFF
         end if;

      when INT_CMD_TOFF    =>                                -- TOFF
         out_cmd                          <= CMD_IC;         -- internal command
         out_data2(31 downto 3)           <= (others => '0');-- clear MSB
         out_data2( 2 downto 0)           <= TOFF;           -- "test off"
         ok_to_read                       <= '0';            -- don't read
         crc_sent                         <= '1';            -- no CRC in test
         sidle                            <= '0';            -- clear idle cnt
         cntclr                           <= '1';            -- clear data cnt
         counten                          <= '0';            -- disbale dat cnt
         kept_data_empty                  <= '0';            -- save data
         if (no_data = '0') then                             -- next data
            data_in_reg_sent              <= '0';            -- save next to
         else                                                -- next no data
            data_in_reg_sent              <= '1';            -- don't save next
         end if;
         next_fr                          <= SEQ_IDLE;       -- next 3 idles

      when CONTROL             =>
         cntclr                           <= '1';            -- clear data cnt
         counten                          <= '0';            -- disable data cnt
         crc_sent                         <= crc_sent_reg;   -- keep value
         kept_data_empty                  <= '1';            -- kept data read
         sidle                            <= '0';            -- clear idle cnt
         out_cmd                          <= CMD_CW;         -- this fr. is CTRL
         ok_to_read                       <= '0';            -- don't read
         if (kept_data_empty_reg = '0')then                  -- CTRL word is in
            out_data2                     <= kept_data( 31 downto 0);--kept_data
            data_in_reg_sent              <= data_in_reg_sent_reg; -- keep value
         else                                                -- CTRL word is in
            out_data2                     <= data_in_reg( 31 downto 0);-- data_in_reg
            data_in_reg_sent              <= '1';
         end if;
         if (no_data = '0') then                             --data_in has valid
            data_in_reg_sent              <= '0';            -- data, data will
         end if;                                             --be in data_in_reg
                                                             -- next
         next_fr                          <= SEQ_IDLE;       -- send 3 IDLEs

      when CRC                  =>                           -- one cycle to
         cntclr                           <= '1';            -- allow the CRC
         out_cmd                          <= CMD_CRCC;       -- Checksum
         counten                          <= '0';            -- insertion
         out_data2                        <= data_in_reg( 31 downto 0);
         crc_sent                         <= '1';            -- CRC is now sent
         ok_to_read                       <= '0';            -- don't read
         sidle                            <= '0';            -- clear idle cnt
         kept_data_empty                  <= kept_data_empty_reg;-- keep values
         data_in_reg_sent                 <= data_in_reg_sent_reg;
         next_fr                          <= SEQ_IDLE;       -- next 3 idles

      when OTHERS               =>
-- In others statement assign 'X' to avoid mismatches between
-- simulation of pre- and post-synthesis versions of the code
--(AN 226, pg 13)
         kept_data_empty                  <= 'X';
         data_in_reg_sent                 <= 'X';
         crc_sent                         <= 'X';
         cntclr                           <= 'X';
         counten                          <= 'X';
         out_cmd                          <= "XXX";
         out_data2                        <= (others => 'X');
         ok_to_read                       <= 'X';
         sidle                            <= '0';
         next_fr                          <= DOWN;           -- default down
    end case;

end process fr_machine;


--------------------------------------------------------------------------------
-- FRAME LENGTH COUNTER                                                       --
-- Maximum payload 1024 data words (4 KBytes)                                 --
--------------------------------------------------------------------------------

frcnt: process (iclk_2,counten)
begin
   if (iclk_2'event and iclk_2='1') then
      if (cntclr='1') then                                   --synchronous reset
         cnt                          <= (0 => '1', others=>'0');--starts at 1
      elsif (counten= '1') then
         cnt                          <= cnt + '1';          -- cnt(10) high
      end if;                                                -- after 1024 word
  end if;
end process frcnt;


--------------------------------------------------------------------------------
-- 7 IDLEs counter (sent after RRES or RLDN commands)                         --
-- also used when 3 idles needed                                              --
--------------------------------------------------------------------------------

--shiftreg_7: process
--begin
--   wait until ICLK_2'event and ICLK_2 = '1';
--      if (sidle = '0') then                                -- reset
--         idle_cnt_7                   <= ( others => '0');
--      else
--         idle_cnt_7                   <= idle_cnt_7 + 1;
--      end if;
--end process;

-- purpose: 7 idles counter
-- type   : sequential
-- inputs : ICLK_2, POWER_UP_RST_N, sidle
-- outputs: idle_cnt_7
shiftreg_7: process (ICLK_2, POWER_UP_RST_N)
begin  -- process shiftreg_7
  if POWER_UP_RST_N = '0' then          -- asynchronous reset (active low)
         idle_cnt_7                   <= ( others => '0');
  elsif ICLK_2'event and ICLK_2 = '1' then  -- rising clock edge
      if (sidle = '0') then                                -- reset
         idle_cnt_7                   <= ( others => '0');
      else
         idle_cnt_7                   <= idle_cnt_7 + 1;
      end if;
  end if;
end process shiftreg_7;
--------------------------------------------------------------------------------
-- keep register - will save data if "kept_data_empty" is set low             --
--------------------------------------------------------------------------------
kept_data_register: process
begin
   wait until ICLK_2'event and ICLK_2 = '1';
   if (reset_machine = '1')then
      kept_data <= (others => '0');
   elsif(kept_data_empty ='0' and kept_data_empty_reg = '1')then
      kept_data <= data_in_reg;
   end if;
end process;


registers: process
begin
   wait until ICLK_2'event and ICLK_2 = '1';
      data_in_reg_sent_reg              <= data_in_reg_sent;
      kept_data_empty_reg               <= kept_data_empty;
      crc_sent_reg                      <= crc_sent;

      TX_CMD                          <= out_cmd;          -- output command
      OUT_DATA                        <= out_data2;        -- output data
end process;


end behavioural;
--------------------------------------------------------------------------------
-- END OF ARCHITECTURE
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : reglsc.vhd                                                   --
--                                                                            --
-- Title       : Input Register                                               --
--                                                                            --
-- Author      : Aurelio Ruiz                                                 --
--                                                                            --
-- Description : Input synchronization.                                       --
--               The purpose is to synchronise asynchronous inputs, or to     --
--               register the inputs (for operating on them)                  --
--                                                                            --
--               If inputs are not registered, IO register from Altera device --
--               cannot be used.                                              --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
--     Version     |    Date     |  Author  | Modifications                   --
--------------------------------------------------------------------------------
--       0.1       | 29-Nov-2001 |   ARG    | First Version                   --
--       0.2       | 04-sep-2002 |   JMH    | Double register added to prevent--
--                 |             |          | Metastability issues.           --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--------------------------------------------------------------------------------
entity REGLSC is
--------------------------------------------------------------------------------

port(
  UCLK       : in   std_logic;                              -- S-Link clock
  ICLK_2     : in   std_logic;                              -- 62.5 MHz
  UTEST_N    : in   std_logic;                              -- Asynchr.
  UCTRL_N    : in   std_logic;                              -- Synchr. with UCLK
  UWEN_N     : in   std_logic;                              -- Synchr. with UCLK
  URESET_N   : in   std_logic;                              -- Asynchr.
  UD         : in   std_logic_vector(31 downto 0);          -- Synchr. with UCLK
  UTEST_U    : out  std_logic;
  UCTRL_N_U  : out  std_logic;
  UWEN_N_U   : out  std_logic;
  UTEST_N_I  : out  std_logic;
  URESET_N_I : out  std_logic;
  UD_U       : out  std_logic_vector(31 downto 0)
);

end REGLSC;



--------------------------------------------------------------------------------
architecture behaviour of REGLSC is
--------------------------------------------------------------------------------
signal utest_u_1    : std_logic;

signal utest_n_i_1  : std_logic;
signal ureset_n_i_1 : std_logic;


--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SYNCHRONISATION STAGES                                                     --
-- Signals synchronised to UCLK                                               --
-- Signal UCTRL_N registered in order to allow operations on it (I/O          --
--       registers otherwise not implemented).                                --
-- Data input must be synchronised as well, otherwise control flag delayed.   --
-- to prevent Metastability issues all no UCLK signals are registered twice   --
--------------------------------------------------------------------------------

sync_uclk: process
begin
   wait until UCLK'event and UCLK = '1';
     utest_u_1      <= UTEST_N;
     UTEST_U        <= utest_u_1;

     UCTRL_N_U      <= UCTRL_N;

     UWEN_N_U       <=  UWEN_N;

     UD_U           <= UD;

end process sync_uclk;


--------------------------------------------------------------------------------
-- Signals synchronised to ICLK_2
--------------------------------------------------------------------------------

sync_iclk2: process
begin
   wait until ICLK_2'event and ICLK_2 = '1';

     ureset_n_i_1   <= URESET_N;
     URESET_N_I     <= ureset_n_i_1;

     utest_n_i_1    <= UTEST_N;
     UTEST_N_I      <= utest_n_i_1;
end process sync_iclk2;


end behaviour;


--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : paritylsc.vhd                                                 --
--                                                                            --
-- Authors    : Aurelio Ruiz Garcia, CERN EP Division                         --
--                                                                            --
-- Description: Even parity is generated on each ctrl word on the bits:       --
--                Tx(0) for data(10.. 4), Tx(1) for data(17..11)              --
--                Tx(2) for data(24..18), Tx(3) for data(31..25)              --
-- Input cmd  :3 bit command which controls the data transmission             --
--             functions: Data, Idle,Control word, Test and internal          --
--             Commands, and the 32-bit when necessary. Meaning:              --
--                                                                            --
--                    000 -> Data (block CRC calculates CRC)                  --
--                    001 -> Test word                                        --
--                    010 -> Control word (next block calculates parity)      --
--                    011 -> CRC Checksum                                     --
--                    100 -> Send CRC                                         --
--                    101 -> Internal command                                 --
--                    110 -> Reserved                                         --
--                    111 -> Ignore data                                      --
--                                                                            --
-- Notes      : Based on parity.vhd (ODIN implementation)                     --
--              by Zoltan Meggyesi and Erik van der Bij                       --
--                                                                            --
--              Creates a two register pipeline delay:                        --
--                                                                            --
--                 outputs are directly from registers                        --
--                                                                            --
--              Check if input register is necessary                          --
--------------------------------------------------------------------------------
--                            Revision History                                --
--------------------------------------------------------------------------------
-- Version |   Mod.Date   | Author |    Modifications                         --
--------------------------------------------------------------------------------
--   1.0   | 14.Nov.2001  |  ARG   | Original Version                         --
--   1.1   |  5.sep.2002  |  JMH   | output register added, input reg removed --
--   1.2   | 12-may-2003  | JMH    | added POWER_UP_RST_N                     --
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity paritylsc is
--==============================================================================

--------------------------------------------------------------------------------
-- Even parity generated on each control word. On reception they must be checked
-- and removed from the word (S-Link specification)
--------------------------------------------------------------------------------

  port (

    POWER_UP_RST_N : in  std_logic;
    ICLK_2         : in  std_logic;     -- 62.5 MHz
    DATA           : in  std_logic_vector(31 downto 0);
    CMDIN          : in  std_logic_vector(2 downto 0);
    OUT_DATA       : out std_logic_vector(31 downto 0);
    TX_CMD         : out std_logic_vector(2 downto 0)
    );

end paritylsc;

--==============================================================================
--==============================================================================
--------------------------------------------------------------------------------
-- END OF ENTITY
--------------------------------------------------------------------------------
--==============================================================================
--==============================================================================


--==============================================================================
architecture behavioural of paritylsc is
--==============================================================================
  constant CW : std_logic_vector(2 downto 0) := "010";  -- Control Word

  signal indata : std_logic_vector(31 downto 0);
  signal oreg   : std_logic_vector(31 downto 0);  -- output register

  signal incmd  : std_logic_vector( 2 downto 0);
  signal outcmd : std_logic_vector( 2 downto 0);  -- output register


begin

  indata <= data;
  incmd  <= cmdin;


--------------------------------------------------------------------------------
-- PARITY Calculater
-- If cmdin = '010' -> calculate parity, add to word and set tx_cmd = '010'
-- Otherwise, just go on sending tx_cmd = cmdin
--------------------------------------------------------------------------------

  parity_calc : process (ICLK_2, POWER_UP_RST_N)
    variable oreg_var : std_logic_vector(3 downto 0);
  begin
    if(POWER_UP_RST_N = '0')then
      oreg   <= (others => '0');
      outcmd <= (others => '1');
      
    elsif (ICLK_2'event and ICLK_2 = '1') then
      oreg(31 downto 4) <= indata(31 downto 4);
      outcmd            <= incmd;
      oreg_var          := "0000";

      for i in 6 downto 0 loop
        oreg_var(0) := oreg_var(0) xor indata( 4 + i);  -- Parity
        oreg_var(1) := oreg_var(1) xor indata(11 + i);  -- calculation
        oreg_var(2) := oreg_var(2) xor indata(18 + i);
        oreg_var(3) := oreg_var(3) xor indata(25 + i);
      end loop;

      case incmd is

        when CW =>                      -- Control word is being transmitted
          oreg(3 downto 0) <= oreg_var;

        when others =>                  -- Data word, do not generate parity
          oreg(3 downto 0) <= indata(3 downto 0);

      end case;

    end if;

  end process parity_calc;

--------------------------------------------------------------------------------
-- OUTPUT REGISTER
--------------------------------------------------------------------------------

  outr : process
  begin
    wait until ICLK_2'event and ICLK_2 = '1';
      out_data <= oreg;                 -- Connect outputs
      tx_cmd   <= outcmd;
  
  end process outr;
end behavioural;

--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : crcgen.vhd                                                   --
--                                                                            --
-- Author      : Erik Brandin, CERN, EP-Division                              --
--                                                                            --
-- Description : A 16 bit CRC with 16 bit look-ahead. Uses the CRC-CCITT      --
--               polynomial x^16+x^12+x^5+1                                   --
--               To increase speed the CRC calculation is split into two clock--
--               cycles. The first cycle only the part that includes the data --
--               is XORed into signal q1, and at the next cycle this result is--
--               XORed with the previous state of the CRC, q0.                --
--               With this wcheme the maximum frequency is greatly increased  --
--               since the numbers of XOR gates on one signal is reduces from --
--               15 to 8.                                                     --
--                                                                            --
--               For an HOLA link:                                            --
--               The transmitter should use the entity CRCLSC which has an    --
--               output multiplexer to insert the CRCC.                       --
--                                                                            --
--               The receiver should use the entity CRCLDC which has a ERROR  --
--               output that is active high with a latency of two clockcycles --
--                                                                            --
--               Both these entities uses CRCGEN generate CRC or calculate    --
--               ERROR state.                                                 --
--                                                                            --
-- Notes       :                                                              --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
-- Version |    Date     |Author| Modifications                               --
--------------------------------------------------------------------------------
--   1.0   | 22-Jul-99   | EB   | Original version                            --
--   1.1   |  9-Apr-02   | ARG  | Comments added                              --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--------------------------------------------------------------------------------
entity CRCGEN is
--------------------------------------------------------------------------------
  port (
    CLK   : in  std_logic;                         -- Input clock
    CLRCRC: in  std_logic;                         -- Synchronous clear active
                                                   -- high. A Clear signal has
                                                   -- to be asserted before or
                                                   -- the same cycle the first
                                                   -- data word is written 
    CALC  : in  std_logic;                         -- Calculate CRC on DIN
    D     : in  std_logic_vector (15 downto 0);    -- Data Input
    Q     : out std_logic_vector (15 downto 0)     -- CRC quotient. One clock
                                                   -- cycle latancy from last
                                                   -- word in to CRC out.

	);
end CRCGEN;

--------------------------------------------------------------------------------
architecture behaviour of CRCGEN is
--------------------------------------------------------------------------------

signal q0     : std_logic_vector (15 downto 0); -- Internal quotient signal
signal q1     : std_logic_vector (15 downto 0); -- Partial CRC quotient
signal nxt    : std_logic;                      -- If high, q1 contains
                                                -- partial CRC
signal nxt_clr: std_logic_vector (1 downto 0);  -- signal used to append nxt and
                                                -- clr for case statement

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------

  Q          <= q0;
  nxt_clr(1) <= nxt;
  nxt_clr(0) <= CLRCRC;
  
--------------------------------------------------------------------------------
-- CRC1 calculates the part of the CRC only containing the data, and store the
-- intermediate result in q1. This calculation is down even when no data is
-- avilable. If CALC = '0' q1 will not be used.

crc1: process(CLK)
begin
  if (CLK'event and CLK = '1') then

    q1(15) <= D(12) xor D(11) xor D(8)  xor D(4)  xor D(0);
    q1(14) <= D(13) xor D(12) xor D(9)  xor D(5)  xor D(1);
    q1(13) <= D(14) xor D(13) xor D(10) xor D(6)  xor D(2);
    q1(12) <= D(15) xor D(14) xor D(11) xor D(7)  xor D(3);
    q1(11) <= D(15) xor D(12) xor D(8)  xor D(4);
    q1(10) <= D(13) xor D(12) xor D(11) xor D(9)  xor D(8) xor D(5) xor
                        D(4)  xor D(0);
    q1(9)  <= D(14) xor D(13) xor D(12) xor D(10) xor D(9) xor D(6)  xor
                        D(5)  xor D(1);
    q1(8)  <= D(15) xor D(14) xor D(13) xor D(11) xor D(10) xor D(7)  xor
                        D(6)  xor D(2);
    q1(7)  <= D(15) xor D(14) xor D(12) xor D(11) xor D(8) xor D(7)  xor
                        D(3);
    q1(6)  <= D(15) xor D(13) xor D(12) xor D(9)  xor D(8) xor D(4);
    q1(5)  <= D(14) xor D(13) xor D(10) xor D(9)  xor D(5);
    q1(4)  <= D(15) xor D(14) xor D(11) xor D(10) xor D(6);
    q1(3)  <= D(15) xor D(8)  xor D(7)  xor D(4)  xor D(0);
    q1(2)  <= D(9)  xor D(8)  xor D(5)  xor D(1);
    q1(1)  <= D(10) xor D(9)  xor D(6)  xor D(2);
    q1(0)  <= D(11) xor D(10) xor D(7)  xor D(3); 
    nxt <= CALC;

  end if;
end process crc1;

--------------------------------------------------------------------------------
-- CRC0 calculates the part of the CRC that uses the previous value of the CRC.
--
-- the following cases are possible
-- 
-- nxt | CLRCRC |Meaning                    |Action
-------+--------+---------------------------+-----------------------------------
--  1  |        |data written previos cycle |Calculate CRC (q0) using previous
--     |  0     |no reset signal            |value of q0 and q1
-------+--------+---------------------------+-----------------------------------
--  1  |        |Data written               |Calculate CRC using previous q1 and
--     |  1     |Reset signal active        |a reduced calculation being equal
--     |        |                           |to q0 being all 1.
-------+--------+---------------------------+-----------------------------------
--  0  |        |No data written            |q0 is unchanged
--     |  0     |No resetr signal           |
-------+--------+---------------------------+-----------------------------------
--  0  |        |No data written            |Reset CRC calculator by presetting
--     |  1     |Reset signal active        |q0 to all 1.
-------+--------+---------------------------+-----------------------------------
-- 
-- The second of the above cases is the most complicated: 
-- To clear previous result without having to preset q to all 1, one can
-- do this by performing q <= q1 xor #F0B8, which is equal to presetting
-- q to all 1 in the previous cycle.
-- This is needed in the following case in the receiver:
--
-- Clock cycle | Input | q0     | q1
---------------+-------+--------+--------
--      1      | Data  | -      | -  
--      2      | Data  | -      | q1_1
--      3      | -     | q0_1   | q1_2
--      4      | CRC   | q0_2   | -
--      5      | Data  | q0_2   | q1_crc
--      6      | Data  | q0_crc | q1_5
--      7      | Data  | q0_5   | q1_6
-- 
-- where qx_y indicates the value of the qx register containing CRC data from
-- beginning of CRC block to clock cycle y. The problem arises when a new CRC
-- block starts on the clock cycle after a CRC is sent. There is no time to
-- preset q0 register to all 1, so this is emulated bu calulating what the
-- effect would be. The operations below is merely the same operations as the
-- one above with q0 registers set to all 1.

crc0:process(CLK)
begin
  if (CLK'event and CLK ='1') then

    case nxt_clr is

      when "10" =>
        q0(15) <= q1(15) xor q0(15) xor q0(11) xor q0(7)  xor q0(4) xor q0(3);
        q0(14) <= q1(14) xor q0(14) xor q0(10) xor q0(6)  xor q0(3) xor q0(2);
        q0(13) <= q1(13) xor q0(13) xor q0(9)  xor q0(5)  xor q0(2) xor q0(1);
        q0(12) <= q1(12) xor q0(12) xor q0(8)  xor q0(4)  xor q0(1) xor q0(0);
        q0(11) <= q1(11) xor q0(11) xor q0(7)  xor q0(3)  xor q0(0);
        q0(10) <= q1(10) xor q0(15) xor q0(11) xor q0(10) xor q0(7) xor q0(6)
                         xor q0(4)  xor q0(3)  xor q0(2);
        q0(9)  <= q1(9)  xor q0(14) xor q0(10) xor q0(9)  xor q0(6) xor q0(5)
                         xor q0(3)  xor q0(2)  xor q0(1);
        q0(8)  <= q1(8)  xor q0(13) xor q0(9)  xor q0(8)  xor q0(5) xor q0(4)
                         xor q0(2)  xor q0(1)  xor q0(0);
        q0(7)  <= q1(7)  xor q0(12) xor q0(8)  xor q0(7)  xor q0(4) xor q0(3)
                         xor q0(1)  xor q0(0);
        q0(6)  <= q1(6)  xor q0(11) xor q0(7)  xor q0(6)  xor q0(3) xor q0(2)
                         xor q0(0);
        q0(5)  <= q1(5)  xor q0(10) xor q0(6)  xor q0(5)  xor q0(2) xor q0(1);
        q0(4)  <= q1(4)  xor q0(9)  xor q0(5)  xor q0(4)  xor q0(1) xor q0(0);
        q0(3)  <= q1(3)  xor q0(15) xor q0(11) xor q0(8)  xor q0(7) xor q0(0);
        q0(2)  <= q1(2)  xor q0(14) xor q0(10) xor q0(7)  xor q0(6);
        q0(1)  <= q1(1)  xor q0(13) xor q0(9)  xor q0(6)  xor q0(5);
        q0(0)  <= q1(0)  xor q0(12) xor q0(8)  xor q0(5)  xor q0(4);

      when "11" =>
        q0(15) <= not q1(15);
        q0(14) <= not q1(14);
        q0(13) <= not q1(13);
        q0(12) <= not q1(12);
        q0(11) <= q1(11);
        q0(10) <= q1(10);
        q0(9)  <= q1(9);
        q0(8)  <= q1(8);
        q0(7)  <= not q1(7);
        q0(6)  <= q1(6);
        q0(5)  <= not q1(5);
        q0(4)  <= not q1(4);
        q0(3)  <= not q1(3);
        q0(2)  <= q1(2);
        q0(1)  <= q1(1);
        q0(0)  <= q1(0);

      when "00" =>
        q0 <= q0;

      when others =>
        q0 <= (others => '1');
    end case;

  end if;

end process crc0;

--------------------------------------------------------------------------------
end behaviour;
--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------

--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : crclsc.vhd                                                   --
--                                                                            --
-- Authors     : Aurelio Ruiz    , CERN, EP-Division                          --
--               Erik van der Bij, CERN, EP-Division                          --
--                                                                            --
-- Description : CRC Checksum generator for 32-bit words, using two           --
--               independent 16 bit CRC 16 bit look-ahead calculators which   --
--               use the polynomial implemented in the entity CRCGEN.         -- 
--                                                                            --
--               The CRCTX monitors the input signals and calculates CRC      --
--               only on valid data in OUT_DATA.                              --
--                                                                            --
--               The latency is one clock cycle, in which a control word      --
--               is sent (bit 0 and 1 asserted) to signal to the LDC that the --
--               the next cycles contains the CRCC.                           --
--                                                                            --
--               The cycle where the CRCC is inserted cannot be used to send  --
--               any data through OUT_DATA.                                   --
--                                                                            --
-- Input command:3 bit command which controls the data transmission           --
--               functions: Data, Idle,Control word, Test and internal        -- 
--               Commands, and the 32-bit when necessary. Meaning:            --
--                                                                            --
--                    000 -> Data (block CRC calculates CRC)                  --
--                    001 -> Test word                                        --
--                    010 -> Control word (next block calculates parity)      --
--                    011 -> CRC Checksum	                              --
--                    100 -> Send CRC                                         --
--                    101 -> Internal command                                 --
--                    110 -> Reserved                                         -- 
--                    111 -> Ignore data                                      --
--                                                                            --
-- Size        : Estimated 171 LEs (14%)                                      --
--                                                                            --
-- Notes       : Based on crctx.vhd (ODIN implementation)                     --
--               by Erik Brandin and Erik van der Bij                         --
--                                                                            --
--               If, for some reason, another CRC polynomial is to be used,   --
--               only the entity CRCGEN has to be modified.                   --
--               IC command 101 for CRC Checksum must be added in framing     --
--               block                                                        --     
--                                                                            --
-- Used files  : crcgen.vhd                                                   --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
-- Version |    Date      |Author | Modifications                             --
--------------------------------------------------------------------------------
--   0.1   | 24-Oct-2001  | ARG   | Original Version                          --
--   0.2   | 15-Apr-2002  | ARG   | CRCGEN mapping changed                    --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity CRCLSC is
--==============================================================================
 
port (
  ICLK_2       : in  std_logic;                          -- clock 62.5 MHz
  RESET        : in  std_logic;                          -- reset request   
  DATA         : in  std_logic_vector(31 downto 0);             
  CMD_IN       : in  std_logic_vector( 2 downto 0);                                    
  OUT_CMD      : out std_logic_vector( 2 downto 0);
  OUT_DATA     : out std_logic_vector(31 downto 0)
   );

end CRCLSC;


--==============================================================================
architecture behaviour of CRCLSC is
--==============================================================================

--------------------------------------------------------------------------------
-- Component declarations
--------------------------------------------------------------------------------

component CRCGEN
  port (
    CLK       : in  std_logic;
    CLRCRC    : in  std_logic;
    CALC      : in  std_logic;
    D         : in  std_logic_vector (15 downto 0);
    Q         : out std_logic_vector (15 downto 0)
    );
end component;

--------------------------------------------------------------------------------
-- Signal declarations                                                        --
--------------------------------------------------------------------------------

  signal rst          : std_logic;                        -- Reset to crcgen 
  signal crc_f        : std_logic_vector(31 downto 0);
  signal clr_reg      : std_logic;                        -- Clear register
  signal crc_stream   : std_logic;
  signal tr_crc       : std_logic;

begin
--------------------------------------------------------------------------------
-- Component instantiation
--------------------------------------------------------------------------------

-- crc_stream: data written. High for the input combination of normal data (000)
-- or CRC Cheksum (011). Low if reset.

crc_stream  <= ((not cmd_in(2) and not cmd_in(1) and not cmd_in(0) and not rst)
                or (not cmd_in(2) and cmd_in(1) and cmd_in(0))) and not clr_reg;

tr_crc      <= cmd_in(2) and not cmd_in(1) and not cmd_in(0);

txcrc_lsb : crcgen
 port map (ICLK_2,rst,crc_stream,data(15 downto  0),crc_f(15 downto  0));
txcrc_msb : crcgen
 port map (ICLK_2,rst,crc_stream,data(31 downto 16),crc_f(31 downto 16));

--------------------------------------------------------------------------------
-- Entity processes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Output multiplexer
-- if TR_CRC was asserted previous cycle the CRC should be sent with MSB first
-- to DOUT which can be sent directly to CRCRX. Otherwise DIN is sent to DOUT

-- If normal data at the input, CRC calculator works with the input data
-- During sending checksum process (internal command + empty cycle + Checksum)
-- CRC is reset
-- In all other cases, CRc doesn't perform any action
--------------------------------------------------------------------------------
 
outmux:process
begin
wait until ICLK_2'event and ICLK_2 = '1';

     if (clr_reg='1') then                           -- Send CRC Checksum
        out_cmd           <= "011";
 
        for i in 15 downto 0 loop
       	  OUT_DATA(i)     <= crc_f(15-i);            -- order of LSB reversed
        end loop;
 
        for i in 15 downto 0 loop
          OUT_DATA(i+16)  <= crc_f(31-i);            -- order of MSB reversed
        end loop;

     else
        OUT_DATA          <= data;                   -- send an IDLE between
        out_cmd           <= cmd_in;                 -- Send CRC command and 
                                                     -- the CRCC
     end if;

end process outmux;

--------------------------------------------------------------------------------
-- Register on the TR_CRC signal because of the CRC generator latency. During 
-- the latency cycle CRC_CN is asserted to signal that this cycle can be used
-- for special crc control words. RESET signal also clears crcgen.
--------------------------------------------------------------------------------

send_crc_reg:process
begin
wait until ICLK_2'event and ICLK_2 ='1';
  clr_reg                 <= tr_crc;
  rst                     <= clr_reg or reset;
end process send_crc_reg;


end behaviour;
--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : split.vhd                                                     --
--                                                                            --
-- Authors    : Aurelio Ruiz Garcia                                           --
--                                                                            --
-- Description: Generation of the suitable input for the TLK-2501             --
--              Inputs :                                                      --
--                      XCLK    -> 125 MHz clock.                             --
--                      DATA_IN ->  32-bit data (at 62.5 MHz)                 --
--                      CMDIN   -> Input command. See coding in table below.  --
--                       3-bit command                                        --
--                                                                            --
--              Output:                                                       --
--                      TXD     -> 16-bit output data. They must be mapped to --
--                                 I/O registers.                             --
--                      TX_ER,TX_EN -> Control bits for TLK2501. See meaning  --
--                                 in table below.                            --
--                                                                            --
--              If data is received, split in two 16-bit words, which         --
--              will be consecutively sent. Other kind of words (internal     --
--              commands,idles) are sent by setting the                       --
--              corresponding combination of signals TX_ER and TX_EN          --
--              When no data is available, IDLE is sent                       --
--                                                                            --
--------------------------------------------------------------------------------
--  CMDIN |   Meaning  |   TX_EN    |   TX_ER     |     ENCODER 20 BIT OUTPUT --
--------------------------------------------------------------------------------
--   000  | Normal data|     1      |     0       |  MSB : Normal data char.  --
--        |            |     1      |     0       |  LSB : Normal data char.  --
--   001  | Test word  |     1      |     0       |  MSB : Normal data char.  --
--        |            |     1      |     0       |  LSB : Normal data char.  --
--   010  |  Control   |     1      |     0       |  MSB : Normal data char.  --
--        |    word    |     1      |     0       |  LSB : Normal data char.  --
--   011  |    CRC     |     1      |     0       |  MSB : Normal data char.  --
--        |  Checksum  |     1      |     0       |  LSB : Normal data char.  --
--   100  |  Send CRC  |     0      |     1       |  MSB : K23.7,K23.7        --
--        |            |     1      |     0       |  LSB : Normal data char.  --
--   101  |  Internal  |     0      |     1       |  MSB : K23.7,K23.7        --
--        |  command   |     1      |     0       |  LSB : Normal data char.  --
--   111  |   IDLE     |     0      |     0       |  K28.5,D5.6 or K28.5 D16.2--
--        |            |     0      |     0       |  K28.5,D5.6 or K28.5 D16.2--
--------------------------------------------------------------------------------
--                                                                            --
--------------------------------------------------------------------------------
--                            Revision History                                --
--------------------------------------------------------------------------------
-- Version |   Mod.Date  |Author| Modifications                               --
--------------------------------------------------------------------------------
--     1.0 |  1.Nov.2001 | ARG  | Original version                            --
--     1.0 | 13 aug 2002 | JMH  | Reviewed,Comments added                     --
--     1.1 | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity SPLIT is
--==============================================================================

  port(
    POWER_UP_RST_N : in  std_logic;
    XCLK           : in  std_logic;                      -- 125 MHz
    DATA_IN        : in  std_logic_vector(31 downto 0);  -- data input
    CMDIN          : in  std_logic_vector( 2 downto 0);  -- meaning of
                                                         -- data input
    TXD            : out std_logic_vector(15 downto 0);  -- data output

    TX_ER : out std_logic;              -- transmit error coding
    TX_EN : out std_logic               -- transmit enable
    -- these two combined have the following meaning to the TLK2501 device
    -- TX_EN = 1 , TX_ER = 0 means normal data
    -- TX_EN = 1 , TX_ER = 1 means transiver generates error
    -- TX_EN = 0 , TX_ER = 1 means carrier extend

    );

end SPLIT;


--==============================================================================
architecture behavioural of SPLIT is
--==============================================================================
  type split_mach is (COMMAND, NORMALLSB, IDLE, NORMALMSB);

  signal tx_er_in : std_logic;
  signal tx_en_in : std_logic;

  signal tx_er_in2 : std_logic;
  signal tx_en_in2 : std_logic;

  signal lsbdata : std_logic;

  signal curr_split : split_mach;
  signal scmd_in    : std_logic_vector( 2 downto 0);
  signal cmdin2     : std_logic_vector( 2 downto 0);

  signal txd_in  : std_logic_vector(15 downto 0);
  signal txd_in2 : std_logic_vector(15 downto 0);

  signal lsb_in : std_logic_vector(15 downto 0);

  signal sdatain  : std_logic_vector(31 downto 0);
  signal data_in2 : std_logic_vector(31 downto 0);

begin

--------------------------------------------------------------------------------
-- SYNCHRONISATION PROCESS                                                    --
-- Signals from CRCLSC running at 62.5 MHz clock (ICLK_2)                     --
--------------------------------------------------------------------------------
  sync : process
  begin
    wait until xclk'event and xclk = '1';
    data_in2 <= data_in;
    sdatain  <= data_in2;
    cmdin2   <= cmdin;
    scmd_in  <= cmdin2;
  end process sync;

--------------------------------------------------------------------------------
-- LSB register, keeps LSB data to be sent on the second clock cycle          --
--------------------------------------------------------------------------------
  lsb : process
  begin
    wait until xclk'event and xclk = '1';
    lsb_in <= sdatain(15 downto 0);
  end process lsb;

--------------------------------------------------------------------------------
-- CASE selection for the output multiplexer                                  --
-- Depending on the command input, the output case is selected.               --
-- Each option is decided at 125 MHz, there is therefore no need for          --
-- synchronisation with the 62.5 MHz clock (possibilities are always one 125  --
-- MHz clock cycle long)                                                      --
--------------------------------------------------------------------------------
  split_case : process(xclk, POWER_UP_RST_N)
  begin
    if POWER_UP_RST_N = '0' then
      curr_split <= IDLE;
      
    elsif( xclk'event and xclk = '1')then

-- Bit 2 low in command input determines that data input must be sent as normal
-- data character (normal data, test word, control word, CRC checksum)

      if (scmd_in(2) = '0') then
        if (lsbdata = '0') then
          curr_split <= NORMALMSB;
        else
          curr_split <= NORMALLSB;
        end if;

-- Internal command to be sent. First send character K23.7 K23.7, then the data
-- as normal data character containing the command. There are two possible
-- inputs for internal commands: 100 -> Send CRC
--                               101 -> All other internal commands

      elsif (scmd_in(1) = '0') then
        if (lsbdata = '1') then
          curr_split <= NORMALLSB;
        else
          curr_split <= COMMAND;
        end if;

-- All other possibilities, send IDLEs

      else
        curr_split <= IDLE;
      end if;
    end if;

  end process split_case;

--------------------------------------------------------------------------------
-- Output multiplexer                                                         --
--------------------------------------------------------------------------------
  out_mux : process(curr_split, sdatain, lsbdata, lsb_in)
  begin
    case curr_split is

      when COMMAND =>                   -- Send K23.7
        tx_er_in <= '1';
        tx_en_in <= '0';
        lsbdata  <= '1';
        txd_in   <= sdatain(31 downto 16);

      when NORMALLSB =>                 -- Send data
        tx_er_in <= '0';                -- (any kind)
        tx_en_in <= '1';
        lsbdata  <= '0';
        txd_in   <= lsb_in;

      when NORMALMSB =>                 -- Send data
        tx_er_in <= '0';                -- (any kind)
        tx_en_in <= '1';
        lsbdata  <= '1';
        txd_in   <= sdatain(31 downto 16);

      when IDLE =>                      -- send IDLE
        tx_er_in <= '0';
        tx_en_in <= '0';
        lsbdata  <= '0';
        txd_in   <= sdatain(31 downto 16);

      when others =>                    -- send IDLE
        tx_er_in <= 'X';
        tx_en_in <= 'X';
        lsbdata  <= 'X';
        txd_in   <= (others => 'X');
    end case;
  end process out_mux;

--------------------------------------------------------------------------------
-- Output process                                                             --
-- The outputs are synchronised to the 125 MHz clock.                         --
--------------------------------------------------------------------------------


  sync_xclk : process
  begin
    wait until XCLK'event and XCLK = '1';  -- Ouputs registered
    txd_in2   <= txd_in;                   -- due to the latency
    TXD       <= txd_in2;                  -- and to guarantee
    tx_er_in2 <= tx_er_in;                 -- that they are
    TX_ER     <= tx_er_in2;                -- mapped to I/O reg.
    tx_en_in2 <= tx_en_in;
    TX_EN     <= tx_en_in2;
  end process sync_xclk;




end behavioural;
--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--==============================================================================
--                                                                            --
-- File name  : retch.vhd                                                     --
--                                                                            --
-- Authors    : Aurelio Ruiz                                                  --
--                                                                            --
-- Description: Return channel logic.                                         --
--                                                                            --
--              Actions performed:                                            --
--                                                                            --
--                -TLK-2501 state checked. Inputs RX_ER and RX_DV are both    --
--                   high (high impedance signals delivered by the TLK device,--
--                   forced to high through pull-up resistors) when           --
--                   the device is in the initialization state after powering --
--                   up, and also high (directly high delivered by the device)--
--                   after any problem during normal transmission or reception--
--                                                                            --
--                - Return channel logic:                                     --
--                   Link Return Lines (output to user)                       --
--                   synchr. to 125 MHz clock                                 --
--                   XOFF, LDOWN, RRESET delivered to                         --
--                   control block, synchr. to 62.5 MHz clock                 --
--                   Test in return lines. Inform TEST block that wrong       --
--                   test word was received                                   --
--                                                                            --
--              During power-on reset in the TLK-2501, RX_CLK is held low.    --
--                                                                            --
--              It is necessary to have fast input registers in pins RX_ER    --
--              and RX_DV. To have them, no combinatorial logic can be        --
--              performed directly on them.                                   --
--                                                                            --
--              To avoid false link down interruptions (due to glitches in    --
--              rx_down signal), this signal is filtered, and only the        --
--              interruption will be generated when this signals keeps the    --
--              value for at least 3 XCLK clock cycles. XCLK signal is used   --
--              since it's the only clock whose existence is guaranteed.      --
--              (RX_CLK doesn't run when the TLK device down, ICLK_2 is the   --
--              internally generated clock, in initialitation also out).      --
--                                                                            --
--              Test words are only checked while the LSC is in test mode.    --
--              Test errors in other case would not be detected. (LDC informed--
--              sending a false test word)                                    --
--                                                                            --
--              Inputs   : RESET   -> Reset signal from REGLSC block.        --
--                         RX_CLK  -> 125 MHz received clock from TLK device. --
--                                    When TLK is still in power-up process,  --
--                                    it is held low. this situation can be   --
--                                    recognised means signals RX_ER and RX_DV--
--                         ICLK_2  -> Internally generated 62.5 MHz clock.    --
--                         RXD     -> 16-bit received data. They can contain  --
--                                    test words (when preceded by a carrier  --
--                                    extend command) or data words with the  --
--                                    bits having the following meaning:      --
--                              ------------------------------------------------
--                              |     Bits    |             Meaning           --
--                               -----------------------------------------------
--                              |  ( 0.. 7)   |  Return lines                 --
--                              |  ( 8.. 9)   |  XOFF - Flow control          --
--                              |  (10..11)   |  LDC down                     --
--                              |  (12..13)   |  LDC reset                    --
--                              |  (14..15)   |  Reserved,ignore on reception --
--                              ------------------------------------------------
--                                    For error control each bit is sent twice--
--                                    They must be mapped to I/O registers.   --
--                         RX_ER   -> Receive error. High (pulled-up high     --
--                                    impedance value) when TLK still in power--
--                                    up process.                             --
--                                    It must be mapped to an I/O register.   --
--                         RX_DV   -> Receive data valid. High (pulled-up high--
--                                    impedance value) when TLK still in power--
--                                    up process.                             --
--                                    It must be mapped to an I/O register.   --
--                                                                            --
--              Outputs  :  LRL    -> Link Return Lines. Updated when valid   --
--                                    received from Return Channel. Value kept--
--                                    otherwise.                              --
--                                    They must be mapped to I/O registers.   --
--                          LDOWN  -> Link Down signal. Either TLK is not     --
--                                    working or link down signal received    --
--                                    from LDC.                               --
--                          LDC_RESET -> Reset signal received from LDC.      --
--                          TEST_ER-> Detected an error in return channel     --
--                                    test.                                   --
--                                                                            --
--------------------------------------------------------------------------------
--                            Revision History                                --
--------------------------------------------------------------------------------
--     Version   |    Mod.Date   |   Author  |    Modifications               --
--------------------------------------------------------------------------------
--       1.0     |   4-Dec-2001  |    ARG    |     Original Version           --
--       1.1     |  18-Mar-2002  |    ARG    |  LRL delivered at 125 MHz      --
--               |               |           | Code2 added.                   --
--       1.2     |  11-Apr-2002  |    ARG    | Output SEND_RXER removed       --
--       1.3     |  24-May-2002  |    ARG    | rx_down signal filtered        --
--       1.4     |   4-Jun-2002  |    ARG    | down_cnt added                 --
--       1.5     |   9-Sep-2002  |    JMH    | reviewed, "when others" added  --
--               |               |           | statechange removed from Wait2 --
--               |               |           | if -then - else made no sence  --
--               |               |           | states CHECK and RES removed   --
--               |               |           |                                --
--       1.6     |  10-sep-2002  |    JMH    | UCLK added to alow TEST_ER to  --
--               |               |           | be sync. to UCLK               --
--               |               |           | even at low freq UCLK          --
--       1.7     |  11-sep-2002  |    JMH    | statemachine changes to be     --
--               |               |           | directly dependent on the      --
--               |               |           | TLK2501 state                  --
--       1.8     |  12-may-2003  |    JMH    | added POWER_UP_RST_N           --
--       1.9     |  19-may-2003  |    JMH    | up_cnt now on rx_clk, reset by --
--               |               |           | down_cnt_xclk'high.            --
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
entity RETCH is
--==============================================================================
  generic (
    INIT_LENGTH : integer
    );

  port(
    POWER_UP_RST_N : in  std_logic;
    RESET          : in  std_logic;
    XCLK           : in  std_logic;
    RX_CLK         : in  std_logic;                      -- clock from TLK-2501
    RXD            : in  std_logic_vector(15 downto 0);  -- data ret.channel
    RX_ER          : in  std_logic;
    RX_DV          : in  std_logic;
    ICLK_2         : in  std_logic;                      -- 62.5 MHz clock
    TEST_MODE      : in  std_logic;
    UCLK           : in  std_logic;                      -- User clock
    LRL            : out std_logic_vector( 3 downto 0);  -- return lines
    XOFF           : out std_logic;                      -- to Frame block
    LDOWN          : out std_logic;
    LDC_RESET      : out std_logic;
    TEST_ER        : out std_logic
    );

end RETCH;

--==============================================================================
--==============================================================================
--------------------------------------------------------------------------------
-- END OF ENTITY
--------------------------------------------------------------------------------
--==============================================================================
--==============================================================================


--==============================================================================
architecture behavioural of RETCH is
--==============================================================================

-- TLK states.                                                 -- IDLE
  constant RX_IDLE    : std_logic_vector( 1 downto 0) := "00";
                                        -- Data
  constant RX_DATA    : std_logic_vector( 1 downto 0) := "10";
                                        -- Carrier extend
  constant RX_CARRIER : std_logic_vector( 1 downto 0) := "01";
                                        -- Error in data
                                        -- or TLK
  constant RX_ERROR   : std_logic_vector( 1 downto 0) := "11";

-- state variables for Up/Down control
  constant STEP1  : std_logic := '0';
  constant DEV_UP : std_logic := '1';

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Signals for PART1: TLK down check                                          --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--

  signal tlk_curr_state : std_logic;
  signal tlk_next_state : std_logic;


  signal rx_down      : std_logic;
  signal rx_down_x    : std_logic;        -- sync. register for RX_DOWN
  signal rx_down_x1   : std_logic;        -- sync. register for RX_DOWN
  signal rx_down_reg_rx : std_logic;      -- registered to achieve tsu for
                                          -- large up_cnt
  signal code : std_logic_vector(1 downto 0);
  signal up_cnt_high_x,up_cnt_high_x_1 :std_logic;    
  signal rx_down_d2_x : std_logic;

  signal down_cnt_xclk : std_logic_vector(3 downto 0);
  signal up_cnt        : std_logic_vector((INIT_LENGTH-1) downto 0);

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- ENF OF Signals for PART1: TLK down check                                   --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- Signals for PART2 and PART3                                               --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--

  signal inldown    : std_logic;
  signal tlk_down   : std_logic;
  signal inldown_i  : std_logic;
  signal tlk_down_i : std_logic;

  signal intester : std_logic;

  signal test_mode_rx1 : std_logic;
  signal test_mode_rx  : std_logic;

--result of validation process
  signal valid  : std_logic;
  signal valid1 : std_logic;

  signal sig_tlk_down_i : std_logic;

  signal xoffin      : std_logic;
  signal ldc_resetin : std_logic;

  signal intestervar : std_logic;

  signal sreset  : std_logic;
  signal sreset1 : std_logic;

  signal sig_xoff      : std_logic;
  signal sig_ldown     : std_logic;
  signal sig_ldc_reset : std_logic;

  signal code2 : std_logic;

-- state variable for TLK2501_STATE_MACHINE
  signal TLK2501_STATE      : std_logic_vector(1 downto 0);
  signal LAST_TLK2501_STATE : std_logic_vector(1 downto 0);

  signal lrlin : std_logic_vector(3 downto 0);

  signal test_word   : std_logic_vector(13 downto 0);
  signal datain      : std_logic_vector(15 downto 0);
  signal datainreg   : std_logic_vector(15 downto 0);
  signal datainreg_d : std_logic_vector( 6 downto 0);

-- these signals are for the TEST_ER UCLK synchronization process
  signal uclk_cnt     : std_logic;
  signal test_er1     : std_logic;
  signal test_er_long : std_logic;
  
   attribute dont_touch : string;
   attribute dont_touch of
      up_cnt : signal is "true";  

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- PART1: TLK down check                                                      --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- this part of the RETCH module reacts on the TLK2501 signals RX_ER and RX_DV--
-- if the RX_clk is not running                                               --
-- the result of this part is the :                rx_down_d2_x               --
-- that signal indicates to the main state machine whether it is save         --
-- to run on RX_CLK.                                                          --
-- rx_down_d2_x = 0 means OK and rx_down_d2_x = 1 that it is not              --
--                                                                            --
-- the part has in total 5 processes                                          --
-- regis_xclk            : simple register                                    --
-- tlk_down_check        : state change register                              --
-- tlk_down_machine      : State machine                                      --
-- down_count            : counter -counts while RX_ER and RX_DV are both high--
-- up_count              : counter - when they are not                        --
--                                                                            --
-- TLK device can be down if RX_DV and RX_ER are high. In that case, RX_CLK   --
-- will be not running, so it's neccessary to check it using a different clock--
-- since ICLK_2 is internally generated using the PLL, and it is not always   --
-- guaranteed to have it running, this checking is performed using the        --
-- 125 MHz clock.                                                             --
--                                                                            --
--------------------------------------------------------------------------------
  rx_down <= RX_ER and RX_DV;
  rx_down_reg_rx <= code(0) and code(1); -- registered version of RX_ER and RX_DV

-- purpose: state change
-- type   : sequential
-- inputs : xclk, POWER_UP_RST_N,tlk_next_state
-- outputs: tlk_curr_state
  tlk_down_check : process (xclk, POWER_UP_RST_N)
  begin  -- process tlk_down_check
    if POWER_UP_RST_N = '0' then          -- asynchronous reset (active low)
      tlk_curr_state <= STEP1;
    elsif xclk'event and xclk = '1' then  -- rising clock edge
      tlk_curr_state <= tlk_next_state;
    end if;
  end process tlk_down_check;

  tlk_down_machine : process(tlk_curr_state, up_cnt_high_x, DOWN_CNT_XCLK)

  begin
    case tlk_curr_state is
      when STEP1 =>

        rx_down_d2_x <= '1';
        -- in order to leave this state
        --the rx_down must be low for at least 2 in INIT_LENGHT  RX_CLK's
        if ( up_cnt_high_x = '1') then
          tlk_next_state <= DEV_UP;
        else
          tlk_next_state <= STEP1;
        end if;


      when DEV_UP =>

        rx_down_d2_x <= '0';
        -- in order to leave this state
        --the rx_down must be high for at least 8 XCLK
        if (down_cnt_xclk(down_cnt_xclk'high) = '1') then
          tlk_next_state <= STEP1;
        else
          tlk_next_state <= DEV_UP;
        end if;


      when others =>
        rx_down_d2_x   <= 'X';
        tlk_next_state <= STEP1;

    end case;
  end process;
--------------------------------------------------------------------------------
-- Link down counter                                                          --
-- To consider that the link is down, at least 8 consecutive down words       --
-- (RX_ER and RX_DV = 1) must be received.                                    --
--------------------------------------------------------------------------------
 
  down_count : process(XCLK, POWER_UP_RST_N)
  begin
    if (POWER_UP_RST_N = '0') then
      down_cnt_xclk <= (others => '1'); -- async reset
      rx_down_x1 <= '1';
      rx_down_x <= '1';
    elsif (XCLK'event and XCLK = '1') then
      rx_down_x1 <= rx_down;
      rx_down_x <= rx_down_x1;
      if rx_down_x = '0' then
        down_cnt_xclk <= (others => '0');
      elsif (down_cnt_xclk(down_cnt_xclk'high) = '0') then
        down_cnt_xclk <= down_cnt_xclk + 1;
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------
-- Link up counter                                                            --
-- To consider that the link is up, at least 2 in INIT_LENGHT consecutive     --
-- words different from down words (RX_ER and RX_DV = 1) must be received.    --                --
--------------------------------------------------------------------------------
  up_count : process(rx_down_reg_rx,down_cnt_xclk(down_cnt_xclk'high),RX_CLK, POWER_UP_RST_N)
  begin
    if( down_cnt_xclk(down_cnt_xclk'high) = '1' or POWER_UP_RST_N = '0') then
      up_cnt <= (others => '0'); --async reset
    elsif (RX_CLK'event and RX_CLK = '1') then
      if( rx_down_reg_rx = '1')then
        up_cnt <= (others => '0');--sync reset
      elsif (up_cnt(up_cnt'high) = '0') then
        up_cnt <= up_cnt + 1;
      end if;
    end if;
  end process;

xclk_sync_of_upcnt_high: process (XCLK,up_cnt(up_cnt'high),  POWER_UP_RST_N)
begin  -- process xclk_sync_of_upcnt_high
  if POWER_UP_RST_N = '0' then          -- asynchronous reset (active low)
    up_cnt_high_x <= '0';    
    up_cnt_high_x_1 <= '0';    
  elsif XCLK'event and XCLK = '1' then  -- rising clock edge
    up_cnt_high_x_1 <= up_cnt(up_cnt'high);    
    up_cnt_high_x <=  up_cnt_high_x_1;    
  end if;
end process xclk_sync_of_upcnt_high;

  
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- END OF PART1: TLK down check                                               --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--


--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- PART2: Main State machine & internal calculation processes                 --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- this part has in total 8 processes                                         --
-- sync                      : Synchronisation process & state change process --
-- datasync_proc             : Data sync process                              --
-- TLK2501_STATE_MACHINE     : Main state machine follows TLK2501 STATE       --
-- test_word_proc            : generates Test words when LSC is in TESTmode   --
-- datavalid                 : validates incomming datawords except testwords --
-- int_reg                   : simple register                                --
-- outmux                    : updates return lines and internal signals      --
--                             if validated                                   --
-- checkpr                   : part of test validation                        --
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Synchronisation process & state change process                             --
-- Signals rx_dv and rx_er must be registered. Otherwise it will not be       --
--         possible to add an input register in the Altera device             --
-- When the TLK is not in the active mode, RX_CLK is held low. It does not    --
--         affect this process, since the registered data will not be then    --
--         used                                                               --
--------------------------------------------------------------------------------

  sync : process(rx_down_d2_x, rx_clk)
  begin
    if (rx_down_d2_x = '1') then        -- TLK down
      TLK2501_STATE      <= RX_ERROR;   -- no clock
      LAST_TLK2501_STATE <= RX_ERROR;

      code2         <= '1';
      sreset1       <= '1';
      sreset        <= '1';
      test_mode_rx1 <= '0';
      test_mode_rx  <= '0';

    elsif (RX_CLK'event and RX_CLK = '1') then  -- TLK works
      LAST_TLK2501_STATE <= TLK2501_STATE;      -- register state
      TLK2501_STATE(1)   <= RX_DV;              -- register TLK
      TLK2501_STATE(0)   <= RX_ER;              -- control bits
                                                -- as state

      code2   <= rx_down_d2_x;
      sreset1 <= reset;
      sreset  <= sreset1;

      test_mode_rx1 <= TEST_MODE;
      test_mode_rx  <= test_mode_rx1;

    end if;
  end process;

--------------------------------------------------------------------------------
-- Data synchronisation                                                       --
-- Input data are registered, otherwise I/O registers cannot be used.         --
-- 2 clock cycles latency needed to check if data were valid to update        --
-- the Link Return Lines and the corresponding signals.                       --
--------------------------------------------------------------------------------

  datasync_proc : process
  begin

    wait until RX_CLK'event and RX_CLK = '1';
    datain    <= RXD;
    datainreg <= datain;

      code(1) <= RX_DV;
      code(0) <= RX_ER;

    for i in 6 downto 0 loop
      datainreg_d(i) <= datainreg(2*i);  -- to update LRL and
    end loop;  -- output signals

  end process;

--------------------------------------------------------------------------------
-- State machine                                                              --
-- RX_CLK clock is low during power-on reset. Therefore, the machine will not --
-- be running under this clock until the device is working properly           --
--------------------------------------------------------------------------------
  TLK2501_STATE_MACHINE : process(TLK2501_STATE, RX_CLK, code2)
  begin
    if (code2 = '1') then               -- TLK is down
      intestervar <= '0';
    elsif (RX_CLK'event and RX_CLK = '1') then
      case TLK2501_STATE is             -- state of TLK2501

        when RX_IDLE =>
          null;

        when RX_CARRIER =>
          null;

        when RX_DATA =>
          if(LAST_TLK2501_STATE = RX_CARRIER)then
            -- test words are preceded by RX_CARRIER
            if (datain(13 downto 0) = test_word) then
              intestervar <= not sreset;
            else
              intestervar <= sreset;
            end if;
          else
            intestervar <= not sreset;
          end if;

        when RX_ERROR =>
          intestervar <= '0';

        when others =>
          intestervar <= '0';

      end case;

    end if;

  end process;

--------------------------------------------------------------------------------
-- Test pattern generator                                                     --
-- Walking 1 shifted when RX_CARRIER received (next word will be a test word) --
-- cleared on going out of test mode, or when device down (checked if there   --
-- is no clock).                                                              --
--------------------------------------------------------------------------------

  test_word_proc : process(code2, rx_clk)
  begin
    if (code2) = '1' then
      test_word <= (13 => '1', others => '0');
    elsif (RX_CLK'event and RX_CLK = '1') then
      if (test_mode_rx = '0' ) then
        test_word <= (13 => '1', others => '0');
      elsif (TLK2501_STATE = RX_CARRIER)then
        test_word <= test_word(12 downto 0) & test_word(13);
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------
-- Check the validity of data from Return Channel                             --
-- Signal valid generation is split in two different loops to increase speed  --
-- I do not beleave an increase in speed can be accomplised by spilting up    --
-- the calculation in 3 FOR loops ?
--------------------------------------------------------------------------------
  datavalid : process(rx_clk)
    variable data_not_test : std_logic;
  begin
    if (RX_CLK'event and RX_CLK = '1') then
      valid <= valid1;
      if(LAST_TLK2501_STATE = RX_CARRIER)then
        valid1 <= '0';

      elsif(TLK2501_STATE = RX_DATA )then
        valid1 <= not ((datain(0) xor datain(1)) or
                       (datain(2) xor datain(3)) or
                       (datain(4) xor datain(5)) or
                       (datain(6) xor datain(7)) or
                       (datain(8) xor datain(9)) or
                       (datain(10) xor datain(11)) or
                       (datain(12) xor datain(13)) or
                       datain(14) or datain(15));
      else
        valid1 <= '0';
      end if;
    end if;
  end process datavalid;



  int_reg : process
  begin
    wait until RX_CLK'event and RX_CLK = '1';
    tlk_down_i     <= sig_tlk_down_i;
    sig_tlk_down_i <= tlk_down;

  end process;

--------------------------------------------------------------------------------
-- Output multiplexor                                                         --
--    Return lines and XOFF,inldown and LDC_RESET signals are updated if      --
--    data received from return channel were valid (each bit had been sent    --
--    twice).                                                                 --
--------------------------------------------------------------------------------

  outmux : process(rx_down_d2_x, rx_clk, valid)
  begin

    if (rx_down_d2_x = '1') then
      lrlin       <= "0000";
      xoffin      <= '0';
      inldown     <= '1';
      ldc_resetin <= '0';

    elsif RX_CLK'event and RX_CLK = '1' then

      if ((valid) = '1') then           -- link return lines must
        lrlin(3 downto 0) <= datainreg_d(3 downto 0);
        XOFFin            <= datainreg_d(4);
        inldown           <= datainreg_d(5);
        LDC_RESETin       <= datainreg_d(6);
      end if;

    end if;

  end process;

  checkpr : process(sreset, intestervar)
  begin
    if (sreset = '0') then
      intester <= '0';
    else
      intester <= intestervar;
    end if;
  end process;

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- END OF PART2: Main State machine & and internal calculation processes      --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- PART3: OUTPUT Synchronization                                              --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- this part has in total 4 processes                                         --
-- lrl_out                 : output register for Link Return Lines (RXCLK)    --
-- linkdown                : synchronization to ICLK_2 of LDC signals like    --
--                           ldcldown ldcreset and Xoff                       --
-- UCLK_COUNT              : counts 1 UCLK - holds test error signal          --
-- UCLK_SYNC               : synchronisation to UCLK                          --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Return lines output registers                                              --
--------------------------------------------------------------------------------

  lrl_out : process
  begin
    wait until RX_CLK'event and RX_CLK = '1';
    lrl(3 downto 0) <= lrlin(3 downto 0);  -- Return lines outputs

  end process;

--------------------------------------------------------------------------------
-- Output register                                                            --
-- Outputs are registered at 62.5 MHz to be delivered to block control        --
-- There should be no problem in the transition 125 MHz -> 62.5 MHz, since    --
-- data will change always at a slower rate                                   --
--------------------------------------------------------------------------------


  linkdown : process
  begin
    wait until ICLK_2'event and ICLK_2 = '1';

    inldown_i     <= inldown;
    sig_LDOWN     <= inldown_i or tlk_down_i;
    LDOWN         <= sig_LDOWN;
    sig_XOFF      <= XOFFin;
    XOFF          <= sig_XOFF;
    sig_LDC_RESET <= LDC_RESETIN;
    LDC_RESET     <= sig_ldc_reset;

  end process;


--------------------------------------------------------------------------------
-- UCLK COUNT                                                                 --
-- this proces makes sure test_er_long is high for 1 UCLK cycle when intester --
-- was high
--------------------------------------------------------------------------------
  UCLK_COUNT : process(intester, UCLK)
  begin
    if (intester = '1')then
      test_er_long <= '1';
      uclk_cnt     <= '0';
    elsif(UCLK'event and UCLK = '1')then
      case uclk_cnt is
        when '1' =>
          uclk_cnt     <= '0';
          test_er_long <= '0';
        when '0' =>
          uclk_cnt <= '1';
        when others =>
          uclk_cnt <= '0';
      end case;
    end if;

  end process;

--------------------------------------------------------------------------------
-- UCLK SYNC                                                                  --
-- double register of TEST_ER                                                 --
--------------------------------------------------------------------------------

  UCLK_SYNC : process
  begin
    wait until UCLK'event and UCLK = '1';
    test_er1 <= test_er_long;
    TEST_ER  <= test_er1;
  end process;

  tlk_down <= TLK2501_STATE(0) and TLK2501_STATE(1);
end behavioural;

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--
-- END OF PART3: OUTPUT Synchronization                                       --
--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||--


--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
--                                                                            --
-- File name   : test.vhd                                                     --
--                                                                            --
-- Title       : Test Pattern Generator                                       --
--                                                                            --
-- Author      : Aurelio Ruiz                                                 --
--                                                                            --
-- Description : Transmits User Data to the input FIFO or loads the           --
--               FIFO with test pattern. Inputs previously registered.        --
--                                                                            --
--               Inputs  :                                                    --
--               RESET   -> From control block. Synchr. to ICLK_2             --
--               UCLK    -> User clock.                                       --
--               UWEN_N  -> User write enable. It must be mapped to I/O       --
--                          register.                                         --
--               UD      -> 32-bit user data. They must be mapped to I/O      --
--                          registers.                                        --
--               UCTRL_N -> User control line. It must be mapped to an I/O    --
--                          register.                                         --
--               UTEST_N -> User test line.It must be mapped to an I/O        --
--               FULL    -> Full Flag from FIFO.                              --
--               EF      -> Empty flag from FIFO, test.                       --
--               TEST_ER -> Test error detected in RC.                        --
--               POWER   -> Powering signal - synchrounized to UCLK before    --
--                          given to TESTING_ST                               --
--                                                                            --
--               Outputs :                                                    --
--               TESTMODE    -> Card in test mode.                            --
--               TESTLED_N   -> Test LED output. On when card in test mode.   --
--               ACTIVITYLED_N -> Activity LED output. On when a write        --
--                          has been performed within the previous number of  --
--                          cycles determined by generic ACTIVITY_LENGTH      --
--                          (2^ACTIVITY_LENGTH).                              --
--               OUT_DATA    -> 34-bit output data. Meaning:                  --
--                                                                            --
--                 -- OUT_DATA(31 downto 0) -> 32-bit data.                   --
--                 -- OUT_DATA(32) ->  To mark control words.                 --
--                                         Active high.                       --
--                 -- OUT_DATA(33) ->  To mark test word.                     --
--                                         Active high.                       --
--                                                                            --
--               WE          -> Write enable for FIFO.                        --
--                                                                            --
--               Test pattern is generated by a 33 bit circular shift register--
--                                                                            --
--               Test mode begins with the first word having test flag high.  --
--                  Data in this first word is test word (it must be sent)    --
--               Test mode ends with the first word having test flag low.     --
--                  This word is no longer a test word (it must be discarded) --
--               After test mode, normal mode is not recovered until empty    --
--                  flag is high, in order to check the FIFO empty flag       --
--                                                                            --
--               The only cases in which data is not written from user is when--
--               UWEN_N is low during reset, or if FIFO full flag received.   --
--                                                                            --
--               When FIFO full flag is received, it means that user received --
--               the flow control signal some clock cycles before (specified  --
--               by FIFO generic FULLMARGIN) and did not react. Data will     --
--               be lost in that case and user informed via DERRLED_N.        --
--                                                                            --
--               That means that data can still be read from user when LDOWN_N--
--               is low, to provide the user a longer response delay, until   --
--               the FIFO is full.                                            --
--                                                                            --
--               Also return channel is tested. However, only the LDC's user  --
--               can check if there was an error during testing. To alert LDC --
--               in that case, a false test sequence is sent (consisting of   --
--               all ones - any other false sequence could be valid).         --
--                                                                            --
--                                                                            --
-- Used files  : testing_st.vhd                                               --
--                                                                            --
-- Notes       : based on testing.vhd (ODIN implementation) by                --
--               Erik van der Bij, CERN, EP-Division                          --
--               Zoltan Meggyesi,  CERN, EP-Division                          --
--               Gyorgy Rubin,     CERN, EP-Division                          --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
--     Version     |    Date     |  Author  | Modifications                   --
--------------------------------------------------------------------------------
--       0.1       |  1-Nov-2001 |   ARG    | First Version                   --
--       0.2       | 29-Nov-2001 |   ARG    | Synchronisation for FULL removed--
--                 |             |          | synchr. generated in FIFO       --
--       0.3       | 17-Apr-2002 |   ARG    | Input reg. for UTEST_N removed  --
--       0.4       |  4-Jun-2002 |   ARG    | power input added               --
--       0.4       | 19-aug-2002 |   JMH    | Reviewed - comments added       --
--                 |             |          | further change will be done     --
--       0.5       | 10-sep-2002 |   JMH    | mapping of POWER to the TESTING --
--                 |             |          | component changed to the UCLK   --
--                 |             |          | synchronized version.           --
--                 |             |          | synchronization of TEST_ER from --
--                 |             |          | the RETCH removed - it is UCLK  --
--                 |             |          | synchronized in the RETCH       --
--       0.6       | 28-Jan-2003 |   JMH    | register removed for testmode   --
--                 |             |          | output signal                   --
--       0.7       | 12-may-2003 |     JMH  | added POWER_UP_RST_N            --
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


--------------------------------------------------------------------------------
entity TEST is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ACTIVITY_LENGTH : When a write operation was performed on the FIFO in the  --
--            last 2^ACTIVITY_LENGTH ICLK2 (internally generated 62.5 MHz     --
--            clock)clock cycles, the activity LED ACTIVITYLED_N will be      --
--            illuminated.                                                    --
--                                                                            --
--            Examples :                                                      --
--               ACTIVITY_LENGTH = 5 => Num. cycles = 2^5 = 32                --
--                   32 cycles x 16 ns/cycle = 512 ns.                        --
--               ACTIVITY_LENGTH = 6 => Num. cycles = 2^6 = 64                --
--                   64 cycles x 16 ns/cycle = 1.024 ms.                      --
--                                                                            --
--            ACTIVITY_LENGTH generic value can be set in the top level       --
--                   entity (holaldc).                                        --
--------------------------------------------------------------------------------

  generic(
    ACTIVITY_LENGTH : integer
    );

  port (
    POWER_UP_RST_N : in std_logic;
    RESET          : in std_logic;                      -- from Control block
    POWER          : in std_logic;
    UCLK           : in std_logic;                      -- Clock from user
    UWEN_N         : in std_logic;                      -- Sync. user write
    UD             : in std_logic_vector(31 downto 0);  -- Data from FEMB
    UCTRL_N        : in std_logic;                      -- Syn.
    UTEST_N        : in std_logic;
    FULL           : in std_logic;                      -- Full Flag from FIFO
    EF             : in std_logic;                      -- Empty flag, test
    TEST_ER        : in std_logic;                      -- Test error in RC

    FIFO_RES      : out std_logic;
    TESTMODE      : out std_logic;
    TESTLED_N     : out std_logic;
    ACTIVITYLED_N : out std_logic;
    OUT_DATA      : out std_logic_vector(33 downto 0);  -- Read data
    WE            : out std_logic       -- Write enable for FIFO

    );
end TEST;


--------------------------------------------------------------------------------
architecture behaviour of TEST is
--------------------------------------------------------------------------------

-- Synchronisation registers for asynchronous inputs
  signal sreset  : std_logic;
  signal sreset1 : std_logic;

  signal sldown_i1 : std_logic;
  signal sldown_i  : std_logic;

-- Registers used, since test and twen_n are both written and read
  signal test   : std_logic;            -- Device in test mode
  signal twen_n : std_logic;
  signal tmode  : std_logic;            -- Output mux. control
  signal swe    : std_logic;

-- Shift register, test pattern generation
  signal shiftr : std_logic_vector(32 downto 0);
  signal cnt    : std_logic_vector( (ACTIVITY_LENGTH-1) downto 0);

  signal sig_testmode : std_logic;
--------------------------------------------------------------------------------
-- Component testing_st contains the state machine for this block             --
--                                                                            --
-- If test mode is requested, the test pattern is generated and written in the--
--   FIFO. Otherwise, when data available at the inputs they are              --
--   written. Flow control is performed                                       --
--                                                                            --
--------------------------------------------------------------------------------
  component testing_st

    port(

      SRESET   : in  std_logic;         -- from Control block
      POWER    : in  std_logic;
      UCLK     : in  std_logic;         -- Clock from user
      UTEST_N  : in  std_logic;
      FULL     : in  std_logic;         -- Full Flag from FIFO
      EF       : in  std_logic;         -- Empty flag, test
      SHIFTR   : in  std_logic_vector(32 downto 0);
      FIFO_RES : out std_logic;
      test     : out std_logic;         -- Device in test mode
      twen_n   : out std_logic;
      tmode    : out std_logic          -- Output mux. control

      );

  end component;

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
  testing_st1 : testing_st

    port map (

      SRESET   => sreset,
      POWER    => sldown_i,             --sldown_i is sync version of POWER
      UCLK     => UCLK,
      UTEST_N  => UTEST_N,
      FULL     => full,
      EF       => ef,
      SHIFTR   => shiftr,
      FIFO_RES => FIFO_RES,
      test     => test,
      twen_n   => twen_n,
      tmode    => tmode

      );


--------------------------------------------------------------------------------
-- SYNCHRONISATION STAGE                                                      --
-- Signals not synchronous to UCLK are synchronised                           --
--------------------------------------------------------------------------------
  syncstage : process
  begin
    wait until UCLK'event and UCLK = '1';
    sreset1 <= RESET;
    sreset  <= sreset1;

    sldown_i1 <= POWER;
    sldown_i  <= sldown_i1;
  end process syncstage;


--------------------------------------------------------------------------------
-- OUTPUT PROCESS                                                             --
-- Data mode   : Input data moved to the output data port.                    --
-- Test mode   : Bit pattern generated in the shift register                  --
--               moved to the output data port                                --
--                                                                            --
-- Write enable is disabled during reset                                      --
--------------------------------------------------------------------------------
  inreg_proc : process
  begin
    wait until UCLK'event and UCLK = '1';

    if (tmode = '1') then
      OUT_DATA(31 downto 0) <= shiftr(31 downto 0);  -- Output test frame
      OUT_DATA(32)          <= shiftr(32);
      OUT_DATA(33)          <= test;                 -- connect to output.
      sWE                   <= not twen_n and not sreset;
--      sig_testmode            <= '1';

    else

      OUT_DATA(31 downto 0) <= UD(31 downto 0);  -- Output data
      OUT_DATA(32)          <= not UCTRL_N;      -- Control flag set.
      OUT_DATA(33)          <= '0';              -- Test flag low.
      sWE                   <= not UWEN_N and not sreset;
--      sig_testmode            <= '0';

    end if;

  end process inreg_proc;
  sig_testmode <= tmode;


--------------------------------------------------------------------------------
-- TEST PATTERN GENERATOR                                                     --
-- The test pattern consists of 1 walking bit                                 --
-- If an error from return channel is received, a false sequence (all 1's)    --
--    is sent so that the LDC detects an error.                               --
--------------------------------------------------------------------------------


  shiftreg : process
  begin
    wait until UCLK'event and UCLK = '1';
    if (test = '0') then
      shiftr <= (32 => '1', others => '0');
    elsif (TEST_ER = '1') then
      shiftr <= (others => '1');
    elsif (twen_n = '0') then
      shiftr <= shiftr(31 downto 0) & shiftr(32);
                                        -- circular shift
    end if;

  end process;


--------------------------------------------------------------------------------
-- ACTIVITY LED: Active LED will be kept low unless no write operation is     --
--               performed during the interval defined by ACTLED_CYCLES       --
--------------------------------------------------------------------------------
  cntactledproc : process(reset, UCLK, POWER_UP_RST_N)
  begin

    if (reset = '1' or POWER_UP_RST_N = '0') then  -- reset
      cnt <= (others => '1');
    elsif UCLK'event and UCLK = '1' then

      if (swe = '1') then
        cnt <= (others => '0');
      elsif (cnt(cnt'high) = '0') then  -- X'high returns X in (X donwto 0)
        cnt <= cnt + '1';
      end if;

    end if;

  end process cntactledproc;

  ACTIVITYLED_N <= cnt(cnt'high);

  WE <= swe;

  TESTMODE  <= sig_testmode;
  TESTLED_N <= not sig_testmode;
end behaviour;

--------------------------------------------------------------------------------
-- END OF FILE
--------------------------------------------------------------------------------
--345678901234567890123456789012345678901234567890123456789012345678901234567890
--------------------------------------------------------------------------------
-- File name   : holalsc_arch.vhd                                             --
--                                                                            --
-- Author      : Aurelio Ruiz Garcia, CERN, EP-Division                       --
--                                                                            --
-- Description : Core function for an HOLA type S-LINK Link Source Card       --
--               ARCHITECTURE                                                 --
--                                                                            --
-- Notes:        Only the active pins are in this architecture. Although      --
--               unlikely, this may limit possibilities for future upgrades.  --
--                                                                            --
--               This design needs three external global clock signals:       --
--                 UCLK, XCLK and RX_CLK                                      --
--                                                                            --
--               ------------------------------------------                   --
--                           TIMING REQUIREMENTS                              --
--               Clock                                                        --
--               ------------------------------------------                   --
--               UCLK           Typ. 40 MHz - From FEMB                       --
--               XCLK               125 MHz - external clock                  --
--               RX_CLK             125 MHz - Recovered from TLK-2501         --
--                                                                            --
--               A fourth clock (ICLK_2 -62.5 MHz) will be used, but          --
--               internally generated after XCLK (using the internal PLL of   --
--               APEX20k30E device).                                          --
--                                                                            --
--               It is possible to work in a simulation mode by setting       --
--               generic SIMULATION "ON", to increase speed when simulating   --
--               on a computer (more details on generics header).             --
--                                                                            --
--               HOLA LSC includes a FIFO used to separate UCLK and ICLK_2    --
--               clock domains. Parameters for the FIFO are set by the        --
--               generics FIFODEPTH,LOG2DEPTH and FULLMARGIN (see complete    --
--               description on generics header).                             --
--                                                                            --
--               It is recommended to add a test connector on boards using    --
--               this core. This connector should carry the signals:          --
--               UCLK                      -- terminate near connector        --
--               LDOWN_N                                                      --
--               URESET_N                                                     --
--               UWEN_N                                                       --
--               UCTRL_N                                                      --
--               LFF_N                                                        --
--               UTEST_N                                                      --
--               UD0                                                          --
--               UD1                                                          --
--               UD31                                                         --
--               URL0                                                         --
--               URL4                                                         --
--                                                                            --
--                                                                            --
-- Synplify    : Warnings:                                                    --
--               Input lderr_n is unused                                      --
--               Input udw is unused                                          --
--               Net iclk_2 appears to be a clock source which was not        --
--                   identified. Assuming default frequency.                  --
--                                                                            --
--------------------------------------------------------------------------------
--                           Revision History                                 --
--------------------------------------------------------------------------------
-- Version |    Date     |Author|      Modifications                          --
--------------------------------------------------------------------------------
--   0.1   | 17-Oct-2001 | ARG  |     Original version                        --
--   0.2   |  6-Feb-2002 | ARG  |     Prepared for Synplify                   --
--   0.3   | 14-Jun-2002 | ARG  | clkd_pll_phase replaces clkd_pll to generate--
--         |             |      | ICLK_2 with 4 ns delay                      --
--   0.4   |  2-dec-2002 | JMH  | support for both Xilinx and Altera          --
--         |             |      | the generic ALTERA_XILINX now selects       --
--         |             |      | Wizard generated components, FIFO and       --
--         |             |      | clock PLL's or DLL's                        --
--   0.4a  |  5-feb-2003 | JMH  | XCLK625_PHASE instantiation changed         --
--   0.4a  | 11-Feb-2003 | JMH  | XCLK625_PHASE instantiation changed and     --
--         |             |      | XCLK_int added                              --
--   0.5   | 12-may-2003 | JMH  | added POWER_UP_RST_N                        --
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

--==============================================================================
--==============================================================================
architecture structure of holalsc_core is
--==============================================================================
--==============================================================================

--==============================================================================
--==============================================================================
-- COMPONENT DECLARATIONS
--==============================================================================
--==============================================================================

--==============================================================================
  component REGLSC
--==============================================================================

    port (
      UCLK     : in std_logic;          -- User inputs
      ICLK_2   : in std_logic;
      UTEST_N  : in std_logic;
      UCTRL_N  : in std_logic;
      UWEN_N   : in std_logic;
      URESET_N : in std_logic;
      UD       : in std_logic_vector(31 downto 0);

      UTEST_U    : out std_logic;       -- Registered outputs
      UCTRL_N_U  : out std_logic;
      UWEN_N_U   : out std_logic;
      UTEST_N_I  : out std_logic;
      URESET_N_I : out std_logic;
      UD_U       : out std_logic_vector(31 downto 0)
      );

  end component;

--==============================================================================
  component XCLK625_PHASE
--==============================================================================
    port (
      RST_IN     : in  std_logic;       --
      CLKIN_IN   : in  std_logic;       -- 125 MHz input
      CLKDV_OUT  : out std_logic;       -- 62.5 MHz output
      CLK180_OUT : out std_logic;
      CLK0_OUT   : out std_logic        -- unused
      );
  end component;

--==============================================================================
  component ACLK625_PHASE
--==============================================================================
    port (
      INCLOCK : in  std_logic;          -- 125 MHz input
      CLOCK1  : out std_logic           -- 62.5 MHz output
    );
  end component;

--==============================================================================
  component ACLK50_PHASE
--==============================================================================
    port (
      INCLOCK : in  std_logic;          -- 100 MHz input
      CLOCK1  : out std_logic           -- 50 MHz output
    );
  end component;

--==============================================================================
  component TEST
--==============================================================================

    generic(
      ACTIVITY_LENGTH : integer := 5
      );

    port (
      POWER_UP_RST_N : in std_logic;
      RESET          : in std_logic;
      POWER          : in std_logic;
      UCLK           : in std_logic;                      -- Clock from user
      UWEN_N         : in std_logic;                      -- User write enable
      UD             : in std_logic_vector(31 downto 0);  -- Data from FEMB
      UCTRL_N        : in std_logic;                      -- User ctrl. line
      UTEST_N        : in std_logic;                      -- user test request
      FULL           : in std_logic;                      -- FIFO Full Flag
      EF             : in std_logic;                      -- Empty flag
      TEST_ER        : in std_logic;                      -- Test error RC

      FIFO_RES      : out std_logic;                      -- Reset FIFO
      TESTMODE      : out std_logic;                      -- Test mode flag
      TESTLED_N     : out std_logic;
      ACTIVITYLED_N : out std_logic;
      OUT_DATA      : out std_logic_vector(33 downto 0);  -- Data output
      WE            : out std_logic                       -- Write enable
      );                                                  -- for FIFO

  end component;


--==============================================================================
  component FIFOLSC
--==============================================================================

    generic(
      ALTERA_XILINX : integer;
      FIFODEPTH     : integer;          -- only powers of 2
      LOG2DEPTH     : integer;          -- 2log of depth
      FULLMARGIN    : integer           -- words left when
      );                                -- LFF_N set

    port (
      POWER_UP_RST_N : in  std_logic;
      ACLR           : in  std_logic;   -- async clear
      TEST_RES       : in  std_logic;
      WCLK           : in  std_logic;   -- write clock
      D              : in  std_logic_vector(33 downto 0);  -- ctl bit and input
                                                           -- data from user
      WEN            : in  std_logic;
      FULL           : out std_logic;   -- Full Flag for
                                        -- testing block
      LFF_N          : out std_logic;   -- Full Flag and XOFF
      RCLK           : in  std_logic;   -- 62.5 MHz
      Q              : out std_logic_vector(33 downto 0);  -- read data
      REN            : in  std_logic;   -- read enable
      EMPTY          : out std_logic;   -- empty flag,read clk
      WR_EMPTY       : out std_logic;   -- empty flag,wr.clk
      DERRLED_N      : out std_logic;
      LFFLED_N       : out std_logic
      );

  end component;


--==============================================================================
  component FRAMELSC
--==============================================================================

    port(
      POWER_UP_RST_N : in  std_logic;
      ICLK_2         : in  std_logic;   -- 62.5 MHz clock
      RESET          : in  std_logic;   -- synchronous reset
      LSCRESET       : in  std_logic;   -- LDC reset request
      LDOWN          : in  std_logic;   -- link down
      XOFF           : in  std_logic;   -- flow control,return
                                        -- channel asynchr.
      DATA_IN        : in  std_logic_vector(33 downto 0);  -- data from FEMB
      EMPTY          : in  std_logic;   -- empty flag;
      REN            : out std_logic;   -- read enable
      OUT_DATA       : out std_logic_vector(31 downto 0);  -- Output data
      TX_CMD         : out std_logic_vector(2 downto 0)    -- output command
      );

  end component;


--==============================================================================
  component PARITYLSC
--==============================================================================

    port (
      POWER_UP_RST_N : in  std_logic;
      ICLK_2         : in  std_logic;                      -- 62.5 MHz clock
      DATA           : in  std_logic_vector(31 downto 0);  -- Input data
      CMDIN          : in  std_logic_vector( 2 downto 0);  -- Input command
      OUT_DATA       : out std_logic_vector(31 downto 0);  -- Output data
      TX_CMD         : out std_logic_vector( 2 downto 0)   -- Output comand
      );

  end component;


--==============================================================================
  component CRCLSC
--==============================================================================

    port (
      ICLK_2   : in  std_logic;                      -- 62.5 MHz clock
      RESET    : in  std_logic;                      -- reset request
      DATA     : in  std_logic_vector(31 downto 0);  -- Input data
      CMD_IN   : in  std_logic_vector( 2 downto 0);  -- Input command
      OUT_CMD  : out std_logic_vector( 2 downto 0);  -- Output command
      OUT_DATA : out std_logic_vector(31 downto 0)   -- Output data
      );

  end component;


--==============================================================================
  component SPLIT
--==============================================================================

    port (

      POWER_UP_RST_N : in  std_logic;
      XCLK           : in  std_logic;   -- external clock
                                        -- 125 MHz
      DATA_IN        : in  std_logic_vector(31 downto 0);  -- data to TLK
      CMDIN          : in  std_logic_vector( 2 downto 0);  -- Input command
      TXD            : out std_logic_vector(15 downto 0);  -- Tx.data(to TLK2501)
      TX_ER          : out std_logic;   -- control bits for
      TX_EN          : out std_logic    -- TLK2501
      );

  end component;


--==============================================================================
  component RETCH
--==============================================================================
    generic (
      INIT_LENGTH : integer
      );

    port (
      POWER_UP_RST_N : in  std_logic;
      RESET          : in  std_logic;
      XCLK           : in  std_logic;   -- External clock
      RX_CLK         : in  std_logic;   -- clock from TLK-2501
      RXD            : in  std_logic_vector(15 downto 0);  -- data from ret.channel
      RX_ER          : in  std_logic;   -- control bits from
      RX_DV          : in  std_logic;   -- TLK2501
      ICLK_2         : in  std_logic;   -- 62.5 MHz clock
      TEST_MODE      : in  std_logic;
      UCLK           : in  std_logic;   -- User clock
      LRL            : out std_logic_vector( 3 downto 0);  -- return lines
      XOFF           : out std_logic;   -- to Frame block
      LDOWN          : out std_logic;   -- Link down
      LDC_RESET      : out std_logic;   -- Reset from LDC
      TEST_ER        : out std_logic    -- Error in test found
      );

  end component;


--==============================================================================
  component CONTROL
--==============================================================================

    generic (
      INIT_LENGTH : integer             -- determines the
                                        -- duration of the
                                        -- initialitation
                                        -- (set by SIMULATION
                                        -- generic)
      );
    port (
      POWER_UP_RST_N : in  std_logic;
      URESET_N_I     : in  std_logic;   -- Synchr. user reset
      ICLK_2         : in  std_logic;   -- 62.5 MHz clock
      UCLK           : in  std_logic;
      LDC_RESET_I    : in  std_logic;   -- reset from LDC
      LDOWN          : in  std_logic;   -- LDOWN from LDC
      TEST_N         : in  std_logic;   -- Test -> Set LDOWN
      TESTMODE       : in  std_logic;
      SEND_RESET     : out std_logic;   -- remote reset
      SEND_LDCRESET  : out std_logic;   -- LDC reset request
      SEND_LDOWN     : out std_logic;   -- inform Link DOWN
                                        -- this signal used
                                        -- both for LDC down
                                        -- and errors in rx.
                                        -- (equiv. to r_up)
      FEMB_LDOWN_N   : out std_logic;   -- inform FEMB that
                                        -- the Link is Down
      POWERING       : out std_logic;
      LUPLED_N       : out std_logic
      );

  end component;


--------------------------------------------------------------------------------
-- End of component declarations
--------------------------------------------------------------------------------

--==============================================================================
-- Internal signals
--==============================================================================
--------------------------------------------------------------------------------
-- signal names have where possible prefix of module where it is output from
-- signal names have where possible suffix of clock they are synchronised to
-- U  : Synchronous to UCLK
-- X  : Synchronous to XCLK
-- I  : Synchronous to ICLK_2
-- RX : Synchronous to RX_CLK
--------------------------------------------------------------------------------

  signal ICLK_2   : std_logic := '1';   -- for simulation
  signal XCLK_int : std_logic;

  signal REG_UTEST_U    : std_logic;
  signal REG_UCTRL_N_U  : std_logic;
  signal REG_UWEN_N_U   : std_logic;
  signal REG_UTEST_N_I  : std_logic;
  signal REG_URESET_N_I : std_logic;
  signal REG_UD_U       : std_logic_vector(31 downto 0);

  signal TEST_FIFORES_U : std_logic;
  signal TEST_TMODE_U   : std_logic;
  signal TEST_WE_U      : std_logic;
  signal TEST_DATA_U    : std_logic_vector(33 downto 0);

  signal FIFO_FULL_U : std_logic;
  signal FIFO_DATA_I : std_logic_vector(33 downto 0);
  signal FIFO_EF_I   : std_logic;
  signal FIFO_WREF_U : std_logic;

  signal FRAME_RE_I   : std_logic;
  signal FRAME_DATA_I : std_logic_vector(31 downto 0);
  signal FRAME_CMD_I  : std_logic_vector( 2 downto 0);

  signal PAR_DATA_I  : std_logic_vector(31 downto 0);
  signal PAR_TXCMD_I : std_logic_vector( 2 downto 0);

  signal CRC_COMMAND_I : std_logic_vector( 2 downto 0);
  signal CRC_DATA_I    : std_logic_vector(31 downto 0);

  signal CRC_COMMAND_SYNC : std_logic_vector( 2 downto 0);
  signal CRC_DATA_SYNC    : std_logic_vector(31 downto 0);  

  signal RCH_XOFF_I      : std_logic;
  signal RCH_LDOWN_I     : std_logic;
  signal RCH_LDC_RESET_I : std_logic;
  signal RCH_TESTER_U    : std_logic;

  signal CTRL_RESET_I    : std_logic;
  signal CTRL_LDCRESET_I : std_logic;
  signal CTRL_LDOWN_I    : std_logic;
  signal CTRL_POWERING_I : std_logic;

--==============================================================================
begin
--==============================================================================

--------------------------------------------------------------------------------
-- CONSTANT SETTINGS                                                          --
--------------------------------------------------------------------------------

  ENABLE <= '1';

--------------------------------------------------------------------------------
-- PORT MAPPINGS
--------------------------------------------------------------------------------

  NO_PLL : if USE_PLL = 0 or USE_ICLK2 = 1 generate

    XCLK_int <= XCLK;

    ICLK2IN_G : if USE_ICLK2 = 1 generate
      ICLK_2 <= ICLK2_IN;
    end generate ICLK2IN_G;

    ICLK2_G : if USE_ICLK2 = 0 generate
      -- Clock generator for internal 50/62.5MHz clock
      ICLK2_P : process (XCLK_int)
      begin  -- process XCLK_int
        if rising_edge(XCLK_int) then
          ICLK_2 <= not ICLK_2;
        end if;
      end process ICLK2_P;
    end generate ICLK2_G;
    
  end generate;

--------------------------------------------------------------------------------

  ALTERA_PLL : if ALTERA_XILINX = 1 and USE_PLL = 1 generate
    
    XCLK_int <= XCLK;

    XCLK_125 : if USE_PLL = 1 and XCLK_FREQ = 125 generate
      CLK625_PHASE : ACLK625_PHASE      --CLKD_PLL_PHASE
        port map (
          INCLOCK => XCLK,
          CLOCK1  => ICLK_2);
    end generate;

    XCLK_100 : if USE_PLL = 1 and XCLK_FREQ = 100 generate
      CLK50_PHASE : ACLK50_PHASE        --CLKD_PLL_PHASE
        port map (
          INCLOCK => XCLK,
          CLOCK1  => ICLK_2);
    end generate;

  end generate;

--------------------------------------------------------------------------------

  XILINX_PLL : if ALTERA_XILINX = 0 and USE_PLL = 1 generate
    
    CLK625_PHASE : XCLK625_PHASE
      port map (
        RST_IN     => dll_reset,        --
        CLKIN_IN   => XCLK,             -- 125 MHz input
        CLKDV_OUT  => ICLK_2,           -- 62.5 MHz output
        CLK180_OUT => XCLK_int,         -- XCLK output signal
        CLK0_OUT   => open);            -- unused

  end generate;

--------------------------------------------------------------------------------
  REG1 : REGLSC
--------------------------------------------------------------------------------

    port map(
      UCLK       => UCLK,
      ICLK_2     => ICLK_2,
      UTEST_N    => UTEST_N,
      UCTRL_N    => UCTRL_N,
      UWEN_N     => UWEN_N,
      URESET_N   => URESET_N,
      UD         => UD,
      UTEST_U    => REG_UTEST_U,
      UCTRL_N_U  => REG_UCTRL_N_U,
      UWEN_N_U   => REG_UWEN_N_U,
      UTEST_N_I  => REG_UTEST_N_I,
      URESET_N_I => REG_URESET_N_I,
      UD_U       => REG_UD_U
      );


--------------------------------------------------------------------------------
  TESTING1 : TEST
--------------------------------------------------------------------------------

    generic map(
      ACTIVITY_LENGTH => ACTIVITY_LENGTH
      )
    port map(
      POWER_UP_RST_N => POWER_UP_RST_N,
      RESET          => CTRL_RESET_I,
      POWER          => CTRL_POWERING_I,
      UCLK           => UCLK,
      UWEN_N         => REG_UWEN_N_U,
      UD             => REG_UD_U,
      UCTRL_N        => REG_UCTRL_N_U,
      UTEST_N        => REG_UTEST_U,
      FULL           => FIFO_FULL_U,
      EF             => FIFO_WREF_U,
      TEST_ER        => RCH_TESTER_U,
      FIFO_RES       => TEST_FIFORES_U,
      TESTMODE       => TEST_TMODE_U,
      TESTLED_N      => TESTLED_N,
      ACTIVITYLED_N  => ACTIVITYLED_N,
      OUT_DATA       => TEST_DATA_U,
      WE             => TEST_WE_U
      );


--------------------------------------------------------------------------------
  FIFOLSC1 : FIFOLSC
--------------------------------------------------------------------------------

    generic map(
      ALTERA_XILINX => ALTERA_XILINX,
      FIFODEPTH     => FIFODEPTH,
      LOG2DEPTH     => LOG2DEPTH,
      FULLMARGIN    => FULLMARGIN
      )

    port map(
      POWER_UP_RST_N => POWER_UP_RST_N,
      ACLR           => CTRL_RESET_I,
      TEST_RES       => TEST_FIFORES_U,
      WCLK           => UCLK,
      D              => TEST_DATA_U,
      WEN            => TEST_WE_U,
      FULL           => FIFO_FULL_U,
      LFF_N          => LFF_N,
      RCLK           => ICLK_2,
      Q              => FIFO_DATA_I,
      REN            => FRAME_RE_I,
      EMPTY          => FIFO_EF_I,
      WR_EMPTY       => FIFO_WREF_U,
      DERRLED_N      => LDERRLED_N,
      LFFLED_N       => FLOWCTLLED_N
      );


--------------------------------------------------------------------------------
  FRAMELSC1 : FRAMELSC
--------------------------------------------------------------------------------

    port map(
      POWER_UP_RST_N => POWER_UP_RST_N,
      ICLK_2         => ICLK_2,
      RESET          => CTRL_RESET_I,
      LSCRESET       => CTRL_LDCRESET_I,
      LDOWN          => CTRL_LDOWN_I,
      XOFF           => RCH_XOFF_I,
      DATA_IN        => FIFO_DATA_I,
      EMPTY          => FIFO_EF_I,
      REN            => FRAME_RE_I,
      OUT_DATA       => FRAME_DATA_I,
      TX_CMD         => FRAME_CMD_I
      );


--------------------------------------------------------------------------------
  PARITYLSC1 : PARITYLSC
--------------------------------------------------------------------------------

    port map(
      POWER_UP_RST_N => POWER_UP_RST_N,
      ICLK_2         => ICLK_2,
      DATA           => FRAME_DATA_I,
      CMDIN          => FRAME_CMD_I,
      OUT_DATA       => PAR_DATA_I,
      TX_CMD         => PAR_TXCMD_I
      );


--------------------------------------------------------------------------------
  CRCLSC1 : CRCLSC
--------------------------------------------------------------------------------

    port map(
      ICLK_2   => ICLK_2,
      RESET    => CTRL_RESET_I,
      DATA     => PAR_DATA_I,
      CMD_IN   => PAR_TXCMD_I,
      OUT_CMD  => CRC_COMMAND_I,
      OUT_DATA => CRC_DATA_I
      );

--------------------------------------------------------------------------------
   SynchronizerFifo_Inst : entity work.SynchronizerFifo
      generic map (
         DATA_WIDTH_G => 35)
      port map (
         wr_clk             => ICLK_2,
         din(31 downto 0)   => CRC_DATA_I,
         din(34 downto 32)  => CRC_COMMAND_I,
         rd_clk             => XCLK_int,
         dout(31 downto 0)  => CRC_DATA_SYNC,    
         dout(34 downto 32) => CRC_COMMAND_SYNC);       

--------------------------------------------------------------------------------
  SPLIT1 : SPLIT
--------------------------------------------------------------------------------

    port map(
      POWER_UP_RST_N => POWER_UP_RST_N,
      XCLK           => XCLK_int,
      DATA_IN        => CRC_DATA_SYNC,
      CMDIN          => CRC_COMMAND_SYNC,
      TXD            => TXD,
      TX_ER          => TX_ER,
      TX_EN          => TX_EN
      );

--------------------------------------------------------------------------------
  RET1 : if SIMULATION = 1 generate
    RETCH1 : RETCH
--------------------------------------------------------------------------------

      generic map (
        INIT_LENGTH => 10
        )
      port map(
        POWER_UP_RST_N => POWER_UP_RST_N,
        RESET          => REG_URESET_N_I,
        XCLK           => XCLK_int,
        RXD            => RXD,
        RX_CLK         => RX_CLK,
        RX_ER          => RX_ER,
        RX_DV          => RX_DV,
        ICLK_2         => ICLK_2,
        TEST_MODE      => TEST_TMODE_U,
        UCLK           => UCLK,
        LRL            => LRL,
        XOFF           => RCH_XOFF_I,
        LDOWN          => RCH_LDOWN_I,
        LDC_RESET      => RCH_LDC_RESET_I,
        TEST_ER        => RCH_TESTER_U

        );
  end generate;

--------------------------------------------------------------------------------
  RET0 : if SIMULATION = 0 generate
    RETCH0 : RETCH
--------------------------------------------------------------------------------

      generic map (
        INIT_LENGTH => 24
        )
      port map(
        POWER_UP_RST_N => POWER_UP_RST_N,
        RESET          => REG_URESET_N_I,
        XCLK           => XCLK_int,
        RXD            => RXD,
        RX_CLK         => RX_CLK,
        RX_ER          => RX_ER,
        RX_DV          => RX_DV,
        ICLK_2         => ICLK_2,
        TEST_MODE      => TEST_TMODE_U,
        UCLK           => UCLK,
        LRL            => LRL,
        XOFF           => RCH_XOFF_I,
        LDOWN          => RCH_LDOWN_I,
        LDC_RESET      => RCH_LDC_RESET_I,
        TEST_ER        => RCH_TESTER_U
        );

  end generate;

--------------------------------------------------------------------------------
  SIM1 : if SIMULATION = 1 generate
    control_sim : CONTROL
--------------------------------------------------------------------------------

      generic map (
        INIT_LENGTH => 3
        )

      port map(
        POWER_UP_RST_N => POWER_UP_RST_N,
        URESET_N_I     => REG_URESET_N_I,
        ICLK_2         => ICLK_2,
        UCLK           => UCLK,
        LDC_RESET_I    => RCH_LDC_RESET_I,
        LDOWN          => RCH_LDOWN_I,
        TEST_N         => REG_UTEST_N_I,
        TESTMODE       => TEST_TMODE_U,
        SEND_RESET     => CTRL_RESET_I,
        SEND_LDCRESET  => CTRL_LDCRESET_I,
        SEND_LDOWN     => CTRL_LDOWN_I,
        FEMB_LDOWN_N   => LDOWN_N,
        POWERING       => CTRL_POWERING_I,
        LUPLED_N       => LUPLED_N
        );
  end generate;


--------------------------------------------------------------------------------
  SIM2 : if SIMULATION = 0 generate
    control_nosim : CONTROL
--------------------------------------------------------------------------------

      generic map (
        INIT_LENGTH => 15
        )

      port map(
        POWER_UP_RST_N => POWER_UP_RST_N,
        URESET_N_I     => REG_URESET_N_I,
        ICLK_2         => ICLK_2,
        UCLK           => UCLK,
        LDC_RESET_I    => RCH_LDC_RESET_I,
        LDOWN          => RCH_LDOWN_I,
        TEST_N         => REG_UTEST_N_I,
        TESTMODE       => TEST_TMODE_U,
        SEND_RESET     => CTRL_RESET_I,
        SEND_LDCRESET  => CTRL_LDCRESET_I,
        SEND_LDOWN     => CTRL_LDOWN_I,
        FEMB_LDOWN_N   => LDOWN_N,
        POWERING       => CTRL_POWERING_I,
        LUPLED_N       => LUPLED_N
        );

  end generate;

end structure;
--------------------------------------------------------------------------------
-- END OF ARCHITECTURE
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                           E N D   O F   F I L E                            --
--------------------------------------------------------------------------------
