-------------------------------------------------------------------------------
-- File       : AxiStreamBytePackerDSP.vhd.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Byte packer for AXI-Stream. 
-- Accepts an incoming stream and packs data into the outbound stream. 
-- Similiar to AxiStreamResize, but allows an input and output width to have 
-- non multiples and for the input size to be dynamic. 
-- This module does not downsize and creates more complex combinitorial logic 
-- than in AxiStreamResize.
-- Ready handshaking is not supported.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamBytePackerDSP is
   generic (
      TPD_G           : time                := 1 ns;
      SLAVE_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      axiClk       : in  sl;
      axiRst       : in  sl;
      -- Inbound frame
      sAxisMaster  : in  AxiStreamMasterType;
      -- Outbound frame
      mAxisMaster  : out AxiStreamMasterType);
end AxiStreamBytePackerDSP;

architecture rtl of AxiStreamBytePackerDSP is

   constant MAX_IN_BYTE_C  : integer := SLAVE_CONFIG_G.TDATA_BYTES_C-1;
   constant MAX_OUT_BYTE_C : integer := MASTER_CONFIG_G.TDATA_BYTES_C-1;

   type RegType is record
      byteCount  : integer range 0 to MAX_OUT_BYTE_C;
      inTop      : integer range 0 to MAX_IN_BYTE_C;
      inMaster   : AxiStreamMasterType;
      curMaster  : AxiStreamMasterType;
      nxtMaster  : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
      tdata      : Slv48Array(7 downto 0);
      tuser      : Slv48Array(SLAVE_CONFIG_G.TUSER_BITS_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteCount  => 0,
      inTop      => 0,
      inMaster   => AXI_STREAM_MASTER_INIT_C,
      curMaster  => AXI_STREAM_MASTER_INIT_C,
      nxtMaster  => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C,
      tdata      => (others=>(others=>'0')),
      tuser      => (others=>(others=>'0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   procedure fieldShift( indata  : in    slv;
                         outdata : inout Slv48Array;
                         curdata : inout slv;
                         bmult   : in    slv;
                         flen    : in    integer;
                         fsize   : in    integer) is
     variable data : slv(MAX_IN_BYTE_C downto 0);
   begin
--     r.inMaster,v.tdata,v.curMaster.tData,byte_mult,r.inTop,8);
     for i in 0 to fsize-1 loop
       data := (others=>'0');
       for j in 0 to MAX_IN_BYTE_C loop
         if j <= flen then
           data(j) := indata(j*fsize+i);
         end if;
       end loop;
       outdata(i) := outdata(i) + data * bmult;
       for j in 0 to 47 loop
         curdata(fsize*j+i) := outdata(i)(j);
       end loop;    
     end loop;
   end procedure;
   
begin

   assert (MAX_IN_BYTE_C < 18)
     report "Input data width exceeds DSP capability" severity failure;

   assert (MAX_OUT_BYTE_C < 48)
     report "Output data width exceeds DSP capability" severity failure;

   comb : process (r, axiRst, sAxisMaster ) is
      variable v     : RegType;
      variable valid : sl;
      variable last  : sl;
      variable user  : slv(SLAVE_CONFIG_G.TUSER_BITS_C-1 downto 0);
      --variable data  : slv(7 downto 0);
      variable mult  : slv(MAX_OUT_BYTE_C downto 0);
      variable data  : slv(MAX_IN_BYTE_C  downto 0);
      variable byte_mult : slv(17 downto 0);
      constant tzero : slv(46-MAX_OUT_BYTE_C downto 0) := (others=>'0');
   begin
      v := r;

      -- Register input and compute size
      v.inMaster := sAxisMaster;
      v.inTop    := getTKeep(sAxisMaster.tKeep(MAX_IN_BYTE_C downto 0),SLAVE_CONFIG_G)-1;
      if v.inMaster.tValid = '0' then
        v.inTop  := 0;
      end if;

      -- Pending output from current
      if r.curMaster.tValid = '1' then
         v.outMaster := r.curMaster;
         v.curMaster := r.nxtMaster;
         v.nxtMaster := AXI_STREAM_MASTER_INIT_C;
         v.nxtMaster.tKeep := (others=>'0');
         -- shift the data
         for i in 0 to 7 loop
           v.tdata(i) := tzero & r.tdata(i)(2*MAX_OUT_BYTE_C+1 downto MAX_OUT_BYTE_C+1);
           for j in 0 to 47 loop
             v.curMaster.tData(8*j+i) := v.tdata(i)(j);
           end loop;
         end loop;
         -- shift the user bits
         for i in 0 to SLAVE_CONFIG_G.TUSER_BITS_C-1 loop
           v.tuser(i) := tzero & r.tuser(i)(2*MAX_OUT_BYTE_C+1 downto MAX_OUT_BYTE_C+1);
           for j in 0 to 47 loop
             v.curMaster.tUser(SLAVE_CONFIG_G.TUSER_BITS_C*j+i) := v.tuser(i)(j);
           end loop;
         end loop;
      else
         v.outMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

      -- Data is valid
      if r.inMaster.tValid = '1' then

         -- Use DSPs to reduce combinatorics in data field
         byte_mult := (others=>'0');
         if r.nxtMaster.tValid = '1' then
           byte_mult(MAX_OUT_BYTE_C+1) := '1';
         else
           byte_mult(r.byteCount) := '1';
         end if;
         -- handle tData
         fieldShift(r.inMaster.tData, v.tdata, v.curMaster.tData, byte_mult, r.inTop, 8);
         -- handle tUser
         fieldShift(r.inMaster.tUser, v.tuser, v.curMaster.tUser, byte_mult, r.inTop, SLAVE_CONFIG_G.TUSER_BITS_C);
         
         -- Process each input byte
         for i in 0 to MAX_IN_BYTE_C loop
            if i <= r.inTop then

               -- Extract values for each iteration
               last  := r.inMaster.tLast and toSl(i=r.inTop);
               valid := toSl(v.byteCount = MAX_OUT_BYTE_C) or last;

               -- Still filling current data
               if v.curMaster.tValid = '0' then 

                  v.curMaster.tKeep(v.byteCount) := '1';
                  v.curMaster.tValid := valid;
                  v.curMaster.tLast  := last;

               -- Filling next data
               elsif v.nxtMaster.tValid = '0' then

                  v.nxtMaster.tKeep(v.byteCount) := '1';
                  v.nxtMaster.tValid := valid;
                  v.nxtMaster.tLast  := last;

               end if;

               if v.byteCount = MAX_OUT_BYTE_C or last = '1' then
                  v.byteCount := 0;
               else
                  v.byteCount := v.byteCount + 1;
               end if;
            end if;
         end loop;
      end if;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
         v.curMaster.tKeep := (others=>'0');
         v.nxtMaster.tKeep := (others=>'0');
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;

   end process;

   seq : process (axiClk) is
   begin  
      if (rising_edge(axiClk)) then
         r <= rin;
      end if;
   end process;

end architecture rtl;

