LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

PACKAGE Hamm32bitPkg IS
	SUBTYPE parity_ham_32bit IS std_logic_vector(6 DOWNTO 0);
	SUBTYPE data_ham_32bit IS std_logic_vector(31 DOWNTO 0);
	SUBTYPE coded_ham_32bit IS std_logic_vector(38 DOWNTO 0);

	FUNCTION hamming_encoder_32bit(data_in:data_ham_32bit) RETURN parity_ham_32bit;
	PROCEDURE hamming_decoder_32bit(data_parity_in:coded_ham_32bit;
		SIGNAL error_out : OUT std_logic_vector(1 DOWNTO 0);
		SIGNAL decoded : OUT data_ham_32bit);
END Hamm32bitPkg;

PACKAGE BODY Hamm32bitPkg IS

---------------------
-- HAMMING ENCODER --
---------------------
FUNCTION hamming_encoder_32bit(data_in:data_ham_32bit) RETURN parity_ham_32bit  IS
	VARIABLE parity: parity_ham_32bit;
BEGIN

	parity(6)	:=	data_in(26) XOR data_in(27) XOR data_in(28) XOR data_in(29) XOR data_in(30) XOR 
					data_in(31);
   
	parity(5)	:=	data_in(11) XOR data_in(12) XOR data_in(13) XOR data_in(14) XOR data_in(15) XOR 
					data_in(16) XOR data_in(17) XOR data_in(18) XOR data_in(19) XOR data_in(20) XOR 
					data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25);
   
					
	parity(4)	:=	data_in(4) XOR data_in(5) XOR data_in(6) XOR data_in(7) XOR data_in(8) XOR 
					data_in(9) XOR data_in(10) XOR data_in(18) XOR data_in(19) XOR data_in(20) XOR 
					data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25);
   
					
	parity(3)	:=	data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(7) XOR data_in(8) XOR 
					data_in(9) XOR data_in(10) XOR data_in(14) XOR data_in(15) XOR data_in(16) XOR 
					data_in(17) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25) XOR 
					data_in(29) XOR data_in(30) XOR data_in(31);
   
	parity(2)	:=	data_in(0) XOR data_in(2) XOR data_in(3) XOR data_in(5) XOR data_in(6) XOR 
					data_in(9) XOR data_in(10) XOR data_in(12) XOR data_in(13) XOR data_in(16) XOR 
					data_in(17) XOR data_in(20) XOR data_in(21) XOR data_in(24) XOR data_in(25) XOR 
					data_in(27) XOR data_in(28) XOR data_in(31);
   
	parity(1)	:=	data_in(0) XOR data_in(1) XOR data_in(3) XOR data_in(4) XOR data_in(6) XOR 
					data_in(8) XOR data_in(10) XOR data_in(11) XOR data_in(13) XOR data_in(15) XOR 
					data_in(17) XOR data_in(19) XOR data_in(21) XOR data_in(23) XOR data_in(25) XOR 
					data_in(26) XOR data_in(28) XOR data_in(30);
   
	parity(0)	:=	data_in(0) XOR data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(4) XOR 
					data_in(5) XOR data_in(6) XOR data_in(7) XOR data_in(8) XOR data_in(9) XOR 
					data_in(10) XOR data_in(11) XOR data_in(12) XOR data_in(13) XOR data_in(14) XOR 
					data_in(15) XOR data_in(16) XOR data_in(17) XOR data_in(18) XOR data_in(19) XOR 
					data_in(20) XOR data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR 
					data_in(25) XOR data_in(26) XOR data_in(27) XOR data_in(28) XOR data_in(29) XOR 
					data_in(30) XOR data_in(31) XOR parity(1) XOR parity(2) XOR parity(3) XOR 
					parity(4) XOR parity(5) XOR parity(6) ;


	RETURN parity;
END;

---------------------
-- HAMMING DECODER --
---------------------
PROCEDURE hamming_decoder_32bit(data_parity_in:coded_ham_32bit;
		SIGNAL error_out : OUT std_logic_vector(1 DOWNTO 0);
		SIGNAL decoded   : OUT data_ham_32bit) IS
	VARIABLE coded       : coded_ham_32bit;
	VARIABLE syndrome    : integer RANGE 0 TO 38;
	VARIABLE parity      : parity_ham_32bit;
	VARIABLE parity_in   : parity_ham_32bit;
	VARIABLE syn         : parity_ham_32bit;
	VARIABLE data_in     : data_ham_32bit;
	VARIABLE P0, P1      : std_logic;
