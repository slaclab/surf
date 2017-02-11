---------------------------------------------------------------------------
-- (c) Copyright 2000, 2001, 2002, 2003, 2004, 2005, 2008 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-------------------------------------------------------------------------------
--
--  History
--
--  Date        Version   Description
--
--  10/31/2008  1.1       Initial release
--
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;

LIBRARY work;
USE work.SaltUltraScaleCore_decode_8b10b_pkg.ALL;

-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
ENTITY SaltUltraScaleCore_decode_8b10b_lut_base IS
  GENERIC (
    C_HAS_CODE_ERR   : INTEGER := 0;
    C_HAS_DISP_ERR   : INTEGER := 0;
    C_HAS_DISP_IN    : INTEGER := 0;
    C_HAS_ND         : INTEGER := 0;
    C_HAS_SYM_DISP   : INTEGER := 0;
    C_HAS_RUN_DISP   : INTEGER := 0;
    C_SINIT_DOUT     : STRING  := "00000000";
    C_SINIT_KOUT     : INTEGER := 0;
    C_SINIT_RUN_DISP : INTEGER := 0
    );
  PORT (
    CLK              : IN  STD_LOGIC                     := '0';
    DIN              : IN  STD_LOGIC_VECTOR(9 DOWNTO 0)  := (OTHERS => '0');
    DOUT             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  ;
    KOUT             : OUT STD_LOGIC                     ;

    CE               : IN  STD_LOGIC                     := '0';
    DISP_IN          : IN  STD_LOGIC                     := '0';
    SINIT            : IN  STD_LOGIC                     := '0';
    CODE_ERR         : OUT STD_LOGIC                     := '0';
    DISP_ERR         : OUT STD_LOGIC                     := '0';
    ND               : OUT STD_LOGIC                     := '0';
    RUN_DISP         : OUT STD_LOGIC                     ;
    SYM_DISP         : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
    );
END SaltUltraScaleCore_decode_8b10b_lut_base;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
ARCHITECTURE xilinx OF SaltUltraScaleCore_decode_8b10b_lut_base IS

  -----------------------------------------------------------------------------
  -- Type Declarations
  -----------------------------------------------------------------------------
  TYPE disparity IS (neg, pos, zero, invalid, specneg, specpos) ;

  -----------------------------------------------------------------------------
  -- Constant Declarations
  -----------------------------------------------------------------------------
  -- set the default decoder output for invalid codes
  CONSTANT DEFAULTB5 : STD_LOGIC_VECTOR(4 DOWNTO 0) := "11111" ;
  CONSTANT DEFAULTB3 : STD_LOGIC_VECTOR(2 DOWNTO 0) := "111" ;

  -----------------------------------------------------------------------------
  -- Signal Declarations
  -----------------------------------------------------------------------------
  SIGNAL dout_i     : STD_LOGIC_VECTOR(7 DOWNTO 0) :=
                      str_to_slv(C_SINIT_DOUT,8);
  SIGNAL kout_i     : STD_LOGIC                    :=
                      bint_2_sl(C_SINIT_KOUT);
  SIGNAL run_disp_i : STD_LOGIC                    :=
                      bint_2_sl(C_SINIT_RUN_DISP);
  SIGNAL sym_disp_i : STD_LOGIC_VECTOR(1 DOWNTO 0) :=
                      conv_std_logic_vector(C_SINIT_RUN_DISP,2);
  SIGNAL code_err_i : STD_LOGIC                    := '0';

  SIGNAL symrd      : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL b6_disp    : disparity := zero;
  SIGNAL b4_disp    : disparity := zero;

  SIGNAL b5  : STD_LOGIC_VECTOR(4 DOWNTO 0) := DEFAULTB5;
  SIGNAL b3  : STD_LOGIC_VECTOR(7 DOWNTO 5) := DEFAULTB3;
  SIGNAL k   : STD_LOGIC                    := '0';
  SIGNAL k28 : STD_LOGIC                    := '0';

  ALIAS b6   : STD_LOGIC_VECTOR(5 DOWNTO 0) IS DIN(5 DOWNTO 0) ; --iedcba
  ALIAS b4   : STD_LOGIC_VECTOR(3 DOWNTO 0) IS DIN(9 DOWNTO 6) ; --jhgf
  ALIAS a    : STD_LOGIC IS DIN(0) ;
  ALIAS b    : STD_LOGIC IS DIN(1) ;
  ALIAS c    : STD_LOGIC IS DIN(2) ;
  ALIAS d    : STD_LOGIC IS DIN(3) ;
  ALIAS e    : STD_LOGIC IS DIN(4) ;
  ALIAS i    : STD_LOGIC IS DIN(5) ;
  ALIAS f    : STD_LOGIC IS DIN(6) ;
  ALIAS g    : STD_LOGIC IS DIN(7) ;
  ALIAS h    : STD_LOGIC IS DIN(8) ;
  ALIAS j    : STD_LOGIC IS DIN(9) ;

