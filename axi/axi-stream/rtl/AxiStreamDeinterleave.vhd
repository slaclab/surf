------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamDeinterleave.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-02-08
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

entity AxiStreamDeinterleave is
   generic ( LANES_G        : integer := 4;
             AXIS_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C );
   port ( axisClk         : in  sl;
          axisRst         : in  sl;
          sAxisMaster     : in  AxiStreamMasterArray( LANES_G-1 downto 0 );
          sAxisSlave      : out AxiStreamSlaveArray ( LANES_G-1 downto 0 );
          mAxisMaster     : out AxiStreamMasterType;
          mAxisSlave      : in  AxiStreamSlaveType );
end AxiStreamDeinterleave;

architecture top_level_app of AxiStreamDeinterleave is

  constant SEQ_C : slv(15 downto 8) := x"55";
  
  constant MAXIS_CONFIG_C : AxiStreamConfigType := (
    TSTRB_EN_C    => false,
    TDATA_BYTES_C => LANES_G*AXIS_CONFIG_G.TDATA_BYTES_C,
    TDEST_BITS_C  => AXIS_CONFIG_G.TDEST_BITS_C,
    TID_BITS_C    => AXIS_CONFIG_G.TID_BITS_C,
    TKEEP_MODE_C  => AXIS_CONFIG_G.TKEEP_MODE_C,
    TUSER_BITS_C  => AXIS_CONFIG_G.TUSER_BITS_C,
    TUSER_MODE_C  => AXIS_CONFIG_G.TUSER_MODE_C );

  type FrameState is ( SOF_S, EOF_S, ERR_S );
  
  type RegType is record
    master  : AxiStreamMasterType;
    state   : FrameState;
    sof     : sl;
    first   : slv                 (LANES_G-1 downto 0);
    discard : slv                 (LANES_G-1 downto 0);
    slaves  : AxiStreamSlaveArray (LANES_G-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    master  => axiStreamMasterInit(MAXIS_CONFIG_C),
    state   => SOF_S,
    sof     => '0',
    first   => (others=>'1'),
    discard => (others=>'0'),
    slaves  => (others=>AXI_STREAM_SLAVE_INIT_C));
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  component ila_0
    port ( clk    : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal state_s : slv(1 downto 0);
begin

  state_s <= "00" when r.state = ERR_S else
             "01" when r.state = SOF_S else
             "10" when r.state = EOF_S else
             "11";
  
  U_ILA : ila_0
    port map ( clk     => axisClk,
               probe0( 15 downto   0) => sAxisMaster(0).tData(15 downto 0),
               probe0( 31 downto  16) => sAxisMaster(1).tData(15 downto 0),
               probe0( 47 downto  32) => sAxisMaster(2).tData(15 downto 0),
               probe0( 63 downto  48) => sAxisMaster(3).tData(15 downto 0),
               probe0(            64) => sAxisMaster(0).tValid,
               probe0(            65) => sAxisMaster(1).tValid,
               probe0(            66) => sAxisMaster(2).tValid,
               probe0(            67) => sAxisMaster(3).tValid,
               probe0(            68) => sAxisMaster(0).tLast,
               probe0(            69) => sAxisMaster(1).tLast,
               probe0(            70) => sAxisMaster(2).tLast,
               probe0(            71) => sAxisMaster(3).tLast,
               probe0( 75 downto  72) => r.discard,
               probe0( 77 downto  76) => state_s,
               probe0(            78) => r.sof,
               probe0(            79) => mAxisSlave.tReady,
               probe0(            80) => r.master.tValid,
               probe0(            81) => r.master.tLast,
               probe0( 85 downto  82) => r.first,
               probe0(255 downto  86) => (others=>'0') );

  comb : process ( r, axisRst, sAxisMaster, mAxisSlave ) is
    variable v : RegType;
    variable m,n : integer;
    variable hdrErr : sl;
    variable seqOff : Slv8Array(LANES_G-1 downto 1);
    variable notSeq : slv(LANES_G-1 downto 0);
    variable ready  : sl;
    variable tready : slv(LANES_G-1 downto 0);
    variable tlast  : slv(LANES_G-1 downto 0);
  begin
    v := r;

    v.sof := '0';
    
    tready := (others=>'0');

    for i in 0 to LANES_G-1 loop
      tlast(i) := sAxisMaster(i).tLast;
    end loop;

    -- process acknowledge
    if mAxisSlave.tReady = '1' then
      v.master.tValid := '0';
    end if;

    -- wait for all streams to contribute
    ready := '1';
    for i in 0 to LANES_G-1 loop
      if sAxisMaster(i).tValid='0' then
        ready := '0';
      end if;
    end loop;

    case r.state is
      when SOF_S =>
        if ready = '1' then
          if allBits(r.first,'1') then  -- wait for all lanes to start
            --  test sequence numbers
            notSeq := (others=>'0');
            for i in 0 to LANES_G-1 loop
              if sAxisMaster(i).tData(SEQ_C'range)/=SEQ_C then
                notSeq(i) := '1';
              end if;
            end loop;
            if notSeq/=0 then
              v.discard := notSeq;
              v.state   := ERR_S;
            else
              hdrErr := '0';
              for i in 1 to LANES_G-1 loop
                seqOff(i) := sAxisMaster(i).tData(7 downto 0) - sAxisMaster(0).tData(7 downto 0);
                if sAxisMaster(0).tData(7 downto 0)/=sAxisMaster(i).tData(7 downto 0) then
                  hdrErr := '1';
                end if;
              end loop;
              if hdrErr = '1' then    -- sequence mismatch - discard late lanes
                v.discard := (others=>'0');
                for i in 1 to LANES_G-1 loop
                  if seqOff(i)(7) = '1' then
                    v.discard(i) := '1';
                  elsif seqOff(i)/=0 then
                    v.discard(0) := '1';
                  end if;
                end loop;
                v.state := ERR_S;
              else
                tready    := (others=>'1');
                v.discard := (others=>'0');
                v.sof     := '1';
                v.state   := EOF_S;
              end if;
            end if;
          else
            v.discard := not r.first;
            v.state   := ERR_S;
          end if;
        end if;
      when EOF_S =>
        if ready = '1' and v.master.tValid = '0' then
          tready   := (others=>'1');
          v.master := sAxisMaster(0);
          -- assemble the data
          for i in 0 to LANES_G-1 loop
            for j in 0 to AXIS_CONFIG_G.TDATA_BYTES_C-1 loop
              m := 8*j;
              n := 8*(LANES_G*j+i);
              v.master.tData(n+7 downto n) := sAxisMaster(i).tData(m+7 downto m);
              v.master.tKeep(LANES_G*j+i)  := sAxisMaster(i).tKeep(j);
            end loop;
          end loop;
          -- user bits
          axiStreamSetUserBit(AXIS_CONFIG_G, v.master, SSI_SOF_C , r.sof, 0);
          -- cleanup
          if    allBits(tlast,'0') then
            v.discard      := (others=>'0');
            v.master.tLast := '0';
            axiStreamSetUserBit(AXIS_CONFIG_G, v.master, SSI_EOFE_C, '0');
          elsif allBits(tlast,'1') then
            v.discard      := (others=>'0');
            v.master.tLast := '1';
            axiStreamSetUserBit(AXIS_CONFIG_G, v.master, SSI_EOFE_C, '0');
            v.state        := SOF_S;
          else
            v.discard      := not tlast;
            v.master.tLast := '1';
            axiStreamSetUserBit(AXIS_CONFIG_G, v.master, SSI_EOFE_C, '0');
            v.state        := ERR_S;
          end if;
        end if;
      when ERR_S =>
        for i in 0 to LANES_G-1 loop
          if r.discard(i) = '1' then
            tready   (i) := '1';  -- sink
            v.discard(i) := not sAxisMaster(i).tLast;
          end if;
          if v.discard=0 then
            v.state := SOF_S;
          end if;
        end loop;
    end case;

    --  start of packet is first tValid after tLast acknowledged
    for i in 0 to LANES_G-1 loop
      v.slaves(i).tReady := tready(i);
      if sAxisMaster(i).tValid = '1' and v.slaves(i).tReady = '1' then
        v.first (i) := sAxisMaster(i).tLast;
      end if;
    end loop;
    
    sAxisSlave  <= v.slaves;
    mAxisMaster <= r.master;
    
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
