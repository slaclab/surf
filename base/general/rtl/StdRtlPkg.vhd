-------------------------------------------------------------------------------
-- File       : StdRtlPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-01
-------------------------------------------------------------------------------
-- Description: Standard RTL Package File
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

package StdRtlPkg is

   -- Useful for pre compiler
   constant IN_SIMULATION_C : boolean := false
-- pragma translate_off
   or true
-- pragma translate_on
   ;
   constant IN_SYNTHESIS_C : boolean := not(IN_SIMULATION_C);

   -- Typing std_logic(_vector) is annoying
   subtype sl is std_logic;
   subtype slv is std_logic_vector;
    
   -- Declare arrays of built in types
   --type SlvArray     is array (natural range <>) of slv;   -- not supported in VCS yet (14APRIL2014 -- LLR)
   type IntegerArray  is array (natural range <>) of integer;
   type NaturalArray  is array (natural range <>) of natural;
   type PositiveArray is array (natural range <>) of positive;
   type RealArray     is array (natural range <>) of real;
   type TimeArray     is array (natural range <>) of time;
   type BooleanArray  is array (natural range <>) of boolean;
   
   -- Declare vector arrays of built in types
   --type SlvVectorArray     is array (natural range<>, natural range<>) of slv;   -- not supported in VCS yet (14APRIL2014 -- LLR)
   type IntegerVectorArray  is array (natural range<>, natural range<>) of integer;
   type NaturalVectorArray  is array (natural range<>, natural range<>) of natural;
   type PositiveVectorArray is array (natural range<>, natural range<>) of positive;
   type RealVectorArray     is array (natural range<>, natural range<>) of real;
   type TimeVectorArray     is array (natural range<>, natural range<>) of time;
   type BooleanVectorArray  is array (natural range<>, natural range<>) of boolean;   

   -- Create an arbitrary sized slv with all bits set high or low
   function slvAll (size  : positive; value : sl) return slv;
   function slvZero (size : positive) return slv;
   function slvOne (size  : positive) return slv;

   -- Very useful functions
   function isPowerOf2 (number       : natural) return boolean;
   function isPowerOf2 (vector       : slv) return boolean;
   function log2 (constant number    : integer) return natural;
   function bitSize (constant number : natural) return positive;
   function bitReverse (a            : slv) return slv;
   function wordCount (number : positive; wordSize : positive := 8) return natural; 

   -- Similar to python's range() function
   function list (constant start, size, step : integer) return IntegerArray;

   -- Simple decoder and mux functions
   function decode(v    : slv) return slv;
   function genmux(s, v : slv) return sl;

   -- This should be unnecessary in VHDL 2008
   function toBoolean (logic : sl) return boolean;
   function toSl (bool       : boolean) return sl;
   function toString (bool   : boolean) return string;
   function toBoolean (str   : string) return boolean;
   function toSlv(bools : BooleanArray) return slv;

   -- Unary reduction operators, also unnecessary in VHDL 2008
   function uOr (vec  : slv) return sl;
   function uAnd (vec : slv) return sl;
   function uXor (vec : slv) return sl;

   -- Test if all bits in a vector are set to a given logic value
   function allBits (vec : slv; test : sl) return boolean;
   function noBits (vec  : slv; test : sl) return boolean;

   -- These just use uXor to calculate parity
   -- Output is parity bit value needed to achieve that parity given vec.
   function evenParity (vec : slv) return sl;
   function oddParity (vec  : slv) return sl;
  
   -- Functions for counting the number of '1' in a slv bus
   function onesCountU (vec : slv) return unsigned;
   function onesCount (vec : slv) return slv;   

   -- Gray Code functions
   function grayEncode (vec : unsigned) return unsigned;
   function grayEncode (vec : slv) return slv;
   function grayDecode (vec : unsigned) return unsigned;
   function grayDecode (vec : slv) return slv;

   -- Linear Feedback Shift Register function
   function lfsrShift (lfsr : slv; constant taps : NaturalArray; input : sl := '0') return slv;

   function maximum (left, right : integer) return integer;
   function maximum (a : IntegerArray) return integer;
   function minimum (left, right : integer) return integer;
   function minimum (a : IntegerArray) return integer;

   -- One line if-then-else functions. Useful for assigning constants based on generics.
   function ite(i : boolean; t : boolean; e : boolean) return boolean;
   function ite(i : boolean; t : sl; e : sl) return sl;
   function ite(i : boolean; t : slv; e : slv) return slv;
   function ite(i : boolean; t : bit; e : bit) return bit;
   function ite(i : boolean; t : bit_vector; e : bit_vector) return bit_vector;
   function ite(i : boolean; t : character; e : character) return character;
   function ite(i : boolean; t : string; e : string) return string;
   function ite(i : boolean; t : integer; e : integer) return integer;
   function ite(i : boolean; t : real; e : real) return real;
   function ite(i : boolean; t : time; e : time) return time;

   -- conv_std_logic_vector functions
   function toSlv(ARG : integer; SIZE : integer) return slv;

   -- gets real multiplication and division with integers
   function "*" (L    : integer; R : real) return real;
   function "*" (L    : real; R : integer) return real;
   function "/" (L    : integer; R : real) return real;
   function "/" (L    : real; R : integer) return real;

   function adcConversion (ain : real; low : real; high : real; bits : positive; twosComp : boolean) return slv;

   --gets a time ratio
   function getTimeRatio (T1, T2 : time) return natural;  --not supported by Vivado
   function getTimeRatio (T1, T2 : real) return natural;

   procedure assignSlv    (i : inout integer; vector : inout slv; value  : in    slv);
   procedure assignSlv    (i : inout integer; vector : inout slv; value  : in    sl);
   procedure assignRecord (i : inout integer; vector : in    slv; value  : inout slv);
   procedure assignRecord (i : inout integer; vector : in    slv; value  : inout sl);   

   -- Resize vector types, either by trimming or padding upper indicies
   function resize (vec : slv; newSize : integer; pad : sl := '0') return slv;
   function resize (str : string; newSize : integer; pad : character := nul) return string;
   
   -- Some synthesis tools wont accept unit types
   -- pragma translate_off
   type frequency is range 0 to 2147483647
      units
         Hz;
         kHz = 1000 Hz;
         MHz = 1000 kHz;
         GHz = 1000 MHz;
      end units;

   function toTime(f : frequency) return time;
   -- pragma translate_on   

   -- Add more slv array sizes here as they become needed
   type Slv256Array is array (natural range <>) of slv(255 downto 0);
   type Slv255Array is array (natural range <>) of slv(254 downto 0);
   type Slv254Array is array (natural range <>) of slv(253 downto 0);
   type Slv253Array is array (natural range <>) of slv(252 downto 0);
   type Slv252Array is array (natural range <>) of slv(251 downto 0);
   type Slv251Array is array (natural range <>) of slv(250 downto 0);
   type Slv250Array is array (natural range <>) of slv(249 downto 0);
   type Slv249Array is array (natural range <>) of slv(248 downto 0);
   type Slv248Array is array (natural range <>) of slv(247 downto 0);
   type Slv247Array is array (natural range <>) of slv(246 downto 0);
   type Slv246Array is array (natural range <>) of slv(245 downto 0);
   type Slv245Array is array (natural range <>) of slv(244 downto 0);
   type Slv244Array is array (natural range <>) of slv(243 downto 0);
   type Slv243Array is array (natural range <>) of slv(242 downto 0);
   type Slv242Array is array (natural range <>) of slv(241 downto 0);
   type Slv241Array is array (natural range <>) of slv(240 downto 0);
   type Slv240Array is array (natural range <>) of slv(239 downto 0);
   type Slv239Array is array (natural range <>) of slv(238 downto 0);
   type Slv238Array is array (natural range <>) of slv(237 downto 0);
   type Slv237Array is array (natural range <>) of slv(236 downto 0);
   type Slv236Array is array (natural range <>) of slv(235 downto 0);
   type Slv235Array is array (natural range <>) of slv(234 downto 0);
   type Slv234Array is array (natural range <>) of slv(233 downto 0);
   type Slv233Array is array (natural range <>) of slv(232 downto 0);
   type Slv232Array is array (natural range <>) of slv(231 downto 0);
   type Slv231Array is array (natural range <>) of slv(230 downto 0);
   type Slv230Array is array (natural range <>) of slv(229 downto 0);
   type Slv229Array is array (natural range <>) of slv(228 downto 0);
   type Slv228Array is array (natural range <>) of slv(227 downto 0);
   type Slv227Array is array (natural range <>) of slv(226 downto 0);
   type Slv226Array is array (natural range <>) of slv(225 downto 0);
   type Slv225Array is array (natural range <>) of slv(224 downto 0);
   type Slv224Array is array (natural range <>) of slv(223 downto 0);
   type Slv223Array is array (natural range <>) of slv(222 downto 0);
   type Slv222Array is array (natural range <>) of slv(221 downto 0);
   type Slv221Array is array (natural range <>) of slv(220 downto 0);
   type Slv220Array is array (natural range <>) of slv(219 downto 0);
   type Slv219Array is array (natural range <>) of slv(218 downto 0);
   type Slv218Array is array (natural range <>) of slv(217 downto 0);
   type Slv217Array is array (natural range <>) of slv(216 downto 0);
   type Slv216Array is array (natural range <>) of slv(215 downto 0);
   type Slv215Array is array (natural range <>) of slv(214 downto 0);
   type Slv214Array is array (natural range <>) of slv(213 downto 0);
   type Slv213Array is array (natural range <>) of slv(212 downto 0);
   type Slv212Array is array (natural range <>) of slv(211 downto 0);
   type Slv211Array is array (natural range <>) of slv(210 downto 0);
   type Slv210Array is array (natural range <>) of slv(209 downto 0);
   type Slv209Array is array (natural range <>) of slv(208 downto 0);
   type Slv208Array is array (natural range <>) of slv(207 downto 0);
   type Slv207Array is array (natural range <>) of slv(206 downto 0);
   type Slv206Array is array (natural range <>) of slv(205 downto 0);
   type Slv205Array is array (natural range <>) of slv(204 downto 0);
   type Slv204Array is array (natural range <>) of slv(203 downto 0);
   type Slv203Array is array (natural range <>) of slv(202 downto 0);
   type Slv202Array is array (natural range <>) of slv(201 downto 0);
   type Slv201Array is array (natural range <>) of slv(200 downto 0);
   type Slv200Array is array (natural range <>) of slv(199 downto 0);
   type Slv199Array is array (natural range <>) of slv(198 downto 0);
   type Slv198Array is array (natural range <>) of slv(197 downto 0);
   type Slv197Array is array (natural range <>) of slv(196 downto 0);
   type Slv196Array is array (natural range <>) of slv(195 downto 0);
   type Slv195Array is array (natural range <>) of slv(194 downto 0);
   type Slv194Array is array (natural range <>) of slv(193 downto 0);
   type Slv193Array is array (natural range <>) of slv(192 downto 0);
   type Slv192Array is array (natural range <>) of slv(191 downto 0);
   type Slv191Array is array (natural range <>) of slv(190 downto 0);
   type Slv190Array is array (natural range <>) of slv(189 downto 0);
   type Slv189Array is array (natural range <>) of slv(188 downto 0);
   type Slv188Array is array (natural range <>) of slv(187 downto 0);
   type Slv187Array is array (natural range <>) of slv(186 downto 0);
   type Slv186Array is array (natural range <>) of slv(185 downto 0);
   type Slv185Array is array (natural range <>) of slv(184 downto 0);
   type Slv184Array is array (natural range <>) of slv(183 downto 0);
   type Slv183Array is array (natural range <>) of slv(182 downto 0);
   type Slv182Array is array (natural range <>) of slv(181 downto 0);
   type Slv181Array is array (natural range <>) of slv(180 downto 0);
   type Slv180Array is array (natural range <>) of slv(179 downto 0);
   type Slv179Array is array (natural range <>) of slv(178 downto 0);
   type Slv178Array is array (natural range <>) of slv(177 downto 0);
   type Slv177Array is array (natural range <>) of slv(176 downto 0);
   type Slv176Array is array (natural range <>) of slv(175 downto 0);
   type Slv175Array is array (natural range <>) of slv(174 downto 0);
   type Slv174Array is array (natural range <>) of slv(173 downto 0);
   type Slv173Array is array (natural range <>) of slv(172 downto 0);
   type Slv172Array is array (natural range <>) of slv(171 downto 0);
   type Slv171Array is array (natural range <>) of slv(170 downto 0);
   type Slv170Array is array (natural range <>) of slv(169 downto 0);
   type Slv169Array is array (natural range <>) of slv(168 downto 0);
   type Slv168Array is array (natural range <>) of slv(167 downto 0);
   type Slv167Array is array (natural range <>) of slv(166 downto 0);
   type Slv166Array is array (natural range <>) of slv(165 downto 0);
   type Slv165Array is array (natural range <>) of slv(164 downto 0);
   type Slv164Array is array (natural range <>) of slv(163 downto 0);
   type Slv163Array is array (natural range <>) of slv(162 downto 0);
   type Slv162Array is array (natural range <>) of slv(161 downto 0);
   type Slv161Array is array (natural range <>) of slv(160 downto 0);
   type Slv160Array is array (natural range <>) of slv(159 downto 0);
   type Slv159Array is array (natural range <>) of slv(158 downto 0);
   type Slv158Array is array (natural range <>) of slv(157 downto 0);
   type Slv157Array is array (natural range <>) of slv(156 downto 0);
   type Slv156Array is array (natural range <>) of slv(155 downto 0);
   type Slv155Array is array (natural range <>) of slv(154 downto 0);
   type Slv154Array is array (natural range <>) of slv(153 downto 0);
   type Slv153Array is array (natural range <>) of slv(152 downto 0);
   type Slv152Array is array (natural range <>) of slv(151 downto 0);
   type Slv151Array is array (natural range <>) of slv(150 downto 0);
   type Slv150Array is array (natural range <>) of slv(149 downto 0);
   type Slv149Array is array (natural range <>) of slv(148 downto 0);
   type Slv148Array is array (natural range <>) of slv(147 downto 0);
   type Slv147Array is array (natural range <>) of slv(146 downto 0);
   type Slv146Array is array (natural range <>) of slv(145 downto 0);
   type Slv145Array is array (natural range <>) of slv(144 downto 0);
   type Slv144Array is array (natural range <>) of slv(143 downto 0);
   type Slv143Array is array (natural range <>) of slv(142 downto 0);
   type Slv142Array is array (natural range <>) of slv(141 downto 0);
   type Slv141Array is array (natural range <>) of slv(140 downto 0);
   type Slv140Array is array (natural range <>) of slv(139 downto 0);
   type Slv139Array is array (natural range <>) of slv(138 downto 0);
   type Slv138Array is array (natural range <>) of slv(137 downto 0);
   type Slv137Array is array (natural range <>) of slv(136 downto 0);
   type Slv136Array is array (natural range <>) of slv(135 downto 0);
   type Slv135Array is array (natural range <>) of slv(134 downto 0);
   type Slv134Array is array (natural range <>) of slv(133 downto 0);
   type Slv133Array is array (natural range <>) of slv(132 downto 0);
   type Slv132Array is array (natural range <>) of slv(131 downto 0);
   type Slv131Array is array (natural range <>) of slv(130 downto 0);
   type Slv130Array is array (natural range <>) of slv(129 downto 0);
   type Slv129Array is array (natural range <>) of slv(128 downto 0);
   type Slv128Array is array (natural range <>) of slv(127 downto 0);
   type Slv127Array is array (natural range <>) of slv(126 downto 0);
   type Slv126Array is array (natural range <>) of slv(125 downto 0);
   type Slv125Array is array (natural range <>) of slv(124 downto 0);
   type Slv124Array is array (natural range <>) of slv(123 downto 0);
   type Slv123Array is array (natural range <>) of slv(122 downto 0);
   type Slv122Array is array (natural range <>) of slv(121 downto 0);
   type Slv121Array is array (natural range <>) of slv(120 downto 0);
   type Slv120Array is array (natural range <>) of slv(119 downto 0);
   type Slv119Array is array (natural range <>) of slv(118 downto 0);
   type Slv118Array is array (natural range <>) of slv(117 downto 0);
   type Slv117Array is array (natural range <>) of slv(116 downto 0);
   type Slv116Array is array (natural range <>) of slv(115 downto 0);
   type Slv115Array is array (natural range <>) of slv(114 downto 0);
   type Slv114Array is array (natural range <>) of slv(113 downto 0);
   type Slv113Array is array (natural range <>) of slv(112 downto 0);
   type Slv112Array is array (natural range <>) of slv(111 downto 0);
   type Slv111Array is array (natural range <>) of slv(110 downto 0);
   type Slv110Array is array (natural range <>) of slv(109 downto 0);
   type Slv109Array is array (natural range <>) of slv(108 downto 0);
   type Slv108Array is array (natural range <>) of slv(107 downto 0);
   type Slv107Array is array (natural range <>) of slv(106 downto 0);
   type Slv106Array is array (natural range <>) of slv(105 downto 0);
   type Slv105Array is array (natural range <>) of slv(104 downto 0);
   type Slv104Array is array (natural range <>) of slv(103 downto 0);
   type Slv103Array is array (natural range <>) of slv(102 downto 0);
   type Slv102Array is array (natural range <>) of slv(101 downto 0);
   type Slv101Array is array (natural range <>) of slv(100 downto 0);
   type Slv100Array is array (natural range <>) of slv(99 downto 0);
   type Slv99Array is array (natural range <>) of slv(98 downto 0);
   type Slv98Array is array (natural range <>) of slv(97 downto 0);
   type Slv97Array is array (natural range <>) of slv(96 downto 0);
   type Slv96Array is array (natural range <>) of slv(95 downto 0);
   type Slv95Array is array (natural range <>) of slv(94 downto 0);
   type Slv94Array is array (natural range <>) of slv(93 downto 0);
   type Slv93Array is array (natural range <>) of slv(92 downto 0);
   type Slv92Array is array (natural range <>) of slv(91 downto 0);
   type Slv91Array is array (natural range <>) of slv(90 downto 0);
   type Slv90Array is array (natural range <>) of slv(89 downto 0);
   type Slv89Array is array (natural range <>) of slv(88 downto 0);
   type Slv88Array is array (natural range <>) of slv(87 downto 0);
   type Slv87Array is array (natural range <>) of slv(86 downto 0);
   type Slv86Array is array (natural range <>) of slv(85 downto 0);
   type Slv85Array is array (natural range <>) of slv(84 downto 0);
   type Slv84Array is array (natural range <>) of slv(83 downto 0);
   type Slv83Array is array (natural range <>) of slv(82 downto 0);
   type Slv82Array is array (natural range <>) of slv(81 downto 0);
   type Slv81Array is array (natural range <>) of slv(80 downto 0);
   type Slv80Array is array (natural range <>) of slv(79 downto 0);
   type Slv79Array is array (natural range <>) of slv(78 downto 0);
   type Slv78Array is array (natural range <>) of slv(77 downto 0);
   type Slv77Array is array (natural range <>) of slv(76 downto 0);
   type Slv76Array is array (natural range <>) of slv(75 downto 0);
   type Slv75Array is array (natural range <>) of slv(74 downto 0);
   type Slv74Array is array (natural range <>) of slv(73 downto 0);
   type Slv73Array is array (natural range <>) of slv(72 downto 0);
   type Slv72Array is array (natural range <>) of slv(71 downto 0);
   type Slv71Array is array (natural range <>) of slv(70 downto 0);
   type Slv70Array is array (natural range <>) of slv(69 downto 0);
   type Slv69Array is array (natural range <>) of slv(68 downto 0);
   type Slv68Array is array (natural range <>) of slv(67 downto 0);
   type Slv67Array is array (natural range <>) of slv(66 downto 0);
   type Slv66Array is array (natural range <>) of slv(65 downto 0);
   type Slv65Array is array (natural range <>) of slv(64 downto 0);
   type Slv64Array is array (natural range <>) of slv(63 downto 0);
   type Slv63Array is array (natural range <>) of slv(62 downto 0);
   type Slv62Array is array (natural range <>) of slv(61 downto 0);
   type Slv61Array is array (natural range <>) of slv(60 downto 0);
   type Slv60Array is array (natural range <>) of slv(59 downto 0);
   type Slv59Array is array (natural range <>) of slv(58 downto 0);
   type Slv58Array is array (natural range <>) of slv(57 downto 0);
   type Slv57Array is array (natural range <>) of slv(56 downto 0);
   type Slv56Array is array (natural range <>) of slv(55 downto 0);
   type Slv55Array is array (natural range <>) of slv(54 downto 0);
   type Slv54Array is array (natural range <>) of slv(53 downto 0);
   type Slv53Array is array (natural range <>) of slv(52 downto 0);
   type Slv52Array is array (natural range <>) of slv(51 downto 0);
   type Slv51Array is array (natural range <>) of slv(50 downto 0);
   type Slv50Array is array (natural range <>) of slv(49 downto 0);
   type Slv49Array is array (natural range <>) of slv(48 downto 0);
   type Slv48Array is array (natural range <>) of slv(47 downto 0);
   type Slv47Array is array (natural range <>) of slv(46 downto 0);
   type Slv46Array is array (natural range <>) of slv(45 downto 0);
   type Slv45Array is array (natural range <>) of slv(44 downto 0);
   type Slv44Array is array (natural range <>) of slv(43 downto 0);
   type Slv43Array is array (natural range <>) of slv(42 downto 0);
   type Slv42Array is array (natural range <>) of slv(41 downto 0);
   type Slv41Array is array (natural range <>) of slv(40 downto 0);
   type Slv40Array is array (natural range <>) of slv(39 downto 0);
   type Slv39Array is array (natural range <>) of slv(38 downto 0);
   type Slv38Array is array (natural range <>) of slv(37 downto 0);
   type Slv37Array is array (natural range <>) of slv(36 downto 0);
   type Slv36Array is array (natural range <>) of slv(35 downto 0);
   type Slv35Array is array (natural range <>) of slv(34 downto 0);
   type Slv34Array is array (natural range <>) of slv(33 downto 0);
   type Slv33Array is array (natural range <>) of slv(32 downto 0);
   type Slv32Array is array (natural range <>) of slv(31 downto 0);
   type Slv31Array is array (natural range <>) of slv(30 downto 0);
   type Slv30Array is array (natural range <>) of slv(29 downto 0);
   type Slv29Array is array (natural range <>) of slv(28 downto 0);
   type Slv28Array is array (natural range <>) of slv(27 downto 0);
   type Slv27Array is array (natural range <>) of slv(26 downto 0);
   type Slv26Array is array (natural range <>) of slv(25 downto 0);
   type Slv25Array is array (natural range <>) of slv(24 downto 0);
   type Slv24Array is array (natural range <>) of slv(23 downto 0);
   type Slv23Array is array (natural range <>) of slv(22 downto 0);
   type Slv22Array is array (natural range <>) of slv(21 downto 0);
   type Slv21Array is array (natural range <>) of slv(20 downto 0);
   type Slv20Array is array (natural range <>) of slv(19 downto 0);
   type Slv19Array is array (natural range <>) of slv(18 downto 0);
   type Slv18Array is array (natural range <>) of slv(17 downto 0);
   type Slv17Array is array (natural range <>) of slv(16 downto 0);
   type Slv16Array is array (natural range <>) of slv(15 downto 0);
   type Slv15Array is array (natural range <>) of slv(14 downto 0);
   type Slv14Array is array (natural range <>) of slv(13 downto 0);
   type Slv13Array is array (natural range <>) of slv(12 downto 0);
   type Slv12Array is array (natural range <>) of slv(11 downto 0);
   type Slv11Array is array (natural range <>) of slv(10 downto 0);
   type Slv10Array is array (natural range <>) of slv(9 downto 0);
   type Slv9Array is array (natural range <>) of slv(8 downto 0);
   type Slv8Array is array (natural range <>) of slv(7 downto 0);
   type Slv7Array is array (natural range <>) of slv(6 downto 0);
   type Slv6Array is array (natural range <>) of slv(5 downto 0);
   type Slv5Array is array (natural range <>) of slv(4 downto 0);
   type Slv4Array is array (natural range <>) of slv(3 downto 0);
   type Slv3Array is array (natural range <>) of slv(2 downto 0);
   type Slv2Array is array (natural range <>) of slv(1 downto 0);
   type Slv1Array is array (natural range <>) of slv(0 downto 0);

   -- Add more slv vector array sizes here as they become needed
   type Slv256VectorArray is array (natural range<>, natural range<>) of slv(255 downto 0);
   type Slv255VectorArray is array (natural range<>, natural range<>) of slv(254 downto 0);
   type Slv254VectorArray is array (natural range<>, natural range<>) of slv(253 downto 0);
   type Slv253VectorArray is array (natural range<>, natural range<>) of slv(252 downto 0);
   type Slv252VectorArray is array (natural range<>, natural range<>) of slv(251 downto 0);
   type Slv251VectorArray is array (natural range<>, natural range<>) of slv(250 downto 0);
   type Slv250VectorArray is array (natural range<>, natural range<>) of slv(249 downto 0);
   type Slv249VectorArray is array (natural range<>, natural range<>) of slv(248 downto 0);
   type Slv248VectorArray is array (natural range<>, natural range<>) of slv(247 downto 0);
   type Slv247VectorArray is array (natural range<>, natural range<>) of slv(246 downto 0);
   type Slv246VectorArray is array (natural range<>, natural range<>) of slv(245 downto 0);
   type Slv245VectorArray is array (natural range<>, natural range<>) of slv(244 downto 0);
   type Slv244VectorArray is array (natural range<>, natural range<>) of slv(243 downto 0);
   type Slv243VectorArray is array (natural range<>, natural range<>) of slv(242 downto 0);
   type Slv242VectorArray is array (natural range<>, natural range<>) of slv(241 downto 0);
   type Slv241VectorArray is array (natural range<>, natural range<>) of slv(240 downto 0);
   type Slv240VectorArray is array (natural range<>, natural range<>) of slv(239 downto 0);
   type Slv239VectorArray is array (natural range<>, natural range<>) of slv(238 downto 0);
   type Slv238VectorArray is array (natural range<>, natural range<>) of slv(237 downto 0);
   type Slv237VectorArray is array (natural range<>, natural range<>) of slv(236 downto 0);
   type Slv236VectorArray is array (natural range<>, natural range<>) of slv(235 downto 0);
   type Slv235VectorArray is array (natural range<>, natural range<>) of slv(234 downto 0);
   type Slv234VectorArray is array (natural range<>, natural range<>) of slv(233 downto 0);
   type Slv233VectorArray is array (natural range<>, natural range<>) of slv(232 downto 0);
   type Slv232VectorArray is array (natural range<>, natural range<>) of slv(231 downto 0);
   type Slv231VectorArray is array (natural range<>, natural range<>) of slv(230 downto 0);
   type Slv230VectorArray is array (natural range<>, natural range<>) of slv(229 downto 0);
   type Slv229VectorArray is array (natural range<>, natural range<>) of slv(228 downto 0);
   type Slv228VectorArray is array (natural range<>, natural range<>) of slv(227 downto 0);
   type Slv227VectorArray is array (natural range<>, natural range<>) of slv(226 downto 0);
   type Slv226VectorArray is array (natural range<>, natural range<>) of slv(225 downto 0);
   type Slv225VectorArray is array (natural range<>, natural range<>) of slv(224 downto 0);
   type Slv224VectorArray is array (natural range<>, natural range<>) of slv(223 downto 0);
   type Slv223VectorArray is array (natural range<>, natural range<>) of slv(222 downto 0);
   type Slv222VectorArray is array (natural range<>, natural range<>) of slv(221 downto 0);
   type Slv221VectorArray is array (natural range<>, natural range<>) of slv(220 downto 0);
   type Slv220VectorArray is array (natural range<>, natural range<>) of slv(219 downto 0);
   type Slv219VectorArray is array (natural range<>, natural range<>) of slv(218 downto 0);
   type Slv218VectorArray is array (natural range<>, natural range<>) of slv(217 downto 0);
   type Slv217VectorArray is array (natural range<>, natural range<>) of slv(216 downto 0);
   type Slv216VectorArray is array (natural range<>, natural range<>) of slv(215 downto 0);
   type Slv215VectorArray is array (natural range<>, natural range<>) of slv(214 downto 0);
   type Slv214VectorArray is array (natural range<>, natural range<>) of slv(213 downto 0);
   type Slv213VectorArray is array (natural range<>, natural range<>) of slv(212 downto 0);
   type Slv212VectorArray is array (natural range<>, natural range<>) of slv(211 downto 0);
   type Slv211VectorArray is array (natural range<>, natural range<>) of slv(210 downto 0);
   type Slv210VectorArray is array (natural range<>, natural range<>) of slv(209 downto 0);
   type Slv209VectorArray is array (natural range<>, natural range<>) of slv(208 downto 0);
   type Slv208VectorArray is array (natural range<>, natural range<>) of slv(207 downto 0);
   type Slv207VectorArray is array (natural range<>, natural range<>) of slv(206 downto 0);
   type Slv206VectorArray is array (natural range<>, natural range<>) of slv(205 downto 0);
   type Slv205VectorArray is array (natural range<>, natural range<>) of slv(204 downto 0);
   type Slv204VectorArray is array (natural range<>, natural range<>) of slv(203 downto 0);
   type Slv203VectorArray is array (natural range<>, natural range<>) of slv(202 downto 0);
   type Slv202VectorArray is array (natural range<>, natural range<>) of slv(201 downto 0);
   type Slv201VectorArray is array (natural range<>, natural range<>) of slv(200 downto 0);
   type Slv200VectorArray is array (natural range<>, natural range<>) of slv(199 downto 0);
   type Slv199VectorArray is array (natural range<>, natural range<>) of slv(198 downto 0);
   type Slv198VectorArray is array (natural range<>, natural range<>) of slv(197 downto 0);
   type Slv197VectorArray is array (natural range<>, natural range<>) of slv(196 downto 0);
   type Slv196VectorArray is array (natural range<>, natural range<>) of slv(195 downto 0);
   type Slv195VectorArray is array (natural range<>, natural range<>) of slv(194 downto 0);
   type Slv194VectorArray is array (natural range<>, natural range<>) of slv(193 downto 0);
   type Slv193VectorArray is array (natural range<>, natural range<>) of slv(192 downto 0);
   type Slv192VectorArray is array (natural range<>, natural range<>) of slv(191 downto 0);
   type Slv191VectorArray is array (natural range<>, natural range<>) of slv(190 downto 0);
   type Slv190VectorArray is array (natural range<>, natural range<>) of slv(189 downto 0);
   type Slv189VectorArray is array (natural range<>, natural range<>) of slv(188 downto 0);
   type Slv188VectorArray is array (natural range<>, natural range<>) of slv(187 downto 0);
   type Slv187VectorArray is array (natural range<>, natural range<>) of slv(186 downto 0);
   type Slv186VectorArray is array (natural range<>, natural range<>) of slv(185 downto 0);
   type Slv185VectorArray is array (natural range<>, natural range<>) of slv(184 downto 0);
   type Slv184VectorArray is array (natural range<>, natural range<>) of slv(183 downto 0);
   type Slv183VectorArray is array (natural range<>, natural range<>) of slv(182 downto 0);
   type Slv182VectorArray is array (natural range<>, natural range<>) of slv(181 downto 0);
   type Slv181VectorArray is array (natural range<>, natural range<>) of slv(180 downto 0);
   type Slv180VectorArray is array (natural range<>, natural range<>) of slv(179 downto 0);
   type Slv179VectorArray is array (natural range<>, natural range<>) of slv(178 downto 0);
   type Slv178VectorArray is array (natural range<>, natural range<>) of slv(177 downto 0);
   type Slv177VectorArray is array (natural range<>, natural range<>) of slv(176 downto 0);
   type Slv176VectorArray is array (natural range<>, natural range<>) of slv(175 downto 0);
   type Slv175VectorArray is array (natural range<>, natural range<>) of slv(174 downto 0);
   type Slv174VectorArray is array (natural range<>, natural range<>) of slv(173 downto 0);
   type Slv173VectorArray is array (natural range<>, natural range<>) of slv(172 downto 0);
   type Slv172VectorArray is array (natural range<>, natural range<>) of slv(171 downto 0);
   type Slv171VectorArray is array (natural range<>, natural range<>) of slv(170 downto 0);
   type Slv170VectorArray is array (natural range<>, natural range<>) of slv(169 downto 0);
   type Slv169VectorArray is array (natural range<>, natural range<>) of slv(168 downto 0);
   type Slv168VectorArray is array (natural range<>, natural range<>) of slv(167 downto 0);
   type Slv167VectorArray is array (natural range<>, natural range<>) of slv(166 downto 0);
   type Slv166VectorArray is array (natural range<>, natural range<>) of slv(165 downto 0);
   type Slv165VectorArray is array (natural range<>, natural range<>) of slv(164 downto 0);
   type Slv164VectorArray is array (natural range<>, natural range<>) of slv(163 downto 0);
   type Slv163VectorArray is array (natural range<>, natural range<>) of slv(162 downto 0);
   type Slv162VectorArray is array (natural range<>, natural range<>) of slv(161 downto 0);
   type Slv161VectorArray is array (natural range<>, natural range<>) of slv(160 downto 0);
   type Slv160VectorArray is array (natural range<>, natural range<>) of slv(159 downto 0);
   type Slv159VectorArray is array (natural range<>, natural range<>) of slv(158 downto 0);
   type Slv158VectorArray is array (natural range<>, natural range<>) of slv(157 downto 0);
   type Slv157VectorArray is array (natural range<>, natural range<>) of slv(156 downto 0);
   type Slv156VectorArray is array (natural range<>, natural range<>) of slv(155 downto 0);
   type Slv155VectorArray is array (natural range<>, natural range<>) of slv(154 downto 0);
   type Slv154VectorArray is array (natural range<>, natural range<>) of slv(153 downto 0);
   type Slv153VectorArray is array (natural range<>, natural range<>) of slv(152 downto 0);
   type Slv152VectorArray is array (natural range<>, natural range<>) of slv(151 downto 0);
   type Slv151VectorArray is array (natural range<>, natural range<>) of slv(150 downto 0);
   type Slv150VectorArray is array (natural range<>, natural range<>) of slv(149 downto 0);
   type Slv149VectorArray is array (natural range<>, natural range<>) of slv(148 downto 0);
   type Slv148VectorArray is array (natural range<>, natural range<>) of slv(147 downto 0);
   type Slv147VectorArray is array (natural range<>, natural range<>) of slv(146 downto 0);
   type Slv146VectorArray is array (natural range<>, natural range<>) of slv(145 downto 0);
   type Slv145VectorArray is array (natural range<>, natural range<>) of slv(144 downto 0);
   type Slv144VectorArray is array (natural range<>, natural range<>) of slv(143 downto 0);
   type Slv143VectorArray is array (natural range<>, natural range<>) of slv(142 downto 0);
   type Slv142VectorArray is array (natural range<>, natural range<>) of slv(141 downto 0);
   type Slv141VectorArray is array (natural range<>, natural range<>) of slv(140 downto 0);
   type Slv140VectorArray is array (natural range<>, natural range<>) of slv(139 downto 0);
   type Slv139VectorArray is array (natural range<>, natural range<>) of slv(138 downto 0);
   type Slv138VectorArray is array (natural range<>, natural range<>) of slv(137 downto 0);
   type Slv137VectorArray is array (natural range<>, natural range<>) of slv(136 downto 0);
   type Slv136VectorArray is array (natural range<>, natural range<>) of slv(135 downto 0);
   type Slv135VectorArray is array (natural range<>, natural range<>) of slv(134 downto 0);
   type Slv134VectorArray is array (natural range<>, natural range<>) of slv(133 downto 0);
   type Slv133VectorArray is array (natural range<>, natural range<>) of slv(132 downto 0);
   type Slv132VectorArray is array (natural range<>, natural range<>) of slv(131 downto 0);
   type Slv131VectorArray is array (natural range<>, natural range<>) of slv(130 downto 0);
   type Slv130VectorArray is array (natural range<>, natural range<>) of slv(129 downto 0);
   type Slv129VectorArray is array (natural range<>, natural range<>) of slv(128 downto 0);
   type Slv128VectorArray is array (natural range<>, natural range<>) of slv(127 downto 0);
   type Slv127VectorArray is array (natural range<>, natural range<>) of slv(126 downto 0);
   type Slv126VectorArray is array (natural range<>, natural range<>) of slv(125 downto 0);
   type Slv125VectorArray is array (natural range<>, natural range<>) of slv(124 downto 0);
   type Slv124VectorArray is array (natural range<>, natural range<>) of slv(123 downto 0);
   type Slv123VectorArray is array (natural range<>, natural range<>) of slv(122 downto 0);
   type Slv122VectorArray is array (natural range<>, natural range<>) of slv(121 downto 0);
   type Slv121VectorArray is array (natural range<>, natural range<>) of slv(120 downto 0);
   type Slv120VectorArray is array (natural range<>, natural range<>) of slv(119 downto 0);
   type Slv119VectorArray is array (natural range<>, natural range<>) of slv(118 downto 0);
   type Slv118VectorArray is array (natural range<>, natural range<>) of slv(117 downto 0);
   type Slv117VectorArray is array (natural range<>, natural range<>) of slv(116 downto 0);
   type Slv116VectorArray is array (natural range<>, natural range<>) of slv(115 downto 0);
   type Slv115VectorArray is array (natural range<>, natural range<>) of slv(114 downto 0);
   type Slv114VectorArray is array (natural range<>, natural range<>) of slv(113 downto 0);
   type Slv113VectorArray is array (natural range<>, natural range<>) of slv(112 downto 0);
   type Slv112VectorArray is array (natural range<>, natural range<>) of slv(111 downto 0);
   type Slv111VectorArray is array (natural range<>, natural range<>) of slv(110 downto 0);
   type Slv110VectorArray is array (natural range<>, natural range<>) of slv(109 downto 0);
   type Slv109VectorArray is array (natural range<>, natural range<>) of slv(108 downto 0);
   type Slv108VectorArray is array (natural range<>, natural range<>) of slv(107 downto 0);
   type Slv107VectorArray is array (natural range<>, natural range<>) of slv(106 downto 0);
   type Slv106VectorArray is array (natural range<>, natural range<>) of slv(105 downto 0);
   type Slv105VectorArray is array (natural range<>, natural range<>) of slv(104 downto 0);
   type Slv104VectorArray is array (natural range<>, natural range<>) of slv(103 downto 0);
   type Slv103VectorArray is array (natural range<>, natural range<>) of slv(102 downto 0);
   type Slv102VectorArray is array (natural range<>, natural range<>) of slv(101 downto 0);
   type Slv101VectorArray is array (natural range<>, natural range<>) of slv(100 downto 0);
   type Slv100VectorArray is array (natural range<>, natural range<>) of slv(99 downto 0);
   type Slv99VectorArray is array (natural range<>, natural range<>) of slv(98 downto 0);
   type Slv98VectorArray is array (natural range<>, natural range<>) of slv(97 downto 0);
   type Slv97VectorArray is array (natural range<>, natural range<>) of slv(96 downto 0);
   type Slv96VectorArray is array (natural range<>, natural range<>) of slv(95 downto 0);
   type Slv95VectorArray is array (natural range<>, natural range<>) of slv(94 downto 0);
   type Slv94VectorArray is array (natural range<>, natural range<>) of slv(93 downto 0);
   type Slv93VectorArray is array (natural range<>, natural range<>) of slv(92 downto 0);
   type Slv92VectorArray is array (natural range<>, natural range<>) of slv(91 downto 0);
   type Slv91VectorArray is array (natural range<>, natural range<>) of slv(90 downto 0);
   type Slv90VectorArray is array (natural range<>, natural range<>) of slv(89 downto 0);
   type Slv89VectorArray is array (natural range<>, natural range<>) of slv(88 downto 0);
   type Slv88VectorArray is array (natural range<>, natural range<>) of slv(87 downto 0);
   type Slv87VectorArray is array (natural range<>, natural range<>) of slv(86 downto 0);
   type Slv86VectorArray is array (natural range<>, natural range<>) of slv(85 downto 0);
   type Slv85VectorArray is array (natural range<>, natural range<>) of slv(84 downto 0);
   type Slv84VectorArray is array (natural range<>, natural range<>) of slv(83 downto 0);
   type Slv83VectorArray is array (natural range<>, natural range<>) of slv(82 downto 0);
   type Slv82VectorArray is array (natural range<>, natural range<>) of slv(81 downto 0);
   type Slv81VectorArray is array (natural range<>, natural range<>) of slv(80 downto 0);
   type Slv80VectorArray is array (natural range<>, natural range<>) of slv(79 downto 0);
   type Slv79VectorArray is array (natural range<>, natural range<>) of slv(78 downto 0);
   type Slv78VectorArray is array (natural range<>, natural range<>) of slv(77 downto 0);
   type Slv77VectorArray is array (natural range<>, natural range<>) of slv(76 downto 0);
   type Slv76VectorArray is array (natural range<>, natural range<>) of slv(75 downto 0);
   type Slv75VectorArray is array (natural range<>, natural range<>) of slv(74 downto 0);
   type Slv74VectorArray is array (natural range<>, natural range<>) of slv(73 downto 0);
   type Slv73VectorArray is array (natural range<>, natural range<>) of slv(72 downto 0);
   type Slv72VectorArray is array (natural range<>, natural range<>) of slv(71 downto 0);
   type Slv71VectorArray is array (natural range<>, natural range<>) of slv(70 downto 0);
   type Slv70VectorArray is array (natural range<>, natural range<>) of slv(69 downto 0);
   type Slv69VectorArray is array (natural range<>, natural range<>) of slv(68 downto 0);
   type Slv68VectorArray is array (natural range<>, natural range<>) of slv(67 downto 0);
   type Slv67VectorArray is array (natural range<>, natural range<>) of slv(66 downto 0);
   type Slv66VectorArray is array (natural range<>, natural range<>) of slv(65 downto 0);
   type Slv65VectorArray is array (natural range<>, natural range<>) of slv(64 downto 0);
   type Slv64VectorArray is array (natural range<>, natural range<>) of slv(63 downto 0);
   type Slv63VectorArray is array (natural range<>, natural range<>) of slv(62 downto 0);
   type Slv62VectorArray is array (natural range<>, natural range<>) of slv(61 downto 0);
   type Slv61VectorArray is array (natural range<>, natural range<>) of slv(60 downto 0);
   type Slv60VectorArray is array (natural range<>, natural range<>) of slv(59 downto 0);
   type Slv59VectorArray is array (natural range<>, natural range<>) of slv(58 downto 0);
   type Slv58VectorArray is array (natural range<>, natural range<>) of slv(57 downto 0);
   type Slv57VectorArray is array (natural range<>, natural range<>) of slv(56 downto 0);
   type Slv56VectorArray is array (natural range<>, natural range<>) of slv(55 downto 0);
   type Slv55VectorArray is array (natural range<>, natural range<>) of slv(54 downto 0);
   type Slv54VectorArray is array (natural range<>, natural range<>) of slv(53 downto 0);
   type Slv53VectorArray is array (natural range<>, natural range<>) of slv(52 downto 0);
   type Slv52VectorArray is array (natural range<>, natural range<>) of slv(51 downto 0);
   type Slv51VectorArray is array (natural range<>, natural range<>) of slv(50 downto 0);
   type Slv50VectorArray is array (natural range<>, natural range<>) of slv(49 downto 0);
   type Slv49VectorArray is array (natural range<>, natural range<>) of slv(48 downto 0);
   type Slv48VectorArray is array (natural range<>, natural range<>) of slv(47 downto 0);
   type Slv47VectorArray is array (natural range<>, natural range<>) of slv(46 downto 0);
   type Slv46VectorArray is array (natural range<>, natural range<>) of slv(45 downto 0);
   type Slv45VectorArray is array (natural range<>, natural range<>) of slv(44 downto 0);
   type Slv44VectorArray is array (natural range<>, natural range<>) of slv(43 downto 0);
   type Slv43VectorArray is array (natural range<>, natural range<>) of slv(42 downto 0);
   type Slv42VectorArray is array (natural range<>, natural range<>) of slv(41 downto 0);
   type Slv41VectorArray is array (natural range<>, natural range<>) of slv(40 downto 0);
   type Slv40VectorArray is array (natural range<>, natural range<>) of slv(39 downto 0);
   type Slv39VectorArray is array (natural range<>, natural range<>) of slv(38 downto 0);
   type Slv38VectorArray is array (natural range<>, natural range<>) of slv(37 downto 0);
   type Slv37VectorArray is array (natural range<>, natural range<>) of slv(36 downto 0);
   type Slv36VectorArray is array (natural range<>, natural range<>) of slv(35 downto 0);
   type Slv35VectorArray is array (natural range<>, natural range<>) of slv(34 downto 0);
   type Slv34VectorArray is array (natural range<>, natural range<>) of slv(33 downto 0);
   type Slv33VectorArray is array (natural range<>, natural range<>) of slv(32 downto 0);
   type Slv32VectorArray is array (natural range<>, natural range<>) of slv(31 downto 0);
   type Slv31VectorArray is array (natural range<>, natural range<>) of slv(30 downto 0);
   type Slv30VectorArray is array (natural range<>, natural range<>) of slv(29 downto 0);
   type Slv29VectorArray is array (natural range<>, natural range<>) of slv(28 downto 0);
   type Slv28VectorArray is array (natural range<>, natural range<>) of slv(27 downto 0);
   type Slv27VectorArray is array (natural range<>, natural range<>) of slv(26 downto 0);
   type Slv26VectorArray is array (natural range<>, natural range<>) of slv(25 downto 0);
   type Slv25VectorArray is array (natural range<>, natural range<>) of slv(24 downto 0);
   type Slv24VectorArray is array (natural range<>, natural range<>) of slv(23 downto 0);
   type Slv23VectorArray is array (natural range<>, natural range<>) of slv(22 downto 0);
   type Slv22VectorArray is array (natural range<>, natural range<>) of slv(21 downto 0);
   type Slv21VectorArray is array (natural range<>, natural range<>) of slv(20 downto 0);
   type Slv20VectorArray is array (natural range<>, natural range<>) of slv(19 downto 0);
   type Slv19VectorArray is array (natural range<>, natural range<>) of slv(18 downto 0);
   type Slv18VectorArray is array (natural range<>, natural range<>) of slv(17 downto 0);
   type Slv17VectorArray is array (natural range<>, natural range<>) of slv(16 downto 0);
   type Slv16VectorArray is array (natural range<>, natural range<>) of slv(15 downto 0);
   type Slv15VectorArray is array (natural range<>, natural range<>) of slv(14 downto 0);
   type Slv14VectorArray is array (natural range<>, natural range<>) of slv(13 downto 0);
   type Slv13VectorArray is array (natural range<>, natural range<>) of slv(12 downto 0);
   type Slv12VectorArray is array (natural range<>, natural range<>) of slv(11 downto 0);
   type Slv11VectorArray is array (natural range<>, natural range<>) of slv(10 downto 0);
   type Slv10VectorArray is array (natural range<>, natural range<>) of slv(9 downto 0);
   type Slv9VectorArray is array (natural range<>, natural range<>) of slv(8 downto 0);
   type Slv8VectorArray is array (natural range<>, natural range<>) of slv(7 downto 0);
   type Slv7VectorArray is array (natural range<>, natural range<>) of slv(6 downto 0);
   type Slv6VectorArray is array (natural range<>, natural range<>) of slv(5 downto 0);
   type Slv5VectorArray is array (natural range<>, natural range<>) of slv(4 downto 0);
   type Slv4VectorArray is array (natural range<>, natural range<>) of slv(3 downto 0);
   type Slv3VectorArray is array (natural range<>, natural range<>) of slv(2 downto 0);
   type Slv2VectorArray is array (natural range<>, natural range<>) of slv(1 downto 0);
   type Slv1VectorArray is array (natural range<>, natural range<>) of slv(0 downto 0);
   type SlVectorArray is array (natural range<>, natural range<>) of sl;
   
   -- Mux a SlVectorArray into an SLV
   function muxSlVectorArray (vec : SlVectorArray; addr : natural; allowOutOfRange : boolean := false) return slv; 
   
   -- Build Information:
   -- BUILD_INFO_G(2047 downto 0)    = buildString
   -- BUILD_INFO_G(2079 downto 2048) = fwVersion
   -- BUILD_INFO_G(2239 downto 2080) = gitHash
   subtype BuildInfoType is slv(2239 downto 0); 
   type BuildInfoRetType is record
      buildString : Slv32Array(0 to 63);
      fwVersion   : slv(31 downto 0);
      gitHash     : slv(159 downto 0);
   end record;   
   function toBuildInfo (din : slv) return BuildInfoRetType;
   function toSlv (      din : BuildInfoRetType) return BuildInfoType;

   constant BUILD_INFO_DEFAULT_C : BuildInfoRetType := (
      buildString =>  (others => (others => '0')),
      fwVersion => X"00000000",
      gitHash => (others => '0'));

   constant BUILD_INFO_DEFAULT_SLV_C : BuildInfoType := (others => '0');
   