--Signals for calculating code_error
  SIGNAL p04     : STD_LOGIC := '0';
  SIGNAL p13     : STD_LOGIC := '0';
  SIGNAL p22     : STD_LOGIC := '0';
  SIGNAL p31     : STD_LOGIC := '0';
  SIGNAL p40     : STD_LOGIC := '0';
  SIGNAL fghj    : STD_LOGIC := '0';
  SIGNAL eifgh   : STD_LOGIC := '0';
  SIGNAL sK28    : STD_LOGIC := '0';
  SIGNAL e_i     : STD_LOGIC := '0';
  SIGNAL ighj    : STD_LOGIC := '0';
  SIGNAL i_ghj   : STD_LOGIC := '0';
  SIGNAL kx7     : STD_LOGIC := '0';
  SIGNAL invr6   : STD_LOGIC := '0';
  SIGNAL pdbr6   : STD_LOGIC := '0';
  SIGNAL ndbr6   : STD_LOGIC := '0';
  SIGNAL pdur6   : STD_LOGIC := '0';
  SIGNAL pdbr4   : STD_LOGIC := '0';
  SIGNAL ndrr4   : STD_LOGIC := '0';
  SIGNAL ndur6   : STD_LOGIC := '0';
  SIGNAL ndbr4   : STD_LOGIC := '0';
  SIGNAL pdrr4   : STD_LOGIC := '0';
  SIGNAL fgh     : STD_LOGIC := '0';
  SIGNAL invby_a : STD_LOGIC := '0';
  SIGNAL invby_b : STD_LOGIC := '0';
  SIGNAL invby_c : STD_LOGIC := '0';
  SIGNAL invby_d : STD_LOGIC := '0';
  SIGNAL invby_e : STD_LOGIC := '0';
  SIGNAL invby_f : STD_LOGIC := '0';
  SIGNAL invby_g : STD_LOGIC := '0';
  SIGNAL invby_h : STD_LOGIC := '0';


