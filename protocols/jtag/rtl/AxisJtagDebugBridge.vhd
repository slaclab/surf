-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI Stream Debug Bridge
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- Axi Stream to JTAG Protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxisToJtagPkg.all;

-- Connect AxisToJtag to a debug bridge IP (convenience wrapper)
entity AxisJtagDebugBridge is
   generic (
      TPD_G            : time                       := 1 ns;
      AXIS_FREQ_G      : real                       := 0.0;   -- Hz (for computing TCK period)
      AXIS_WIDTH_G     : positive range 4 to 16     := 4;     -- bytes
      CLK_DIV2_G       : positive                   := 4;     -- half-period of TCK in axisClk cycles
      MEM_DEPTH_G      : natural  range 0 to 65535  := 4;     -- size of buffer memory (0 for none)
      MEM_STYLE_G      : string                     := "auto" -- 'auto', 'block' or 'distributed'
   );
   port (
      axisClk          : in sl;
      axisRst          : in sl;

      mAxisReq         : in  AxiStreamMasterType;
      sAxisReq         : out AxiStreamSlaveType;

      mAxisTdo         : out AxiStreamMasterType;
      sAxisTdo         : in  AxiStreamSlaveType
   );
end entity AxisJtagDebugBridge;

architecture AxisJtagDebugBridgeImpl of AxisJtagDebugBridge is

   -- IP
   -- Must be generated and named DebugBridgeJtag, e.g., with TCL commands:
   --
   --    create_ip -name debug_bridge -vendor xilinx.com -library ip -module_name DebugBridgeJtag
   --    # C_DEBUG_MODE selects JTAG <-> BSCAN mode
   --    set_property -dict [list CONFIG.C_DEBUG_MODE {4}] [get_ips DebugBridgeJtag]
   --

   component DebugBridgeJtag is
     port (
       jtag_tdi : in  std_logic;
       jtag_tdo : out std_logic;
       jtag_tms : in  std_logic;
       jtag_tck : in  std_logic
     );
   end component DebugBridgeJtag;

   signal tck, tdi, tms, tdo : sl;

begin

   U_AXIS_JTAG : entity surf.AxisToJtag
      generic map (
         TPD_G        => TPD_G,
         AXIS_WIDTH_G => AXIS_WIDTH_G,
         AXIS_FREQ_G  => AXIS_FREQ_G,
         CLK_DIV2_G   => CLK_DIV2_G,
         MEM_DEPTH_G  => MEM_DEPTH_G,
         MEM_STYLE_G  => MEM_STYLE_G
      )
      port map (
         axisClk      => axisClk,
         axisRst      => axisRst,

         mAxisReq     => mAxisReq,
         sAxisReq     => sAxisReq,

         mAxisTdo     => mAxisTdo,
         sAxisTdo     => sAxisTdo,

         tck          => tck,
         tms          => tms,
         tdi          => tdi,
         tdo          => tdo
      );

   U_JTAG_BSCAN : component DebugBridgeJtag
      port map (
         jtag_tdi     => tdi,
         jtag_tdo     => tdo,
         jtag_tms     => tms,
         jtag_tck     => tck
      );

end architecture AxisJtagDebugBridgeImpl;

architecture AxisJtagDebugBridgeStub of AxisJtagDebugBridge is

   type StateType is (READY_S, SKIP_S, REPLY_S);

   type RegType is record
      state    : StateType;
      repValid : sl;
      repData  : slv(31 downto 0);
      reqReady : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => READY_S,
      repValid => '0',
      repData  => (others => '0'),
      reqReady => '1'
   );

   signal mReply : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sReq   : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal r      : RegType             := REG_INIT_C;
   signal rin    : RegType;

begin

   sReq.tReady               <= r.reqReady;
   mReply.tValid             <= r.repValid;
   mReply.tLast              <= '1';
   mReply.tData(31 downto 0) <= r.repData;

   sAxisReq                  <= sReq;
   mAxisTdo                  <= mReply;

   U_COMB : process(r, mAxisReq, sAxisTdo) is
      variable v : RegType;
   begin
      v := r;

      case (r.state) is

         when READY_S =>
            if ( mAxisReq.tValid = '1' ) then
               v.repData := ( others => '0' );
               if ( getVersion( mAxisReq.tData ) /= PRO_VERSN_C ) then
                  setVersion( PRO_VERSN_C      , v.repData );
                  setErr    ( ERR_BAD_VERSION_C, v.repData );
               elsif ( getCommand( mAxisReq.tData ) /= CMD_QUERY_C ) then
                  setErr    ( ERR_BAD_COMMAND_C, v.repData );
               else
                  setErr    ( ERR_NOT_PRESENT_C, v.repData );
               end if;
               if ( mAxisReq.tLast = '1' ) then
                  v.reqReady := '0';
               end if;
               v.repValid := '1';
               v.state    := REPLY_S;
            end if;

         when REPLY_S =>
            if ( (mAxisReq.tValid and mAxisReq.tLast and r.reqReady) = '1' ) then
               v.reqReady := '0';
            end if;
            if ( sAxisTdo.tReady = '1' ) then
               v.repValid := '0';
               if ( v.reqReady = '1' ) then
                  -- no TLAST seen yet
                  v.state := SKIP_S;
               else
                  v.reqReady := '1';
                  v.state    := READY_S;
               end if;
            end if;

         when SKIP_S =>
            if ( (mAxisReq.tValid and mAxisReq.tLast) = '1' ) then
               v.state := READY_S;
            end if;

      end case;

      rin <= v;

   end process U_comb;

   U_SEQ : process( axisClk ) is
   begin
      if ( rising_edge( axisClk ) ) then
         if ( axisRst /= '0' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process U_seq;

end architecture AxisJtagDebugBridgeStub;