end StdRtlPkg;

package body StdRtlPkg is

   function slvAll (size : positive; value : sl) return slv is
      variable retVar : slv(size-1 downto 0) := (others => value);
   begin
      return retVar;
   end function slvAll;

   function slvZero (size : positive) return slv is
   begin
      return slvAll(size, '0');
   end function;

   function slvOne (size : positive) return slv is
   begin
      return slvAll(size, '1');
   end function;

   function isPowerOf2 (number : natural) return boolean is
   begin
      return isPowerOf2(toSlv(number, 32));
   end function isPowerOf2;

   function isPowerOf2 (vector : slv) return boolean is
   begin
      return (unsigned(vector) /= 0) and
         (unsigned(unsigned(vector) and (unsigned(vector)-1)) = 0);
   end function isPowerOf2;

   ---------------------------------------------------------------------------------------------------------------------
   -- Function: log2
   -- Purpose: Finds the log base 2 of an integer
   -- Input is rounded up to nearest power of two.
   -- Therefore log2(5) = log2(8) = 3.
   -- Arg: number - integer to find log2 of
   -- Returns: Integer containing log base two of input.
   ---------------------------------------------------------------------------------------------------------------------
   function log2(constant number : integer) return natural is
   begin
      if (number < 2) then
         return 1;
      end if;
      return integer(ceil(ieee.math_real.log2(real(number))));
   end function;

   -- Find number of bits needed to store a number
   function bitSize (constant number : natural ) return positive is
   begin
      if (number = 0 or number = 1) then
         return 1;
      else
         if (isPowerOf2(number)) then
            return log2(number) + 1;
         else
            return log2(number);
         end if;
      end if;
   end function;

   -- NOTE: XST will crap its pants if you try to pass a constant to this function
   function bitReverse (a : slv) return slv is
      variable resultVar : slv(a'range);
      alias aa           : slv(a'reverse_range) is a;
   begin
      for i in aa'range loop
         resultVar(i) := aa(i);
      end loop;
      return resultVar;
   end;

   function wordCount (number : positive; wordSize : positive := 8) return natural is
      variable ret : natural;
   begin
      ret := number / wordSize;
      if (number mod wordSize /= 0) then
         ret := ret + 1;
      end if;
      return ret;
   end function wordCount;

   function list (constant start, size, step : integer) return IntegerArray is
      variable retVar : IntegerArray(0 to size-1);
   begin
      for i in retVar'range loop
         retVar(i) := start + (i * step);
      end loop;
      return retVar;
   end function list;

   function toBoolean (logic : sl) return boolean is
   begin  -- function toBoolean
      return logic = '1';
   end function toBoolean;

   function toSl (bool : boolean) return sl is
   begin
      if (bool) then
         return '1';
      else
         return '0';
      end if;
   end function toSl;

   function toString (bool : boolean) return string is
   begin
      if (bool) then
         return "TRUE";
      else
         return "FALSE";
      end if;
   end function toString;

   function toBoolean (str : string) return boolean is
   begin
      if (str = "TRUE" or str = "true") then
         return true;
      else
         return false;
      end if;
   end function toBoolean;

   function toSlv (      bools : BooleanArray)      return slv is
      variable ret : slv(bools'range) := (others => '0');
   begin
      for i in ret'range loop
         ret(i) := toSl(bools(i));
      end loop;
      return ret;
   end function toSlv;

   --------------------------------------------------------------------------------------------------
   -- Decode and genmux
   --------------------------------------------------------------------------------------------------
   -- generic decoder
   function decode(v : slv) return slv is
      variable res : slv((2**v'length)-1 downto 0);
      variable i   : integer;
   begin
      res    := (others => '0');
      i      := 0;
      i      := to_integer(unsigned(v));
      res(i) := '1';
      return res;
   end;

   -- generic multiplexer
   function genmux(s, v : slv) return sl is
      variable res : slv(v'length-1 downto 0);
      variable i   : integer;
   begin
      res := v;
      i   := 0;
      i   := to_integer(unsigned(s));
      return res(i);
   end;

   ---------------------------------------------------------------------------------------------------------------------
   -- Unary reduction operators
   ---------------------------------------------------------------------------------------------------------------------
   function uOr (vec : slv) return sl is
   begin
      for i in vec'range loop
         if (vec(i) = '1') then
            return '1';
         end if;
      end loop;
      return '0';
   end function uOr;

   function uAnd (vec : slv) return sl is
   begin
      for i in vec'range loop
         if (vec(i) = '0') then
            return '0';
         end if;
      end loop;
      return '1';
   end function uAnd;

   function uXor (vec : slv) return sl is
      variable intVar : sl;
   begin
      for i in vec'range loop
         if (i = vec'left) then
            intVar := vec(i);
         else
            intVar := intVar xor vec(i);
         end if;
      end loop;
      return intVar;
   end function uXor;

   function allBits (vec : slv; test : sl) return boolean is
   begin
      for i in vec'range loop
         if (vec(i) /= test) then
            return false;
         end if;
      end loop;
      return true;
   end function;

   function noBits (vec : slv; test : sl) return boolean is
   begin
      for i in vec'range loop
         if (vec(i) = test) then
            return false;
         end if;
      end loop;
      return true;
   end function;

   -----------------------------------------------------------------------------
   -- Functions to determine parity of arbitrary sized slv
   -----------------------------------------------------------------------------
   -- returns '1' if vec has even parity
   function evenParity (vec : slv)
      return sl is
   begin
      return not uXor(vec);
   end function;

   -- return '1' if vec has odd parity
   function oddParity (vec : slv)
      return sl is
   begin
      return uXor(vec);
   end function;
   
   -----------------------------------------------------------------------------
   -- Functions for counting the number of '1' in a slv bus
   -----------------------------------------------------------------------------
   -- New Non-recursive onesCount Function
   function onesCountU (vec : slv)
      return unsigned is
      variable retVar : unsigned((bitSize(vec'length)-1) downto 0) := to_unsigned(0,bitSize(vec'length));
   begin
      for i in vec'range loop
         if vec(i) = '1' then
            retVar := retVar + 1;
         end if;
      end loop;
      return retVar;
   end function;

   function onesCount (
      vec : slv)
      return slv is
   begin
      return slv(onesCountU(vec));
   end function onesCount;
   
   -- -- Old Recursive onesCount Function
--    function onesCount (vec : slv) return unsigned is
--       variable topVar    : slv(vec'high downto vec'low+(vec'length/2));
--       variable bottomVar : slv(topVar'low-1 downto vec'low);
--       variable tmpVar    : slv(2 downto 0);
--    begin
--       if (vec'length = 1) then
--          return '0' & unsigned(vec);
--       end if;

--       if (vec'length = 2) then
--          return uAnd(vec) & uXor(vec);
--       end if;

--       if (vec'length = 3) then
--          tmpVar := vec;
--          case tmpVar is
--             when "000"  => return "00";
--             when "001"  => return "01";
--             when "010"  => return "01";
--             when "011"  => return "10";
--             when "100"  => return "01";
--             when "101"  => return "10";
--             when "110"  => return "10";
--             when "111"  => return "11";
--             when others => return "00";
--          end case;
--       end if;

--       topVar    := vec(vec'high downto (vec'high+1)-((vec'length+1)/2));
--       bottomVar := vec(vec'high-((vec'length+1)/2) downto vec'low);

--       return ('0' & onesCount(topVar)) + ('0' & onesCount(bottomVar));
--    end function;  

   -- SLV variant   
--    function onesCount (vec : slv)
--       return slv is
--       variable retVar : slv((bitSize(vec'length)-1) downto 0);      
--       variable cntVar : unsigned((bitSize(vec'length)-1) downto 0);
--    begin
--       cntVar := onesCount(vec);
--       retVar := slv(cntVar);
--       return retVar;
--    end function;   

   -----------------------------------------------------------------------------
   -- Functions for encoding and decoding grey codes
   -----------------------------------------------------------------------------
   -- Get next gray code given binary vector
   function grayEncode (vec : unsigned)
      return unsigned is
   begin
      return vec xor shift_right(vec, 1);
   end function;

   -- SLV variant
   function grayEncode (vec : slv)
      return slv is
   begin
      return slv(grayEncode(unsigned(vec)));
   end function;

   -- Get the binary equivalent of a Gray code created with gray_encode.
   function grayDecode (vec : unsigned)
      return unsigned is
      variable retVar : unsigned(vec'range) := (others => '0');
   begin
      for i in vec'range loop
         if (i = vec'left) then
            retVar(i) := vec(i);
         else
            if (vec'ascending) then
               retVar(i) := retVar(i-1) xor vec(i);
            else
               retVar(i) := retVar(i+1) xor vec(i);
            end if;
         end if;
      end loop;
      return retVar;
   end function;

   -- SLV variant
   function grayDecode (vec : slv)
      return slv is
   begin
      return slv(grayDecode(unsigned(vec)));
   end function;

   -------------------------------------------------------------------------------------------------
   -- Implements an N tap linear feedback shift operation
   -- Size of LFSR is variable and determined by length of lfsr parameter
   -- Number of taps is variable and determined by length of taps array parameter
   -- An input parameter is also available for use in scramblers
   -- Output is new lfsr value after one shift operation
   -- The lfsr param can be indexed ascending or decending
   -- The shift is in the direction of increasing index (left shift for decending, right for ascending)
   -------------------------------------------------------------------------------------------------
   function lfsrShift (lfsr : slv; constant taps : NaturalArray; input : sl := '0') return slv is
      variable retVar : slv(lfsr'range) := (others => '0');
   begin
      if (lfsr'ascending) then
         retVar := input & lfsr(lfsr'left to lfsr'right-1);
      else
         retVar := lfsr(lfsr'left-1 downto lfsr'right) & input;
      end if;

      for i in taps'range loop
         assert (taps(i)  <= lfsr'high) report "lfsrShift() - Tap value exceedes lfsr range" severity failure;
         retVar(lfsr'low) := retVar(lfsr'low) xor lfsr(taps(i));
      end loop;

      return retVar;
   end function;

   -------------------------------------------------------------------------------------------------
   -- One line if-then-else functions.
   -------------------------------------------------------------------------------------------------
  
   function ite (i : boolean; t : boolean; e : boolean) return boolean is
   begin
      if (i) then return t; else return e; end if;
   end function ite;    
   
   function ite (i : boolean; t : sl; e : sl) return sl is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : slv; e : slv) return slv is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : bit; e : bit) return bit is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : bit_vector; e : bit_vector) return bit_vector is
   begin
      if (i) then return t; else return e; end if;
   end function ite;   

   function ite (i : boolean; t : character; e : character) return character is
   begin
      if (i) then return t; else return e; end if;
   end function ite;
   
   function ite (i : boolean; t : string; e : string) return string is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : integer; e : integer) return integer is
   begin
      if (i) then return t; else return e; end if;
   end function ite;  

   function ite (i : boolean; t : real; e : real) return real is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : time; e : time) return time is
   begin
      if (i) then return t; else return e; end if;
   end function ite;  

   -----------------------------
   -- Min and Max
   -----------------------------
   function maximum (left, right : integer) return integer is
   begin
      if left > right then return left;
      else return right;
      end if;
   end maximum;

   function maximum (
      a : IntegerArray)
      return integer is
      variable max : integer := a(a'low);
   begin
      for i in a'range loop
         if (a(i) > max) then
            max := a(i);
         end if;
      end loop;
      return max;
   end function maximum;

   function minimum (left, right : integer) return integer is
   begin
      if left < right then return left;
      else return right;
      end if;
   end minimum;
   
   function minimum (
      a : IntegerArray)
      return integer is
      variable max : integer := a(a'low);
   begin
      for i in a'range loop
         if (a(i) < max) then
            max := a(i);
         end if;
      end loop;
      return max;
   end function minimum;
   -----------------------------
   -- conv_std_logic_vector functions
   -- without calling the STD_LOGIC_ARITH library
   -----------------------------

   -- convert an integer to an STD_LOGIC_VECTOR
   function toSlv(ARG : integer; SIZE : integer) return slv is
   begin
      if (arg < 0) then
         return slv(to_unsigned(0, SIZE));
      end if;
      return slv(to_unsigned(ARG, SIZE));
   end;


   -------------------------------------------------------------------------------------------------
   -- Multiply and divide reals and integer
   -------------------------------------------------------------------------------------------------
   function "*" (L : real; R : integer)      return real is
   begin
      return real(L*real(R));
   end function "*";

   function "*" (L : integer; R : real) return real is
   begin
      return real(real(R)*L);
   end function;
   
   function "/" (L : integer; R : real) return real is
   begin
      return real(real(L)/R);
   end function;

   function "/" (L : real; R : integer) return real is
   begin
      return real(L/real(R));
   end function;   

   -------------------------------------------------------------------------------------------------
   -- Simulates an ADC conversion
   -------------------------------------------------------------------------------------------------
   function adcConversion (
      ain      : real;
      low      : real;
      high     : real;
      bits     : positive;
      twosComp : boolean)
      return slv is
      variable tmpR : real;
      variable tmpI : integer;

      variable retSigned   : signed(bits-1 downto 0);
      variable retUnsigned : unsigned(bits-1 downto 0);
   begin
      tmpR := ain;

      -- Constrain input to full scale range
      tmpR := realmin(high, tmpR);
      tmpR := realmax(low, tmpR);

      -- Scale to [0,1] or [-.5,.5]
      tmpR := (tmpR-low)/(high-low) + ite(twosComp, -0.5, 0.0);

      -- Scale to number of bits
      tmpR := tmpR * real(2**bits);

      if (twosComp) then
         retSigned := to_signed(integer(round(tmpR)), bits);
         return slv(retSigned);
      else
         retUnsigned := to_unsigned(integer(round(tmpR)), bits);
         return slv(retUnsigned);
      end if;
   end function adcConversion;

   -----------------------------
   -- gets a time ratio
   -----------------------------   
   function getTimeRatio (T1, T2 : time) return natural is
   begin
      return natural(T1/T2);
   end function;

   function getTimeRatio (T1, T2 : real) return natural is
   begin
      return natural(ROUND(abs(T1/T2)));
   end function;

   ---------------------------------------------------------------------------------------------------------------------
   -- Convert a frequency to a period (time).
   ---------------------------------------------------------------------------------------------------------------------
   -- pragma translate_off
   function toTime(f : frequency) return time is
   begin
      return(1.0 sec / (f/Hz));
   end function;
   --pragma translate_on
   
   -----------------------------
   -- Mux a SlVectorArray into an SLV
   ----------------------------- 
   function muxSlVectorArray (vec : SlVectorArray; 
      addr            : natural;
      allowOutOfRange : boolean := false)
      return slv is
      variable retVar : slv(vec'range(2)); 
   begin
      -- Check the limit of the address
      if (addr < vec'length(1)) or (allowOutOfRange = false) then
         for i in vec'range(2) loop
            retVar(i) := vec(addr, i);
         end loop;
      else
         retVar := (others => '0');
      end if;
      return retVar;   
   end function;

   procedure assignSlv (
      i      : inout integer;
      vector : inout slv;
      value  : in    slv)
   is
      variable low : integer;
   begin
      low := i;
      i   := i+value'length;
      vector(i-1 downto low) := value;
   end procedure assignSlv;
   
   procedure assignSlv (
      i      : inout integer;
      vector : inout slv;
      value  : in    sl)
   is
   begin
      vector(i) := value;
      i := i+1;
   end procedure assignSlv;
   
   procedure assignRecord (
      i      : inout integer;
      vector : in    slv;
      value  : inout slv)
   is
      variable low : integer;
   begin
      low := i;
      i   := i+value'length;
      value := vector(i-1 downto low);
   end procedure assignRecord;
   
   procedure assignRecord (
      i      : inout integer;
      vector : in    slv;
      value  : inout sl)
   is
   begin
      value := vector(i);
      i   := i+1;
   end procedure assignRecord;

   -- Resize an SLV, either by trimming or padding upper bits
   function resize ( vec : slv; newSize : integer; pad : sl:='0') return slv is
      variable ret : slv(newSize-1 downto 0);
      variable tmp : slv(vec'length-1 downto 0);
      variable top    : integer;
   begin
      ret := (others => pad);
      tmp := vec;                       -- handles ranges that arent x:0
      top := minimum( newSize, vec'length) - 1;
      ret(top downto 0) := tmp(top downto 0);
      return ret;   
   end function;

   function resize (str : string; newSize : integer ; pad : character := nul) return string is
      variable ret : string(1 to newSize);
      variable tmp : string(1 to str'length);
      variable top : integer;
   begin
      ret := (others => pad);
      tmp := str;
      top := minimum( newSize, str'length);
      ret(1 to top) := tmp(1 to top);
      return ret;
   end function resize;
   
   function toBuildInfo (din : slv) return BuildInfoRetType is
      variable ret : BuildInfoRetType;
      variable i   : natural;
   begin
      for i in 0 to 255 loop         
         ret.buildString(i/4)(8*(i mod 4)+7 downto 8*(i mod 4)) := din(2047-(8*i) downto 2040-(8*i));
      end loop;
      ret.fwVersion := din(2079 downto 2048); 
      ret.gitHash   := din(2239 downto 2080);  
      return ret;
   end function;

   function toSlv (din : BuildInfoRetType) return BuildInfoType is
      variable ret : BuildInfoType;
   begin
      for i in 0 to 255 loop
         ret(2047-(8*i) downto 2040-(8*i)) := din.buildString(i/4)(8*(i mod 4)+7 downto 8*(i mod 4));
      end loop;
      ret(2079 downto 2048) := din.fwVersion;
      ret(2239 downto 2080) := din.gitHash;
      return ret;
   end function toSlv;

end package body StdRtlPkg;