BEGIN

	data_in   := data_parity_in(38 DOWNTO 7);
	parity_in := data_parity_in(6 DOWNTO 0);

	parity(6)	:=	data_in(26) XOR data_in(27) XOR data_in(28) XOR data_in(29) XOR data_in(30) XOR 
					data_in(31);
   
	parity(5)	:=	data_in(11) XOR data_in(12) XOR data_in(13) XOR data_in(14) XOR data_in(15) XOR 
					data_in(16) XOR data_in(17) XOR data_in(18) XOR data_in(19) XOR data_in(20) XOR 
					data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25);
   
					
	parity(4)	:=	data_in(4) XOR data_in(5) XOR data_in(6) XOR data_in(7) XOR data_in(8) XOR 
					data_in(9) XOR data_in(10) XOR data_in(18) XOR data_in(19) XOR data_in(20) XOR 
					data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25);
   
					
	parity(3)	:=	data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(7) XOR data_in(8) XOR 
					data_in(9) XOR data_in(10) XOR data_in(14) XOR data_in(15) XOR data_in(16) XOR 
					data_in(17) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR data_in(25) XOR 
					data_in(29) XOR data_in(30) XOR data_in(31);
   
	parity(2)	:=	data_in(0) XOR data_in(2) XOR data_in(3) XOR data_in(5) XOR data_in(6) XOR 
					data_in(9) XOR data_in(10) XOR data_in(12) XOR data_in(13) XOR data_in(16) XOR 
					data_in(17) XOR data_in(20) XOR data_in(21) XOR data_in(24) XOR data_in(25) XOR 
					data_in(27) XOR data_in(28) XOR data_in(31);
   
	parity(1)	:=	data_in(0) XOR data_in(1) XOR data_in(3) XOR data_in(4) XOR data_in(6) XOR 
					data_in(8) XOR data_in(10) XOR data_in(11) XOR data_in(13) XOR data_in(15) XOR 
					data_in(17) XOR data_in(19) XOR data_in(21) XOR data_in(23) XOR data_in(25) XOR 
					data_in(26) XOR data_in(28) XOR data_in(30);
   
	parity(0)	:=	data_in(0) XOR data_in(1) XOR data_in(2) XOR data_in(3) XOR data_in(4) XOR 
					data_in(5) XOR data_in(6) XOR data_in(7) XOR data_in(8) XOR data_in(9) XOR 
					data_in(10) XOR data_in(11) XOR data_in(12) XOR data_in(13) XOR data_in(14) XOR 
					data_in(15) XOR data_in(16) XOR data_in(17) XOR data_in(18) XOR data_in(19) XOR 
					data_in(20) XOR data_in(21) XOR data_in(22) XOR data_in(23) XOR data_in(24) XOR 
					data_in(25) XOR data_in(26) XOR data_in(27) XOR data_in(28) XOR data_in(29) XOR 
					data_in(30) XOR data_in(31) XOR parity(1) XOR parity(2) XOR parity(3) XOR 
					parity(4) XOR parity(5) XOR parity(6) ;

	coded(0)	:=	data_parity_in(0);
	coded(1)	:=	data_parity_in(1);
	coded(2)	:=	data_parity_in(2);
	coded(4)	:=	data_parity_in(3);
	coded(8)	:=	data_parity_in(4);
	coded(16)	:=	data_parity_in(5);
	coded(32)	:=	data_parity_in(6);
	coded(3)	:=	data_parity_in(7);
	coded(5)	:=	data_parity_in(8);
	coded(6)	:=	data_parity_in(9);
	coded(7)	:=	data_parity_in(10);
	coded(9)	:=	data_parity_in(11);
	coded(10)	:=	data_parity_in(12);
	coded(11)	:=	data_parity_in(13);
	coded(12)	:=	data_parity_in(14);
	coded(13)	:=	data_parity_in(15);
	coded(14)	:=	data_parity_in(16);
	coded(15)	:=	data_parity_in(17);
	coded(17)	:=	data_parity_in(18);
	coded(18)	:=	data_parity_in(19);
	coded(19)	:=	data_parity_in(20);
	coded(20)	:=	data_parity_in(21);
	coded(21)	:=	data_parity_in(22);
	coded(22)	:=	data_parity_in(23);
	coded(23)	:=	data_parity_in(24);
	coded(24)	:=	data_parity_in(25);
	coded(25)	:=	data_parity_in(26);
	coded(26)	:=	data_parity_in(27);
	coded(27)	:=	data_parity_in(28);
	coded(28)	:=	data_parity_in(29);
	coded(29)	:=	data_parity_in(30);
	coded(30)	:=	data_parity_in(31);
	coded(31)	:=	data_parity_in(32);
	coded(33)	:=	data_parity_in(33);
	coded(34)	:=	data_parity_in(34);
	coded(35)	:=	data_parity_in(35);
	coded(36)	:=	data_parity_in(36);
	coded(37)	:=	data_parity_in(37);
	coded(38)	:=	data_parity_in(38);

	-- syndorme generation
	syn(6 DOWNTO 1) := parity(6 DOWNTO 1) XOR parity_in(6 DOWNTO 1);
	P0 := '0';
	P1 := '0';
	FOR i IN 0 TO 6 LOOP
		P0 := P0 XOR parity(i);
		P1 := P1 XOR parity_in(i);
	END LOOP;
	syn(0) := P0 XOR P1;

	CASE syn(6 DOWNTO 1) IS
		WHEN "000011" => syndrome := 3;
		WHEN "000101" => syndrome := 5;
		WHEN "000110" => syndrome := 6;
		WHEN "000111" => syndrome := 7;
		WHEN "001001" => syndrome := 9;
		WHEN "001010" => syndrome := 10;
		WHEN "001011" => syndrome := 11;
		WHEN "001100" => syndrome := 12;
		WHEN "001101" => syndrome := 13;
		WHEN "001110" => syndrome := 14;
		WHEN "001111" => syndrome := 15;
		WHEN "010001" => syndrome := 17;
		WHEN "010010" => syndrome := 18;
		WHEN "010011" => syndrome := 19;
		WHEN "010100" => syndrome := 20;
		WHEN "010101" => syndrome := 21;
		WHEN "010110" => syndrome := 22;
		WHEN "010111" => syndrome := 23;
		WHEN "011000" => syndrome := 24;
		WHEN "011001" => syndrome := 25;
		WHEN "011010" => syndrome := 26;
		WHEN "011011" => syndrome := 27;
		WHEN "011100" => syndrome := 28;
		WHEN "011101" => syndrome := 29;
		WHEN "011110" => syndrome := 30;
		WHEN "011111" => syndrome := 31;
		WHEN "100001" => syndrome := 33;
		WHEN "100010" => syndrome := 34;
		WHEN "100011" => syndrome := 35;
		WHEN "100100" => syndrome := 36;
		WHEN "100101" => syndrome := 37;
		WHEN "100110" => syndrome := 38;
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
	decoded(8)	<=	coded(13);
	decoded(9)	<=	coded(14);
	decoded(10)	<=	coded(15);
	decoded(11)	<=	coded(17);
	decoded(12)	<=	coded(18);
	decoded(13)	<=	coded(19);
	decoded(14)	<=	coded(20);
	decoded(15)	<=	coded(21);
	decoded(16)	<=	coded(22);
	decoded(17)	<=	coded(23);
	decoded(18)	<=	coded(24);
	decoded(19)	<=	coded(25);
	decoded(20)	<=	coded(26);
	decoded(21)	<=	coded(27);
	decoded(22)	<=	coded(28);
	decoded(23)	<=	coded(29);
	decoded(24)	<=	coded(30);
	decoded(25)	<=	coded(31);
	decoded(26)	<=	coded(33);
	decoded(27)	<=	coded(34);
	decoded(28)	<=	coded(35);
	decoded(29)	<=	coded(36);
	decoded(30)	<=	coded(37);
	decoded(31)	<=	coded(38);

END;
END PACKAGE BODY;
