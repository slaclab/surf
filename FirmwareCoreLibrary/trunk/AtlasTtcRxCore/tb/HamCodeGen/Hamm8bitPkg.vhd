LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

PACKAGE Hamm8bitPkg IS
	SUBTYPE parity_ham_8bit IS std_logic_vector(4 DOWNTO 0);
	SUBTYPE data_ham_8bit IS std_logic_vector(7 DOWNTO 0);
	SUBTYPE coded_ham_8bit IS std_logic_vector(12 DOWNTO 0);

	FUNCTION hamming_encoder_8bit(data_in:data_ham_8bit) RETURN parity_ham_8bit;
	PROCEDURE hamming_decoder_8bit(data_parity_in:coded_ham_8bit;
		SIGNAL error_out : OUT std_logic_vector(1 DOWNTO 0);
		SIGNAL decoded : OUT data_ham_8bit);
END Hamm8bitPkg;

PACKAGE BODY Hamm8bitPkg IS

---------------------
-- HAMMING ENCODER --
---------------------
FUNCTION hamming_encoder_8bit(data_in:data_ham_8bit) RETURN parity_ham_8bit  IS
	VARIABLE parity: parity_ham_8bit;
BEGIN

	parity(4)	:=	data_in(4) XOR data_in(5) XOR data_in(6) XOR data_in(7);
   
	parity(3)	:=	data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(7);
   
	parity(2)	:=	data_in(0) XOR data_in(2) XOR data_in(3) XOR data_in(5) XOR data_in(6);
   
					
	parity(1)	:=	data_in(0) XOR data_in(1) XOR data_in(3) XOR data_in(4) XOR data_in(6);
   
					
	parity(0)	:=	data_in(0) XOR data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(4) XOR 
					data_in(5) XOR data_in(6) XOR data_in(7) XOR parity(1) XOR parity(2) XOR 
					parity(3) XOR parity(4) ;


	RETURN parity;
END;

---------------------
-- HAMMING DECODER --
---------------------
PROCEDURE hamming_decoder_8bit(data_parity_in:coded_ham_8bit;
		SIGNAL error_out : OUT std_logic_vector(1 DOWNTO 0);
		SIGNAL decoded   : OUT data_ham_8bit) IS
	VARIABLE coded       : coded_ham_8bit;
	VARIABLE syndrome    : integer RANGE 0 TO 12;
	VARIABLE parity      : parity_ham_8bit;
	VARIABLE parity_in   : parity_ham_8bit;
	VARIABLE syn         : parity_ham_8bit;
	VARIABLE data_in     : data_ham_8bit;
	VARIABLE P0, P1      : std_logic;
BEGIN

	data_in   := data_parity_in(12 DOWNTO 5);
	parity_in := data_parity_in(4 DOWNTO 0);

	parity(4)	:=	data_in(4) XOR data_in(5) XOR data_in(6) XOR data_in(7);
   
	parity(3)	:=	data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(7);
   
	parity(2)	:=	data_in(0) XOR data_in(2) XOR data_in(3) XOR data_in(5) XOR data_in(6);
   
					
	parity(1)	:=	data_in(0) XOR data_in(1) XOR data_in(3) XOR data_in(4) XOR data_in(6);
   
					
	parity(0)	:=	data_in(0) XOR data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(4) XOR 
					data_in(5) XOR data_in(6) XOR data_in(7) XOR parity(1) XOR parity(2) XOR 
					parity(3) XOR parity(4) ;

	coded(0)	:=	data_parity_in(0);
	coded(1)	:=	data_parity_in(1);
	coded(2)	:=	data_parity_in(2);
	coded(4)	:=	data_parity_in(3);
	coded(8)	:=	data_parity_in(4);
	coded(3)	:=	data_parity_in(5);
	coded(5)	:=	data_parity_in(6);
	coded(6)	:=	data_parity_in(7);
	coded(7)	:=	data_parity_in(8);
	coded(9)	:=	data_parity_in(9);
	coded(10)	:=	data_parity_in(10);
	coded(11)	:=	data_parity_in(11);
	coded(12)	:=	data_parity_in(12);

	-- syndorme generation
	syn(4 DOWNTO 1) := parity(4 DOWNTO 1) XOR parity_in(4 DOWNTO 1);
	P0 := '0';
	P1 := '0';
	FOR i IN 0 TO 4 LOOP
		P0 := P0 XOR parity(i);
		P1 := P1 XOR parity_in(i);
	END LOOP;
	syn(0) := P0 XOR P1;

	CASE syn(4 DOWNTO 1) IS
		WHEN "0011" => syndrome := 3;
		WHEN "0101" => syndrome := 5;
		WHEN "0110" => syndrome := 6;
		WHEN "0111" => syndrome := 7;
		WHEN "1001" => syndrome := 9;
		WHEN "1010" => syndrome := 10;
		WHEN "1011" => syndrome := 11;
		WHEN "1100" => syndrome := 12;
		WHEN OTHERS =>  syndrome := 0;
	END CASE;

	IF syn(0) = '1'  THEN
		coded(syndrome) := NOT(coded(syndrome));
		error_out <= "01";    -- There is an error
	ELSIF syndrome/= 0 THEN     -- There are more than one error
		coded := (OTHERS => '0');-- FATAL ERROR
		error_out <= "11";
	ELSE
		error_out <= "00"; -- No errors detected
	END IF;
	decoded(0)	<=	coded(3);
	decoded(1)	<=	coded(5);
	decoded(2)	<=	coded(6);
	decoded(3)	<=	coded(7);
	decoded(4)	<=	coded(9);
	decoded(5)	<=	coded(10);
	decoded(6)	<=	coded(11);
	decoded(7)	<=	coded(12);

END;
END PACKAGE BODY;
