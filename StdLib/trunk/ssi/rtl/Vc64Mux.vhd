-------------------------------------------------------------------------------
-- Title      : VC Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : Vc64Mux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-08
-- Last update: 2014-04-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming VC interfaces to a single encoded
-- outbound interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/08/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.Vc64Pkg.all;

entity Vc64Mux is
   generic (
      TPD_G           : time                  := 1 ns;
      IB_VC_COUNT_G   : integer range 1 to 16 := 4;
      VC_INTERLEAVE_G : boolean               := true
   ); port (

      -- VC clock and reset
      vcClk         : in sl;
      vcClkRst      : in sl;

      -- Inbound VCs, ready is used for handshake, almost full is passed from outbound
      ibVcData      : in  Vc64DataArray(IB_VC_COUNT_G-1 downto 0);
      ibVcCtrl      : out Vc64CtrlArray(IB_VC_COUNT_G-1 downto 0);

      -- Outbound VC, ready is ignored, almost full is used
      obVcData      : out Vc64DataType;
      obVcCtrl      : in  Vc64CtrlType
   );
end Vc64Mux;

architecture structure of Vc64Mux is

   constant ACK_NUM_SIZE_C : integer := bitSize(IB_VC_COUNT_G-1);

   type StateType is ( S_IDLE, S_MOVE );

   type RegType is record
      state            : StateType;
      acks             : slv(IB_VC_COUNT_G-1 downto 0);
      ackNum           : slv(ACK_NUM_SIZE_C-1 downto 0);
      valid            : sl;
      ibVcCtrl         : Vc64CtrlArray(IB_VC_COUNT_G-1 downto 0);
      obVcData         : Vc64DataType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => S_IDLE,
      acks             => (others=>'0'),
      ackNum           => (others=>'0'),
      valid            => '0',
      ibVcCtrl         => (others=>VC64_CTRL_INIT_C),
      obVcData         => VC64_DATA_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (vcClkRst, r, ibVcData, obVcCtrl ) is
      variable v            : RegType;
      variable requests     : slv(IB_VC_COUNT_G-1 downto 0);
      variable selData      : Vc64DataType;
   begin
      v := r;

      -- Pass Flow Control, Init Ready
      for i in 0 to (IB_VC_COUNT_G-1) loop
         v.ibVcCtrl(i).overflow   := obVcCtrl.overflow;
         v.ibVcCtrl(i).almostFull := obVcCtrl.almostFull;
         v.ibVcCtrl(i).ready      := '0';
      end loop;

      -- Select source and drive output
      selData    := ibVcData(conv_integer(r.ackNum));
      selData.vc := conv_std_logic_vector(conv_integer(r.ackNum),4);
      v.obVcData := selData;

      -- Clear valid for now
      v.obVcData.valid := '0';

      -- Format requests
      for i in 0 to (IB_VC_COUNT_G-1) loop
         requests(i) := ibVcData(i).valid;
      end loop;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE =>

            -- Aribrate between requesters
            if r.valid = '0' then
               arbitrate(requests, r.ackNum, v.ackNum, v.valid, v.acks);
            end if;

            -- Valid request
            if r.valid = '1' then
               v.state := S_MOVE;
            end if;

         -- Move a frame until EOF or gap in frame
         when S_MOVE =>
            v.valid          := '0';
            v.obVcData.valid := selData.valid;

            v.ibVcCtrl(conv_integer(r.ackNum)).ready := '1';

            -- EOF seen or Gap in frame with interleave enabled
            if selData.eof = '1' or (selData.valid = '0' and VC_INTERLEAVE_G = true) then
               v.state := S_IDLE;
            end if;

      end case;

      if (vcClkRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ibVcCtrl <= v.ibVcCtrl;
      obVcData <= r.obVcData;

   end process comb;

   seq : process (vcClk) is
   begin
      if (rising_edge(vcClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

