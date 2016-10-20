
---------------------------------------------------------------------------
-- (c) Copyright 2000, 2001, 2002, 2003, 2004, 2008 Xilinx, Inc. All rights reserved.
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
---------------------------------------------------------------------------
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

LIBRARY work;
USE work.Salt7SeriesCore_encode_8b10b_pkg.ALL;

ENTITY Salt7SeriesCore_encode_8b10b_lut_base IS
  GENERIC (
    C_HAS_DISP_IN     :     INTEGER :=0 ;
    C_HAS_FORCE_CODE  :     INTEGER :=0 ;
    C_FORCE_CODE_VAL  :     STRING  :="1010101010" ;
    C_FORCE_CODE_DISP :     INTEGER :=0 ;
    C_HAS_ND          :     INTEGER :=0 ;
    C_HAS_KERR        :     INTEGER :=0
    );
  PORT (
    DIN               : IN  STD_LOGIC_VECTOR(7 DOWNTO 0) :=(OTHERS => '0');
    KIN               : IN  STD_LOGIC                    :='0' ;
    CLK               : IN  STD_LOGIC                    :='0' ;
    DOUT              : OUT STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    CE                : IN  STD_LOGIC                    :='0' ;
    FORCE_CODE        : IN  STD_LOGIC                    :='0' ;
    FORCE_DISP        : IN  STD_LOGIC                    :='0' ;
    DISP_IN           : IN  STD_LOGIC                    :='0' ;
    DISP_OUT          : OUT STD_LOGIC                    :='0' ;
    KERR              : OUT STD_LOGIC                    :='0' ;
    ND                : OUT STD_LOGIC                    :='0'
    );
END Salt7SeriesCore_encode_8b10b_lut_base;

-----------------------------------------------------------------
-- Architecture
-----------------------------------------------------------------
ARCHITECTURE xilinx OF Salt7SeriesCore_encode_8b10b_lut_base IS

-----------------------------------------------------------------
-- Constant Declarations
-----------------------------------------------------------------
  CONSTANT POS     : STD_LOGIC := '1' ;
  CONSTANT NEG     : STD_LOGIC := '0' ;

------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------
  SIGNAL b6         : STD_LOGIC_VECTOR(5 DOWNTO 0) :=(OTHERS => '0');
  SIGNAL b4         : STD_LOGIC_VECTOR(3 DOWNTO 0) :=(OTHERS => '0');
  SIGNAL pdes6      : STD_LOGIC :='0';
  SIGNAL pdes4      : STD_LOGIC :='0';
  SIGNAL k28        : STD_LOGIC :='0';
  SIGNAL l13        : STD_LOGIC :='0';
  SIGNAL l31        : STD_LOGIC :='0';
  SIGNAL a7         : STD_LOGIC :='0';
  SIGNAL disp_in_i  : STD_LOGIC :='0';
  SIGNAL disp_run   : STD_LOGIC :=bint_2_sl(C_FORCE_CODE_DISP);
  SIGNAL kerr_i     : STD_LOGIC :='0' ;

  ALIAS a  : STD_LOGIC IS DIN(0) ;
  ALIAS b  : STD_LOGIC IS DIN(1) ;
  ALIAS c  : STD_LOGIC IS DIN(2) ;
  ALIAS d  : STD_LOGIC IS DIN(3) ;
  ALIAS e  : STD_LOGIC IS DIN(4) ;
  ALIAS b5 : STD_LOGIC_VECTOR(4 DOWNTO 0) IS DIN(4 DOWNTO 0) ;
  ALIAS b3 : STD_LOGIC_VECTOR(2 DOWNTO 0) IS DIN(7 DOWNTO 5) ;

-----------------------------------------------------------------
-- Begin Architecture
-----------------------------------------------------------------
BEGIN

-----------------------------------------------------------------
-- Map internal signals to proper port names
-----------------------------------------------------------------
  DISP_OUT  <= disp_run ;
  KERR      <= kerr_i ;

-------------------------------------------------------------------------------
-- Calculate intermediate terms using notation and logic from 8b/10b spec
-------------------------------------------------------------------------------
  k28 <= boolean_to_std_logic((KIN = '1') AND (b5 = "11100")) ;
  l13 <= (((a XOR b) AND NOT(c OR d)) OR ((c XOR d) AND NOT(a OR b)));
  l31 <= (((a XOR b) AND (c AND d)) OR ((c XOR d) AND (a AND b)));
  a7  <= (KIN OR ((l31 AND D AND NOT(e) AND disp_in_i) OR
                  (l13 AND NOT(d) AND e AND NOT(disp_in_i))));

