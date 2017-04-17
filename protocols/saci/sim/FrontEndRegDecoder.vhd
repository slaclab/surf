-------------------------------------------------------------------------------
-- File       : FrontEndRegDecoder.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-05-07
-- Last update: 2013-03-05
-------------------------------------------------------------------------------
-- Description: Decodes register addresses from the Front End interface.
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
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.SynchronizePkg.all;
use work.Version.all;
use work.FrontEndPkg.all;
use work.SaciMasterPkg.all;

entity FrontEndRegDecoder is
  
  generic (
    DELAY_G : time := 1 ns);

  port (
    sysClk : in sl;
    sysRst : in sl;

    -- Interface to front end
    frontEndRegCntlOut : in  FrontEndRegCntlOutType;
    frontEndRegCntlIn  : out FrontEndRegCntlInType;

    -- Interface to SACI Master
    saciMasterIn  : out SaciMasterInType;
    saciMasterOut : in  SaciMasterOutType);

end entity FrontEndRegDecoder;

architecture rtl of FrontEndRegDecoder is

  constant FRONT_END_REG_WRITE_C : sl := '1';
  constant FRONT_END_REG_READ_C  : sl := '0';

  -- Define local registers addresses
  constant VERSION_REG_ADDR_C    : natural := 0;
  constant SACI_RESET_REG_ADDR_C : natural := 1;

  -- Address block constants
  subtype ADDR_BLOCK_RANGE_C is natural range 23 downto 20;
  subtype LOCAL_REGS_ADDR_RANGE_C is natural range 19 downto 0;  --log2(NUM_LOCAL_REGS_C)-1 downto 0;
  constant LOCAL_REGS_ADDR_C : slv(3 downto 0) := "0000";
  constant SACI_REGS_ADDR_C  : slv(3 downto 0) := "0001";

  type RegType is record
    frontEndRegCntlIn : FrontEndRegCntlInType;  -- Outputs to FrontEnd module
    saciMasterIn      : SaciMasterInType;       -- Outputs to Saci Master
    saciMasterAckSync : SynchronizerType;
  end record RegType;

  signal r, rin : RegType;

begin

  sync : process (sysClk, sysRst) is
  begin
    if (sysRst = '1') then
      r.frontEndRegCntlIn.regAck    <= '0'             after DELAY_G;
      r.frontEndRegCntlIn.regDataIn <= (others => '0') after DELAY_G;
      r.frontEndRegCntlIn.regFail   <= '0'             after DELAY_G;

      r.saciMasterIn.req    <= '0'             after DELAY_G;
      r.saciMasterIn.reset  <= '0'             after DELAY_G;
      r.saciMasterIn.chip   <= (others => '0') after DELAY_G;
      r.saciMasterIn.op     <= '0'             after DELAY_G;
      r.saciMasterIn.cmd    <= (others => '0') after DELAY_G;
      r.saciMasterIn.addr   <= (others => '0') after DELAY_G;
      r.saciMasterIn.wrData <= (others => '0') after DELAY_G;

      r.saciMasterAckSync <= SYNCHRONIZER_INIT_0_C after DELAY_G;

    elsif (rising_edge(sysClk)) then
      r <= rin after DELAY_G;
    end if;
  end process sync;

  comb : process (r, frontEndRegCntlOut, saciMasterOut) is
    variable rVar         : RegType;
    variable addrIndexVar : integer;
  begin
    rVar := r;

    rVar.frontEndRegCntlIn.regAck    := '0';
    rVar.frontEndRegCntlIn.regDataIn := (others => '0');
    rVar.frontEndRegCntlIn.regFail   := '0';

    rVar.saciMasterIn.req    := '0';
    rVar.saciMasterIn.reset  := '0';
    rVar.saciMasterIn.chip   := (others => '0');
    rVar.saciMasterIn.op     := '0';
    rVar.saciMasterIn.cmd    := (others => '0');
    rVar.saciMasterIn.addr   := (others => '0');
    rVar.saciMasterIn.wrData := (others => '0');

    synchronize(saciMasterOut.ack, r.saciMasterAckSync, rVar.saciMasterAckSync);


    if (frontEndRegCntlOut.regAddr(ADDR_BLOCK_RANGE_C) = SACI_REGS_ADDR_C) then
      -- SACI regs being accessed
      -- Pass FrontEndCntl io right though
      -- Will revert back when frontEndRegCntlOut.regReq falls
      rVar.saciMasterIn.req            := frontEndRegCntlOut.regReq;
      rVar.saciMasterIn.op             := frontEndRegCntlOut.regOp;
      rVar.saciMasterIn.reset          := '0';
      rVar.saciMasterIn.addr           := frontEndRegCntlOut.regAddr(11 downto 0);
      rVar.saciMasterIn.cmd            := frontEndRegCntlOut.regAddr(18 downto 12);
      rVar.saciMasterIn.chip           := frontEndRegCntlOut.regAddr((SACI_CHIP_WIDTH_C-1)+19 downto 19);
      rVar.saciMasterIn.wrData         := frontEndRegCntlOut.regDataOut;
      rVar.frontEndRegCntlIn.regAck    := r.saciMasterAckSync.sync;
      rVar.frontEndRegCntlIn.regFail   := saciMasterOut.fail;
      rVar.frontEndRegCntlIn.regDataIn := saciMasterOut.rdData;

    -- Wait for an access request
    elsif (frontEndRegCntlOut.regAddr(ADDR_BLOCK_RANGE_C) = LOCAL_REGS_ADDR_C and
           frontEndRegCntlOut.regReq = '1') then

      -- Local Regs being accessed
      -- Peform register access
      addrIndexVar := to_integer(unsigned(frontEndRegCntlOut.regAddr(LOCAL_REGS_ADDR_RANGE_C)));
      case (addrIndexVar) is

        when VERSION_REG_ADDR_C =>
          rVar.frontEndRegCntlIn.regDataIn := FPGA_VERSION_C;
          rVar.frontEndRegCntlIn.regAck := '1';

        when SACI_RESET_REG_ADDR_C =>
          if (frontEndRegCntlOut.regOp = FRONT_END_REG_WRITE_C) then
            rVar.saciMasterIn.reset       := '1';
            rVar.frontEndRegCntlIn.regAck := r.saciMasterAckSync.sync;
          end if;

        when others =>
          null;

      end case;

    elsif (frontEndRegCntlOut.regReq = '1') then
      -- Ack non existant registers too so they don't fail
      rVar.frontEndRegCntlIn.regAck := '1';
    end if;

    rin <= rVar;

    frontEndRegCntlIn <= r.frontEndRegCntlIn;
    saciMasterIn      <= r.saciMasterIn;
    
  end process comb;

end architecture rtl;