-------------------------------------------------------------------------------
-- Begin Architecture
-------------------------------------------------------------------------------
BEGIN

  -----------------------------------------------------------------------------
  -- Conditionally tie optional ports to internal signals
  -----------------------------------------------------------------------------

  ----New Data-----------------------------------------------------------------
  gnd : IF (C_HAS_ND = 1) GENERATE

        ----Update the New Data output-------------------------------
        PROCESS (CLK)
        BEGIN
          IF (CLK'event AND CLK = '1') THEN
            IF ((CE = '1') AND (SINIT = '1')) THEN
              ND <= '0' AFTER TFF;
            ELSE
              ND <= CE AFTER TFF;
            END IF ;
          END IF ;
        END PROCESS ;

  END GENERATE gnd ;

 ngnd: IF (C_HAS_ND=0) GENERATE
        PROCESS (CLK)
        BEGIN
          IF (CLK'event AND CLK = '1') THEN
            ND <= '0' ;
          END IF ;
        END PROCESS ;
  END GENERATE ngnd;
  ----Code Error---------------------------------------------------------------
  gcerr : IF (C_HAS_CODE_ERR = 1) GENERATE

        ----Update CODE_ERR output-------------------
        PROCESS (CLK)
        BEGIN
          IF (CLK'event AND CLK = '1') THEN
            IF  (CE = '1') THEN
              IF (SINIT = '1') THEN
                CODE_ERR <= '0' AFTER TFF;
              ELSE
                CODE_ERR <= code_err_i AFTER TFF;
              END IF;
            END IF ;
          END IF ;
        END PROCESS ;

  END GENERATE gcerr ;



-- The following code uses notation and logic from the 8b/10b specification

-------------------------------------------------------------------------------
-- Set the value of k28 signal
-------------------------------------------------------------------------------
  k28 <= NOT((c OR d OR e OR i) OR NOT(h XOR j)) ;

-------------------------------------------------------------------------------
-- Do the 6B/5B conversion
-------------------------------------------------------------------------------
  PROCESS (b6)
  BEGIN
    CASE b6 IS
      WHEN "000110" => b5 <= "00000" ;   --D.0
      WHEN "111001" => b5 <= "00000" ;   --D.0
      WHEN "010001" => b5 <= "00001" ;   --D.1
      WHEN "101110" => b5 <= "00001" ;   --D.1
      WHEN "010010" => b5 <= "00010" ;   --D.2
      WHEN "101101" => b5 <= "00010" ;   --D.2
      WHEN "100011" => b5 <= "00011" ;   --D.3
      WHEN "010100" => b5 <= "00100" ;   --D.4
      WHEN "101011" => b5 <= "00100" ;   --D.4
      WHEN "100101" => b5 <= "00101" ;   --D.5
      WHEN "100110" => b5 <= "00110" ;   --D.6
      WHEN "000111" => b5 <= "00111" ;   --D.7
      WHEN "111000" => b5 <= "00111" ;   --D.7
      WHEN "011000" => b5 <= "01000" ;   --D.8
      WHEN "100111" => b5 <= "01000" ;   --D.8
      WHEN "101001" => b5 <= "01001" ;   --D.9
      WHEN "101010" => b5 <= "01010" ;   --D.10
      WHEN "001011" => b5 <= "01011" ;   --D.11
      WHEN "101100" => b5 <= "01100" ;   --D.12
      WHEN "001101" => b5 <= "01101" ;   --D.13
      WHEN "001110" => b5 <= "01110" ;   --D.14
      WHEN "000101" => b5 <= "01111" ;   --D.15
      WHEN "111010" => b5 <= "01111" ;   --D.15

      WHEN "110110" => b5 <= "10000" ;   --D.16
      WHEN "001001" => b5 <= "10000" ;   --D.16
      WHEN "110001" => b5 <= "10001" ;   --D.17
      WHEN "110010" => b5 <= "10010" ;   --D.18
      WHEN "010011" => b5 <= "10011" ;   --D.19
      WHEN "110100" => b5 <= "10100" ;   --D.20
      WHEN "010101" => b5 <= "10101" ;   --D.21
      WHEN "010110" => b5 <= "10110" ;   --D.22
      WHEN "010111" => b5 <= "10111" ;   --D/K.23
      WHEN "101000" => b5 <= "10111" ;   --D/K.23
      WHEN "001100" => b5 <= "11000" ;   --D.24
      WHEN "110011" => b5 <= "11000" ;   --D.24
      WHEN "011001" => b5 <= "11001" ;   --D.25
      WHEN "011010" => b5 <= "11010" ;   --D.26
      WHEN "011011" => b5 <= "11011" ;   --D/K.27
      WHEN "100100" => b5 <= "11011" ;   --D/K.27
      WHEN "011100" => b5 <= "11100" ;   --D.28
      WHEN "111100" => b5 <= "11100" ;   --K.28
      WHEN "000011" => b5 <= "11100" ;   --K.28
      WHEN "011101" => b5 <= "11101" ;   --D/K.29
      WHEN "100010" => b5 <= "11101" ;   --D/K.29
      WHEN "011110" => b5 <= "11110" ;   --D.30
      WHEN "100001" => b5 <= "11110" ;   --D.30
      WHEN "110101" => b5 <= "11111" ;   --D.31
      WHEN "001010" => b5 <= "11111" ;   --D.31
      WHEN OTHERS   => b5 <= DEFAULTB5 ; --CODE VIOLATION!
    END CASE ;
  END PROCESS ;

-------------------------------------------------------------------------------
-- Disparity for the 6B block
-------------------------------------------------------------------------------
  PROCESS (b6)
  BEGIN
    CASE b6 IS
      WHEN "000000" => b6_disp <= neg ;    --invalid ;
      WHEN "000001" => b6_disp <= neg ;    --invalid ;
      WHEN "000010" => b6_disp <= neg ;    --invalid ;
      WHEN "000011" => b6_disp <= neg ;    --K.28
      WHEN "000100" => b6_disp <= neg ;    --invalid ;
      WHEN "000101" => b6_disp <= neg ;    --D.15
      WHEN "000110" => b6_disp <= neg ;    --D.0
      WHEN "000111" => b6_disp <= specneg; --D.7
      WHEN "001000" => b6_disp <= neg ;    --invalid ;
      WHEN "001001" => b6_disp <= neg ;    --D.16
      WHEN "001010" => b6_disp <= neg ;    --D.31
      WHEN "001011" => b6_disp <= zero ;   --D.11
      WHEN "001100" => b6_disp <= neg ;    --D.24
      WHEN "001101" => b6_disp <= zero ;   --D.13
      WHEN "001110" => b6_disp <= zero ;   --D.14
      WHEN "001111" => b6_disp <= pos ;    --invalid ;

      WHEN "010000" => b6_disp <= neg ;    --invalid ;
      WHEN "010001" => b6_disp <= neg ;    --D.1
      WHEN "010010" => b6_disp <= neg ;    --D.2
      WHEN "010011" => b6_disp <= zero ;   --D.19
      WHEN "010100" => b6_disp <= neg ;    --D.4
      WHEN "010101" => b6_disp <= zero ;   --D.21
      WHEN "010110" => b6_disp <= zero ;   --D.22
      WHEN "010111" => b6_disp <= pos ;    --D.23
      WHEN "011000" => b6_disp <= neg ;    --D.8
      WHEN "011001" => b6_disp <= zero ;   --D.25
      WHEN "011010" => b6_disp <= zero ;   --D.26
      WHEN "011011" => b6_disp <= pos ;    --D.27
      WHEN "011100" => b6_disp <= zero ;   --D.28
      WHEN "011101" => b6_disp <= pos ;    --D.29
      WHEN "011110" => b6_disp <= pos ;    --D.30
      WHEN "011111" => b6_disp <= pos ;    --invalid ;

      WHEN "100000" => b6_disp <= neg ;    --invalid ;
      WHEN "100001" => b6_disp <= neg ;    --D.30 ;
      WHEN "100010" => b6_disp <= neg ;    --D.29 ;
      WHEN "100011" => b6_disp <= zero ;   --D.3
      WHEN "100100" => b6_disp <= neg ;    --D.27
      WHEN "100101" => b6_disp <= zero ;   --D.5
      WHEN "100110" => b6_disp <= zero ;   --D.6
      WHEN "100111" => b6_disp <= pos ;    --D.8
      WHEN "101000" => b6_disp <= neg ;    --D.23
      WHEN "101001" => b6_disp <= zero ;   --D.9
      WHEN "101010" => b6_disp <= zero ;   --D.10
      WHEN "101011" => b6_disp <= pos ;    --D.4
      WHEN "101100" => b6_disp <= zero ;   --D.12
      WHEN "101101" => b6_disp <= pos ;    --D.2
      WHEN "101110" => b6_disp <= pos ;    --D.1
      WHEN "101111" => b6_disp <= pos ;    --invalid ;

      WHEN "110000" => b6_disp <= neg ;    --invalid ;
      WHEN "110001" => b6_disp <= zero ;   --D.17
      WHEN "110010" => b6_disp <= zero ;   --D.18
      WHEN "110011" => b6_disp <= pos ;    --D.24
      WHEN "110100" => b6_disp <= zero ;   --D.20
      WHEN "110101" => b6_disp <= pos ;    --D.31
      WHEN "110110" => b6_disp <= pos ;    --D.16
      WHEN "110111" => b6_disp <= pos ;    --invalid ;
      WHEN "111000" => b6_disp <= specpos; --D.7
      WHEN "111001" => b6_disp <= pos ;    --D.0
      WHEN "111010" => b6_disp <= pos ;    --D.15
      WHEN "111011" => b6_disp <= pos ;    --invalid ;
      WHEN "111100" => b6_disp <= pos ;    --K.28
      WHEN "111101" => b6_disp <= pos ;    --invalid ;
      WHEN "111110" => b6_disp <= pos ;    --invalid ;
      WHEN "111111" => b6_disp <= pos ;    --invalid ;

      WHEN OTHERS => b6_disp   <= zero ;
    END CASE ;
  END PROCESS ;

-------------------------------------------------------------------------------
-- Do the 3B/4B conversion
-------------------------------------------------------------------------------
  PROCESS (b4, k28)
  BEGIN
    CASE b4 IS
      WHEN "0010" => b3 <= "000" ;      --D/K.x.0
      WHEN "1101" => b3 <= "000" ;      --D/K.x.0
      WHEN "1001" =>
        IF (k28 = '0')
        THEN b3         <= "001" ;      --D/K.x.1
        ELSE b3         <= "110" ;      --K28.6
        END IF ;
      WHEN "0110" =>
        IF (k28 = '1')
        THEN b3         <= "001" ;      --K.28.1
        ELSE b3         <= "110" ;      --D/K.x.6
        END IF ;
      WHEN "1010" =>
        IF (k28 = '0')
        THEN b3         <= "010" ;      --D/K.x.2
        ELSE b3         <= "101" ;      --K28.5
        END IF ;
      WHEN "0101" =>
        IF (k28 = '1')
        THEN b3         <= "010" ;      --K28.2
        ELSE b3         <= "101" ;      --D/K.x.5
        END IF ;
      WHEN "0011" => b3 <= "011" ;      --D/K.x.3
      WHEN "1100" => b3 <= "011" ;      --D/K.x.3
      WHEN "0100" => b3 <= "100" ;      --D/K.x.4
      WHEN "1011" => b3 <= "100" ;      --D/K.x.4
      WHEN "0111" => b3 <= "111" ;      --D.x.7
      WHEN "1000" => b3 <= "111" ;      --D.x.7
      WHEN "1110" => b3 <= "111" ;      --D/K.x.7
      WHEN "0001" => b3 <= "111" ;      --D/K.x.7
      WHEN OTHERS => b3 <= DEFAULTB3 ;  --CODE VIOLATION!
    END CASE ;
  END PROCESS ;

-------------------------------------------------------------------------------
-- Disparity for the 4B block
-------------------------------------------------------------------------------
  PROCESS (b4)
  BEGIN
    CASE b4 IS
      WHEN "0000" => b4_disp <= neg ;
      WHEN "0001" => b4_disp <= neg ;
      WHEN "0010" => b4_disp <= neg ;
      WHEN "0011" => b4_disp <= specneg;
      WHEN "0100" => b4_disp <= neg ;
      WHEN "0101" => b4_disp <= zero ;
      WHEN "0110" => b4_disp <= zero ;
      WHEN "0111" => b4_disp <= pos ;
      WHEN "1000" => b4_disp <= neg ;
      WHEN "1001" => b4_disp <= zero ;
      WHEN "1010" => b4_disp <= zero ;
      WHEN "1011" => b4_disp <= pos ;
      WHEN "1100" => b4_disp <= specpos;
      WHEN "1101" => b4_disp <= pos ;
      WHEN "1110" => b4_disp <= pos ;
      WHEN "1111" => b4_disp <= pos ;
      WHEN OTHERS => b4_disp <= zero ;
    END CASE ;
  END PROCESS ;

-------------------------------------------------------------------------------
-- Special Code for calculating symrd[3:0]
--
--    +---------+---------+-------+------------+-------+------------+
--    |         |         |                  symrd                  |
--    |         |         |   + Start Disp     |   - Start Disp     |
--    | b6_disp | b4_disp | Error | NewRunDisp | Error | NewRunDisp |
--    +---------+---------+-------+------------+-------+------------+
--    |    +    |    +    |   1   |     1      |   1   |      1     |
--    |    +    |    -    |   1   |     0      |   0   |      0     |
--    |    +    |    0    |   1   |     1      |   0   |      1     |
--    |    -    |    +    |   0   |     1      |   1   |      1     |
--    |    -    |    -    |   1   |     0      |   1   |      0     |
--    |    -    |    0    |   0   |     0      |   1   |      0     |
--    |    0    |    +    |   1   |     1      |   0   |      1     |
--    |    0    |    -    |   0   |     0      |   1   |      0     |
--    |    0    |    0    |   0   |     1      |   0   |      0     |
--    +---------+---------+-------+------------+-------+------------+
--
-------------------------------------------------------------------------------
  PROCESS (b4_disp, b6_disp)
  BEGIN
    CASE b6_disp IS
      WHEN pos =>
        CASE b4_disp IS
          WHEN pos    => symrd(3 DOWNTO 0) <= "1111";
          WHEN neg    => symrd(3 DOWNTO 0) <= "1000";
          WHEN specpos=> symrd(3 DOWNTO 0) <= "1101"; --Ex: D1.3-
          WHEN specneg=> symrd(3 DOWNTO 0) <= "1000";
          WHEN zero   => symrd(3 DOWNTO 0) <= "1101";
          WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
        END CASE;
      WHEN neg =>
        CASE b4_disp IS
          WHEN pos    => symrd(3 DOWNTO 0) <= "0111";
          WHEN neg    => symrd(3 DOWNTO 0) <= "1010";
          WHEN specpos=> symrd(3 DOWNTO 0) <= "0111";
          WHEN specneg=> symrd(3 DOWNTO 0) <= "0010"; --Ex: D1.3+
          WHEN zero   => symrd(3 DOWNTO 0) <= "0010";
          WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
        END CASE;
      WHEN zero =>
        CASE b4_disp IS
          WHEN pos    => symrd(3 DOWNTO 0) <= "1101";
          WHEN neg    => symrd(3 DOWNTO 0) <= "0010";
          WHEN specpos=> symrd(3 DOWNTO 0) <= "0111"; --Ex: D11.3+
          WHEN specneg=> symrd(3 DOWNTO 0) <= "1000"; --Ex: D11.3-
          WHEN zero   => symrd(3 DOWNTO 0) <= "0100";
          WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
        END CASE;
      WHEN specpos =>
        CASE b4_disp IS
          WHEN pos    => symrd(3 DOWNTO 0) <= "1111";
          WHEN neg    => symrd(3 DOWNTO 0) <= "0010"; --Ex: D7.0+
          WHEN specpos=> symrd(3 DOWNTO 0) <= "0111"; --Ex: D7.3+
          WHEN specneg=> symrd(3 DOWNTO 0) <= "1010";
          WHEN zero   => symrd(3 DOWNTO 0) <= "0111"; --Ex: D7.5+
          WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
        END CASE;
      WHEN specneg =>
        CASE b4_disp IS
          WHEN pos    => symrd(3 DOWNTO 0) <= "1101"; --Ex: D7.0-
          WHEN neg    => symrd(3 DOWNTO 0) <= "1010";
          WHEN specpos=> symrd(3 DOWNTO 0) <= "1111";
          WHEN specneg=> symrd(3 DOWNTO 0) <= "1000"; --Ex: D7.3-
          WHEN zero   => symrd(3 DOWNTO 0) <= "1000"; --Ex: D7.5-
          WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
        END CASE;
      WHEN OTHERS => symrd(3 DOWNTO 0) <= "XXXX";
    END CASE;
  END PROCESS;

    -- the new running disparity is calculated from the input disparity
    --  and the disparity of the 10-bit word
    grdi : IF (C_HAS_DISP_IN = 1 AND C_HAS_RUN_DISP=1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event and CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              run_disp_i <= bint_2_sl(C_SINIT_RUN_DISP) AFTER TFF;
            ELSIF (DISP_IN = '1') THEN
              run_disp_i <= symrd(2) AFTER TFF;
            ELSE
              run_disp_i <= symrd(0) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE grdi;

    -- the new running disparity is calculated from the old running disparity
    --  and the disparity of the 10-bit word.  run_disp is also used to
    --  calculate disp_err and sym_disp when disp_in is not present
    grdni : IF (C_HAS_DISP_IN /= 1 AND (C_HAS_RUN_DISP=1 OR
                                        C_HAS_DISP_ERR=1 OR
                                        C_HAS_SYM_DISP=1)) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event and CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              run_disp_i <= bint_2_sl(C_SINIT_RUN_DISP) AFTER TFF;
            ELSIF (run_disp_i = '1') THEN
              run_disp_i <= symrd(2) AFTER TFF;
            ELSE
              run_disp_i <= symrd(0) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE grdni;

  gde : IF (C_HAS_DISP_ERR = 1) GENERATE
    -- the new disparity error is calculated from the old running disparity
    --  and the error information from the 10-bit word
    gdei : IF (C_HAS_DISP_IN = 1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event AND CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              disp_err <= '0' AFTER TFF;
            ELSIF (DISP_IN='1') THEN
              disp_err <= symrd(3) AFTER TFF;
            ELSE
              disp_err <= symrd(1) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE gdei;

    gdeni : IF (C_HAS_DISP_IN /= 1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event AND CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              disp_err <= '0' AFTER TFF;
            ELSIF (run_disp_i='1') THEN
              disp_err <= symrd(3) AFTER TFF;
            ELSE
              disp_err <= symrd(1) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE gdeni;
  END GENERATE gde;

  gsd :  IF (C_HAS_SYM_DISP = 1) GENERATE
    gsdi : IF (C_HAS_DISP_IN = 1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event AND CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              sym_disp_i <= conv_std_logic_vector(C_SINIT_RUN_DISP,2) AFTER TFF;
            ELSIF (DISP_IN='1') THEN
              sym_disp_i <= symrd(3 DOWNTO 2) AFTER TFF;
            ELSE
              sym_disp_i <= symrd(1 DOWNTO 0) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE gsdi;

    gsdni : IF (C_HAS_DISP_IN /= 1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event AND CLK='1') THEN
          IF (CE = '1') THEN
            IF (SINIT = '1') THEN
              sym_disp_i <= conv_std_logic_vector(C_SINIT_RUN_DISP,2) AFTER TFF;
            ELSIF (run_disp_i='1') THEN
              sym_disp_i <= symrd(3 DOWNTO 2) AFTER TFF;
            ELSE
              sym_disp_i <= symrd(1 DOWNTO 0) AFTER TFF;
            END IF;
          END IF;
        END IF;
      END PROCESS;
    END GENERATE gsdni;
  END GENERATE gsd;

  ngsd :  IF (C_HAS_SYM_DISP /= 1) GENERATE
      PROCESS (CLK)
      BEGIN
        IF (CLK'event AND CLK='1') THEN
          sym_disp_i <= (OTHERS => '0') ;
        END IF;
      END PROCESS;
  END GENERATE ngsd;

 -- map internal signals to outputs
  run_disp <= run_disp_i;
  sym_disp <= sym_disp_i;

-------------------------------------------------------------------------------
-- Decode the K codes
-------------------------------------------------------------------------------
  PROCESS (c, d, e, i, g, h, j)
  BEGIN
    k <= (c AND d AND e AND i) OR NOT(c OR d OR e OR i) OR
         ((e XOR i) AND ((i AND g AND h AND j) OR
                         NOT(i OR g OR h OR j))) ;
  END PROCESS ;

-------------------------------------------------------------------------------
-- Update the outputs on the clock
-------------------------------------------------------------------------------
  ----Update DOUT output-------------------
  PROCESS (CLK)
  BEGIN
    IF (CLK'event AND CLK = '1') THEN
      IF (CE = '1') THEN
        IF (SINIT = '1') THEN
          dout_i <= str_to_slv(C_SINIT_DOUT, 8) AFTER TFF ;
        ELSE
          dout_i <= (b3 & b5)  AFTER TFF;
        END IF;
      END IF ;
    END IF ;
  END PROCESS ;
  DOUT <= dout_i;
  ----Update KOUT output-------------------
  PROCESS (CLK)
  BEGIN
    IF (CLK'event AND CLK = '1') THEN
      IF (CE = '1') THEN
        IF (SINIT = '1') THEN
          kout_i <= bint_2_sl(C_SINIT_KOUT) AFTER TFF;
        ELSE
          kout_i <= k  AFTER TFF;
        END IF;
      END IF ;
    END IF ;
  END PROCESS ;
  KOUT <= kout_i;

-------------------------------------------------------------------------------
-- Calculate code_error (uses notation from IBM spec)
-------------------------------------------------------------------------------
  bitcount: PROCESS (DIN)
  BEGIN
    CASE DIN(3 DOWNTO 0) IS
      WHEN "0000" => p04 <= '1';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0001" => p04 <= '0';
                     p13 <= '1';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0010" => p04 <= '0';
                     p13 <= '1';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0011" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0100" => p04 <= '0';
                     p13 <= '1';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0101" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0110" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "0111" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '1';
                     p40 <= '0';
      WHEN "1000" => p04 <= '0';
                     p13 <= '1';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "1001" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "1010" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "1011" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '1';
                     p40 <= '0';
      WHEN "1100" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '1';
                     p31 <= '0';
                     p40 <= '0';
      WHEN "1101" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '1';
                     p40 <= '0';
      WHEN "1110" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '1';
                     p40 <= '0';
      WHEN "1111" => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '1';
      WHEN OTHERS => p04 <= '0';
                     p13 <= '0';
                     p22 <= '0';
                     p31 <= '0';
                     p40 <= '1';

    END CASE;
  END PROCESS bitcount;

  fghj    <= (f AND g AND h AND j) OR (NOT f AND NOT g AND NOT h AND NOT j);
  eifgh   <= (e AND i AND f AND g AND h) OR (NOT e AND NOT i AND NOT f AND NOT g
                                           AND NOT h);
  sk28    <= (c AND d AND e AND i) OR (NOT c AND NOT d AND NOT e AND NOT i);
  e_i     <= (e AND NOT i) OR (NOT e AND i);
  ighj    <= (i AND g AND h AND j) OR (NOT i AND NOT g AND NOT h AND NOT j);
  i_ghj   <= (NOT i AND g AND h AND j) OR (i AND NOT g AND NOT h AND NOT j);
  kx7     <= e_i AND ighj;
  invr6   <= p40 OR p04 OR (p31 AND e AND i) OR (p13 AND NOT e AND NOT i);
  pdbr6   <= (p31 AND (e OR i)) OR (p22 AND e AND i) OR p40;
  ndbr6   <= (p13 AND (NOT e OR NOT i)) OR (p22 AND NOT e AND NOT i) OR p04;
  pdur6   <= pdbr6 OR (d AND e AND i);
  pdbr4   <= (f AND g AND (h OR j)) OR ((f OR g) AND h AND j);
  ndrr4   <= pdbr4 OR (f AND g);
  ndur6   <= ndbr6 OR (NOT d AND NOT e AND NOT i);
  fgh     <= (f AND g AND h) OR (NOT f AND NOT g AND NOT h);
  ndbr4   <= (NOT f AND NOT g AND (NOT h OR NOT j)) OR ((NOT f OR NOT g) AND
                                                        NOT h AND NOT j);
  pdrr4   <= ndbr4 OR (NOT f AND NOT g);

  invby_a <= invr6;
  invby_b <= fghj;
  invby_c <= eifgh;
  invby_d <= (NOT sk28 AND i_ghj);
  invby_e <= (sk28 AND fgh);
  invby_f <= (kx7 AND NOT pdbr6 AND NOT ndbr6);
  invby_g <= (pdur6 AND ndrr4);
  invby_h <= (ndur6 AND pdrr4);

  --Update internal code error signal
  code_err_i <= invby_a OR invby_b OR invby_c OR invby_d OR invby_e OR invby_f OR
                invby_g OR invby_h;

END xilinx ;