------------------------------------------------------
-- Check for invalid K codes
------------------------------------------------------
  gke : IF (C_HAS_KERR = 1) GENERATE
    PROCESS (CLK)
    BEGIN
      IF (CLK'event AND CLK = '1') THEN
        IF (CE = '1') THEN
          IF (FORCE_CODE='1') THEN
            kerr_i <= NEG AFTER TFF;
          ELSIF (b5 = "11100") THEN
            kerr_i <= NEG AFTER TFF;
          ELSIF (b3 /= "111") THEN
            kerr_i <= KIN AFTER TFF;
          ELSIF ((b5 /= "10111") AND (b5 /= "11011") AND (b5 /= "11101")
                 AND (b5 /= "11110")) THEN
            kerr_i <= KIN AFTER TFF;
          ELSE
            kerr_i <= NEG AFTER TFF;
          END IF ;
        END IF ;
      END IF;
    END PROCESS;
  END GENERATE gke ;

  ngke : IF (C_HAS_KERR /= 1) GENERATE
    kerr_i <= '0';
  END GENERATE ngke ;

-------------------------------------------------------
--Do the 5B/6B conversion (calculate the 6b symbol)
-------------------------------------------------------
  PROCESS (b5, k28, disp_in_i)
  BEGIN
    IF (k28='1') THEN                     --K.28
      IF (disp_in_i = NEG) THEN
        b6 <= "111100" ;
      ELSE
        b6 <= "000011" ;
      END IF;
    ELSE
      CASE b5 IS
        WHEN "00000" =>                   --D.0
          IF (disp_in_i = POS)
          THEN b6          <= "000110" ;
          ELSE b6          <= "111001" ;
          END IF ;
        WHEN "00001" =>                   --D.1
          IF (disp_in_i = POS)
          THEN b6          <= "010001" ;
          ELSE b6          <= "101110" ;
          END IF ;
        WHEN "00010" =>                   --D.2
          IF (disp_in_i = POS)
          THEN b6          <= "010010" ;
          ELSE b6          <= "101101" ;
          END IF ;
        WHEN "00011" => b6 <= "100011" ;  --D.3
        WHEN "00100" =>                   --D.4
          IF (disp_in_i = POS)
          THEN b6          <= "010100" ;
          ELSE b6          <= "101011" ;
          END IF ;
        WHEN "00101" => b6 <= "100101" ;  --D.5
        WHEN "00110" => b6 <= "100110" ;  --D.6
        WHEN "00111" =>                   --D.7
          IF (disp_in_i = NEG)
          THEN b6          <= "000111" ;
          ELSE b6          <= "111000" ;
          END IF ;
        WHEN "01000" =>                   --D.8
          IF (disp_in_i = POS)
          THEN b6          <= "011000" ;
          ELSE b6          <= "100111" ;
          END IF ;
        WHEN "01001" => b6 <= "101001" ;  --D.9
        WHEN "01010" => b6 <= "101010" ;  --D.10
        WHEN "01011" => b6 <= "001011" ;  --D.11
        WHEN "01100" => b6 <= "101100" ;  --D.12
        WHEN "01101" => b6 <= "001101" ;  --D.13
        WHEN "01110" => b6 <= "001110" ;  --D.14
        WHEN "01111" =>                   --D.15
          IF (disp_in_i = POS)
          THEN b6          <= "000101" ;
          ELSE b6          <= "111010" ;
          END IF ;

        WHEN "10000" =>                   --D.16
          IF (disp_in_i = NEG)
          THEN b6          <= "110110" ;
          ELSE b6          <= "001001" ;
          END IF ;
        WHEN "10001" => b6 <= "110001" ;  --D.17
        WHEN "10010" => b6 <= "110010" ;  --D.18
        WHEN "10011" => b6 <= "010011" ;  --D.19
        WHEN "10100" => b6 <= "110100" ;  --D.20
        WHEN "10101" => b6 <= "010101" ;  --D.21
        WHEN "10110" => b6 <= "010110" ;  --D.22
        WHEN "10111" =>                   --D/K.23
          IF (disp_in_i = NEG)
          THEN b6          <= "010111" ;
          ELSE b6          <= "101000" ;
          END IF ;
        WHEN "11000" =>                   --D.24
          IF (disp_in_i = POS)
          THEN b6          <= "001100" ;
          ELSE b6          <= "110011" ;
          END IF ;
        WHEN "11001" => b6 <= "011001" ;  --D.25
        WHEN "11010" => b6 <= "011010" ;  --D.26
        WHEN "11011" =>                   --D/K.27
          IF (disp_in_i = NEG)
          THEN b6          <= "011011" ;
          ELSE b6          <= "100100" ;
          END IF ;
        WHEN "11100" => b6 <= "011100" ;  --D.28
        WHEN "11101" =>                   --D/K.29
          IF (disp_in_i = NEG)
          THEN b6          <= "011101" ;
          ELSE b6          <= "100010" ;
          END IF ;
        WHEN "11110" =>                   --D/K.30
          IF (disp_in_i = NEG)
          THEN b6          <= "011110" ;
          ELSE b6          <= "100001" ;
          END IF ;
        WHEN "11111" =>                   --D.31
          IF (disp_in_i = NEG)
          THEN b6          <= "110101" ;
          ELSE b6          <= "001010" ;
          END IF ;
        WHEN OTHERS => b6  <= "110101" ;
      END CASE ;
    END IF ;
  END PROCESS ;

-------------------------------------------------------
-- Calculate the running disparity -after- the 6B symbol
-------------------------------------------------------
  PROCESS (b5, k28, disp_in_i)
  BEGIN
    IF (k28='1') THEN
      pdes6                   <= NOT(disp_in_i) ;
    ELSE
      CASE b5 IS
        WHEN "00000" => pdes6 <= NOT(disp_in_i) ;
        WHEN "00001" => pdes6 <= NOT(disp_in_i) ;
        WHEN "00010" => pdes6 <= NOT(disp_in_i) ;
        WHEN "00011" => pdes6 <= disp_in_i ;
        WHEN "00100" => pdes6 <= NOT(disp_in_i) ;
        WHEN "00101" => pdes6 <= disp_in_i ;
        WHEN "00110" => pdes6 <= disp_in_i ;
        WHEN "00111" => pdes6 <= disp_in_i ;

        WHEN "01000" => pdes6 <= NOT(disp_in_i) ;
        WHEN "01001" => pdes6 <= disp_in_i ;
        WHEN "01010" => pdes6 <= disp_in_i ;
        WHEN "01011" => pdes6 <= disp_in_i ;
        WHEN "01100" => pdes6 <= disp_in_i ;
        WHEN "01101" => pdes6 <= disp_in_i ;
        WHEN "01110" => pdes6 <= disp_in_i ;
        WHEN "01111" => pdes6 <= NOT(disp_in_i) ;

        WHEN "10000" => pdes6 <= NOT(disp_in_i) ;
        WHEN "10001" => pdes6 <= disp_in_i ;
        WHEN "10010" => pdes6 <= disp_in_i ;
        WHEN "10011" => pdes6 <= disp_in_i ;
        WHEN "10100" => pdes6 <= disp_in_i ;
        WHEN "10101" => pdes6 <= disp_in_i ;
        WHEN "10110" => pdes6 <= disp_in_i ;
        WHEN "10111" => pdes6 <= NOT(disp_in_i) ;

        WHEN "11000" => pdes6 <= NOT(disp_in_i) ;
        WHEN "11001" => pdes6 <= disp_in_i ;
        WHEN "11010" => pdes6 <= disp_in_i ;
        WHEN "11011" => pdes6 <= NOT(disp_in_i) ;
        WHEN "11100" => pdes6 <= disp_in_i ;
        WHEN "11101" => pdes6 <= NOT(disp_in_i) ;
        WHEN "11110" => pdes6 <= NOT(disp_in_i) ;
        WHEN "11111" => pdes6 <= NOT(disp_in_i) ;
        WHEN OTHERS  => pdes6 <= disp_in_i;
      END CASE ;
    END IF ;
  END PROCESS ;

------------------------------------------------------
-- Do the 3B/4B conversion (calculate the 4b symbol)
------------------------------------------------------
  PROCESS (b3, k28, pdes6, a7)
  BEGIN
    CASE b3 IS
      WHEN "000"  =>                    --D/K.x.0
        IF (pdes6 = POS)
        THEN b4         <= "0010" ;
        ELSE b4         <= "1101" ;
        END IF ;
      WHEN "001"  =>                    --D/K.x.1
        IF ((k28='1') AND (pdes6 = NEG))
        THEN b4         <= "0110" ;
        ELSE b4         <= "1001" ;
        END IF ;
      WHEN "010"  =>                    --D/K.x.2
        IF ((k28='1') AND (pdes6 = NEG))
        THEN b4         <= "0101" ;
        ELSE b4         <= "1010" ;
        END IF ;
      WHEN "011"  =>                    --D/K.x.3
        IF (pdes6 = NEG)
        THEN b4         <= "0011" ;
        ELSE b4         <= "1100" ;
        END IF ;
      WHEN "100"  =>                    --D/K.x.4
        IF (pdes6 = POS)
        THEN b4         <= "0100" ;
        ELSE b4         <= "1011" ;
        END IF ;
      WHEN "101"  =>                    --D/K.x.5
        IF ((k28='1') AND (pdes6 = NEG))
        THEN b4         <= "1010" ;
        ELSE b4         <= "0101" ;
        END IF ;
      WHEN "110"  =>                    --D/K.x.6
        IF ((k28='1') AND (pdes6 = NEG))
        THEN b4         <= "1001" ;
        ELSE b4         <= "0110" ;
        END IF ;
      WHEN "111"  =>                    --D.x.P7
        IF (a7 /= '1') THEN
          IF (pdes6 = NEG)
          THEN b4       <= "0111" ;
          ELSE b4       <= "1000" ;
          END IF ;
        ELSE                            --D/K.y.A7
          IF (pdes6 = NEG)
          THEN b4       <= "1110" ;
          ELSE b4       <= "0001" ;
          END IF ;
        END IF ;
      WHEN OTHERS => b4 <= "0001" ;
    END CASE ;

  END PROCESS ;

-------------------------------------------------------
-- Calculate the running disparity -after- the 4B symbol
-------------------------------------------------------
 PROCESS (b3, pdes6)
  BEGIN
    CASE b3 IS
      WHEN "000"  => pdes4 <= NOT(pdes6) ;
      WHEN "001"  => pdes4 <= pdes6 ;
      WHEN "010"  => pdes4 <= pdes6 ;
      WHEN "011"  => pdes4 <= pdes6 ;
      WHEN "100"  => pdes4 <= NOT(pdes6) ;
      WHEN "101"  => pdes4 <= pdes6 ;
      WHEN "110"  => pdes4 <= pdes6 ;
      WHEN "111"  => pdes4 <= NOT(pdes6) ;
      WHEN OTHERS => pdes4 <= pdes6;
    END CASE ;
  END PROCESS ;

-------------------------------------------------------
-- Update the running disparity on the clock
-------------------------------------------------------
  gdr: IF ((C_HAS_FORCE_CODE = 1) AND (C_FORCE_CODE_DISP = 1)) GENERATE
    PROCESS (CLK)
    BEGIN
      IF (CLK'event AND CLK = '1') THEN
        IF (CE = '1') THEN
          IF (FORCE_CODE = '1') THEN
            disp_run <= '1' AFTER TFF;
          ELSE
            disp_run <= pdes4 AFTER TFF;
          END IF;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE  gdr;

  gdc: IF ((C_HAS_FORCE_CODE = 1) AND (C_FORCE_CODE_DISP = 0)) GENERATE
    PROCESS (CLK)
    BEGIN
      IF (CLK'event AND CLK = '1') THEN
        IF (CE = '1') THEN
          IF (FORCE_CODE = '1') THEN
            disp_run <= '0' AFTER TFF;
          ELSE
            disp_run <= pdes4 AFTER TFF;
          END IF;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE gdc;

  ngdb: IF (C_HAS_FORCE_CODE = 0) GENERATE
    PROCESS (CLK)
    BEGIN
      IF (CLK'event AND CLK = '1') THEN
        IF (CE = '1') THEN
          disp_run <= pdes4 AFTER TFF;
        END IF;
      END IF ;
    END PROCESS;
  END GENERATE  ngdb;

--------------------------------------------------------
-- Override the internal running disparity if FORCE_DISP=1
--------------------------------------------------------
  gpd: IF (C_HAS_DISP_IN = 1) GENERATE
    PROCESS (FORCE_DISP, DISP_IN, disp_run)
    BEGIN
      IF (FORCE_DISP = '1') THEN
        disp_in_i <= DISP_IN ;
      ELSE
        disp_in_i <= disp_run ;
      END IF ;
    END PROCESS ;
  END GENERATE gpd;

  ngpd: IF (C_HAS_DISP_IN=0) GENERATE
    disp_in_i <= disp_run;
  END GENERATE ngpd;

--------------------------------------------------------
-- Update the data output on the clock
--------------------------------------------------------
  PROCESS (CLK)
  BEGIN
    IF (CLK'event AND CLK = '1') THEN
      IF (CE = '1') THEN
        IF (FORCE_CODE = '1') THEN
          DOUT <= str_to_slv(C_FORCE_CODE_VAL, 10) AFTER TFF;
        ELSE
          DOUT <= (b4 & b6) AFTER TFF ;
        END IF ;
      END IF;
    END IF ;
  END PROCESS ;

-------------------------------------------------------
-- Update the ND output on the clock
-------------------------------------------------------
  gnd: IF (C_HAS_ND=1) GENERATE
    PROCESS (CLK)
    BEGIN
      IF  (CLK'event AND CLK = '1') THEN
        IF (FORCE_CODE = '1') THEN
          ND <= '0' AFTER TFF;
        ELSE
          ND <= CE AFTER TFF;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE gnd;
  
 ngnd: IF (C_HAS_ND=0) GENERATE
    PROCESS (CLK)
    BEGIN
      IF  (CLK'event AND CLK = '1') THEN
        ND <= '0' ;
      END IF;
    END PROCESS;
  END GENERATE ngnd;

 END xilinx ;

