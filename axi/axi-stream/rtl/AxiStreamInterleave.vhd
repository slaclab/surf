------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamInterleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-05-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamInterleave is
   generic ( LANES_G        : integer := 4;
             SAXIS_CONFIG_G : AxiStreamConfigType;
             MAXIS_CONFIG_G : AxiStreamConfigType );
   port ( axisClk         : in  sl;
          axisRst         : in  sl;
          sAxisMaster     : in  AxiStreamMasterType;
          sAxisSlave      : out AxiStreamSlaveType;
          mAxisMaster     : out AxiStreamMasterArray( LANES_G-1 downto 0 );
          mAxisSlave      : in  AxiStreamSlaveArray ( LANES_G-1 downto 0 ) );
end AxiStreamInterleave;

architecture top_level_app of AxiStreamInterleave is

  constant SEQ_C : slv(15 downto 8) := x"55";

  type RegType is record
    masters : AxiStreamMasterArray(LANES_G-1 downto 0);
    nready  : slv                 (LANES_G-1 downto 0);
    tSeq    : slv                 (7 downto 0);
    first   : sl;
    slave   : AxiStreamSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    masters => (others=>axiStreamMasterInit(MAXIS_CONFIG_G)),
    nready  => (others=>'0'),
    tSeq    => (others=>'0'),
    first   => '1',
    slave   => AXI_STREAM_SLAVE_INIT_C );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

begin

  U_ILA : ila_0
    port map ( clk     => axisClk,
               probe0( 15 downto   0) => r.masters(0).tData(15 downto 0),
               probe0( 31 downto  16) => r.masters(1).tData(15 downto 0),
               probe0( 47 downto  32) => r.masters(2).tData(15 downto 0),
               probe0( 63 downto  48) => r.masters(3).tData(15 downto 0),
               probe0(            64) => r.masters(0).tValid,
               probe0(            65) => r.masters(1).tValid,
               probe0(            66) => r.masters(2).tValid,
               probe0(            67) => r.masters(3).tValid,
               probe0(            68) => r.masters(0).tLast,
               probe0(            69) => r.masters(1).tLast,
               probe0(            70) => r.masters(2).tLast,
               probe0(            71) => r.masters(3).tLast,
               probe0( 79 downto  72) => r.tSeq,
               probe0( 83 downto  80) => r.nready,
               probe0(            84) => r.first,
               probe0(            85) => sAxisMaster.tValid,
               probe0(            86) => sAxisMaster.tLast,
               probe0(            87) => r.slave.tReady,
               probe0(            88) => mAxisSlave(0).tReady,
               probe0(            89) => mAxisSlave(1).tReady,
               probe0(            90) => mAxisSlave(2).tReady,
               probe0(            91) => mAxisSlave(3).tReady,
               probe0(255 downto  92) => (others=>'0') );
  
  comb : process ( r, axisRst, sAxisMaster, mAxisSlave ) is
    variable v : RegType;
    variable m,n : integer;
  begin
    v := r;

    v.slave.tReady := '0';
    
    if v.nready /= 0 then
      for i in 0 to LANES_G-1 loop
        if mAxisSlave(i).tReady = '1' then
          v.nready (i)        := '0';
          v.masters(i).tValid := '0';
        end if;
      end loop;
    end if;

    if v.nready = 0 then
      if sAxisMaster.tValid = '1' then

        if (r.first = '1') then

          --  Insert user sequence# for maintaining alignment of interleaved streams
          v.first := '0';
          for i in 0 to LANES_G-1 loop
            axiStreamSetUserBit(MAXIS_CONFIG_G, v.masters(i), SSI_SOF_C, '1', 0);
            v.nready (i)        := '1';
            v.masters(i).tValid := '1';
            v.masters(i).tLast  := '0';
            v.masters(i).tData(SEQ_C'range) := SEQ_C;
            v.masters(i).tData(r.tSeq'range) := r.tSeq;
            v.masters(i).tKeep  := genTKeep(MAXIS_CONFIG_G.TDATA_BYTES_C);
            v.tSeq              := r.tSeq+1;
          end loop;

        else

          v.slave.tReady := '1';
          v.first        := sAxisMaster.tLast;
          for i in 0 to LANES_G-1 loop
            v.nready (i)        := '1';
            v.masters(i).tValid := '1';
            v.masters(i).tLast  := sAxisMaster.tLast;
            
            -- set user bits
            axiStreamSetUserBit(MAXIS_CONFIG_G, v.masters(i), SSI_SOF_C, '0', 0);
            if sAxisMaster.tLast = '1' then
              axiStreamSetUserBit(MAXIS_CONFIG_G, v.masters(i), SSI_EOFE_C, '0', 0);
            end if;
            
            -- distribute data
            for j in 0 to MAXIS_CONFIG_G.TDATA_BYTES_C-1 loop
              m := 8*j;
              n := 8*(LANES_G*j+i);
              v.masters(i).tData(m+7 downto m) := sAxisMaster.tData(n+7 downto n);
              v.masters(i).tKeep(j)            := sAxisMaster.tKeep(LANES_G*j+i);
            end loop;
          end loop;
        end if;
      end if;
    end if;

    sAxisSlave  <= v.slave;
    mAxisMaster <= r.masters;
    
    if axisRst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
    
  end process comb;

  seq : process ( axisClk ) is
  begin
    if rising_edge(axisClk) then
      r <= rin;
    end if;
  end process seq;
  
end top_level_app;
