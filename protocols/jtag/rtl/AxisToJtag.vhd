-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI stream to JTAG
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

--
-- This module implements a simple protocol for encoding XVC transactions over
-- an AXI stream. Part of this is support for unreliable transport protocols
-- (by means of a memory buffer and transaction IDs).
-- Once the protocol header is processed the stream is delegated to the
-- AxisToJtagCore module.
--
-- INCOMING STREAM
--
-- The incoming Stream consists of consecutive words of AXIS_WIDTH_G bytes,
-- must be framed with 'TLAST' and is expected to have the following format :
--
--    Header Word [, Payload ]
--
-- The header word is defined as
--
--   [31:30]  Protocol Version -- currently "00"
--   [29:28]  Command
--   [27:00]  Command-specific parameter(s)
--
-- Note that if the core is configured for a stream width (AXIS_WIDTH_G) > 4
-- then the header is padded up to the desired width, i.e., the paylod must
-- be word-aligned.
--
-- Each command word is answered with a reply word on the outgoing stream
-- (see below).
--
-- The following commands are currently defined:
--
--      "00"  QUERY: request basic features such as word length, memory depth.
--
--            Payload: NONE, i.e., TLAST should be asserted with this command.
--
--      "01"  JTAG: shift jtag vectors. The vectors are shipped in the payload.
--            The parameter bits for this command are defined as follows:
--
--            [27:20] Transaction ID; this is used when the core is configured
--                    with MEM_DEPTH_G > 0 in order to support a non-reliable
--                    transport.
--            [19:00] JTAG vector length (in bits). The payload must provide
--                    2*ceil( length / AXIS_WIDTH_G ) words of TMS/TDI vector
--                    data. I.e., the length refers to the length of a single
--                    TMS or TDI vector.
--                    !!!!!!!
--                     NOTE: the number in [19:00] encodes the actual number
--                           minus 1. E.g., a value of 0 transmits one TMS
--                           and one TDI bit. Two payload words are expected
--                           in this example.
--                    !!!!!!!
--
--            Payload: sequence of words from the TMS and TDI bit-vectors:
--
--                    TMS_WORD, TDI_WORD, TMS_WORD, TDI_WORD, ...
--
--                    Note that the user must format the stream accordingly
--                    and therefore must be aware of the stream width. This
--                    parameter is returned by the QUERY command.
--
--                    If the number of bits supplied does not fill the last
--                    word then the relevant bits must be lsb/right-aligned
--                    in the last word.
--
--                    TLAST must be asserted during the transmission of the
--                    last TDI/payload word.
--
-- OUTGOING STREAM
--
-- The outgoing stream consists of consecutive words of AXIS_WIDTH_G bytes
-- and is framed with 'TLAST'. Each reply has the following format:
--
--    Header Word [, Payload ]
--
-- The header word is defined as
--
--   [31:30]  Protocol Version; if the user supplies an unsupported protocol
--            version in the request header then the reply contains an error
--            code (see below) and the protocol version in the reply is set
--            to the supported version.
--
--   [29:28]  Command -- the request command is returned unless an error occurred;
--            in case of an error the command bits in the reply are:
--
--            "10"  ERROR: An error was detected. The 8 least-significant bits
--                  [7:0] contain an error code:
--                  1: bad protocol version; the protocol version in the reply
--                     is set to the supported version.
--                  2: bad/unsupported command code
--                  3: truncated input stream (TLAST detected before the
--                     first TDI word was received). Note that a premature
--                     TLAST which is detected after the first TDI word
--                     does NOT flag an error but yields a truncated reply
--                     (less TDO words than requested by the number of bits).
--
--            "00"  QUERY: the response to a QUERY command encodes information
--                  in the command-specific bits:
--
--                 [ 3: 0] AXIS_WIDTH_G - 1. I.e., this field encodes the
--                         word size (minus one) used by the core. This information
--                         is important for formatting the stream.
--                 [19: 4] MEM_DEPTH_G. Indicates how much memory (if any) was
--                         configured in words.
--                 [27:20] TCK period. Encoded as
--
--                                          200Mhz     1
--                            round{ log10( ------- ) --- 256 }
--                                           Ttck      4
--
--                        With the special value 0 representing 'unknown'.
--
--
--            "01"  JTAG: the response to a JTAG command is a sequence of
--                  TDO words which form the TDO bit vector. The vector
--                  stored in little-endian format (first bit of the vector
--                  is the LSB of the first TDO word).
--                  If the number of JTAG bits does not fill the last TDO
--                  word completely then the relevant bits are right-
--                  aligned.
--
-- RELIABILITY SUPPORT
--
-- If the transport mechanism contains unreliable segments with a potential for
-- data loss then a simple retry mechanism is not suitable because JTAG operations
-- are not necessarily idempotent.
-- The core can be configured to use internal memory (MEM_DEPTH_C > 0) in which
-- case it stores the last JTAG TDO response in memory.
-- When the next JTAG command arrives the core inspects the 'transaction ID' field
-- of the command and if it is identical with the ID submitted along with the previous
-- transaction then the core detects a retried operation and does not actually execute
-- it again on JTAG but plays back the stored TDO response to the requestor.

entity AxisToJtag is
   generic (
      TPD_G            : time                       := 1 ns;
      -- Clock frequency in Hz. This information is used for computing
      -- the JTAG clock frequency which is sent as part of a QUERY reply.
      -- If unset (=0.0) then this will cause the XVC server (software)
      -- to always return the requested (and not the true) TCK frequency
      -- in the XVC 'settck' command.
      AXIS_FREQ_G      : real                       := 0.0;
      -- Width in bytes of the TDATA; this module does not support TKEEP
      -- nor resizing the I/O streams.
      AXIS_WIDTH_G     : positive range 4 to 16     := 4;
      -- Half period of TCK in axisClk cycles. I.e., for a given TCK
      -- frequency set CLK_DIV2_G = round( AXIS_FREQ_G / TCK_FREQ / 2 );
      CLK_DIV2_G       : positive                   := 4;
      -- Depth of buffer memory (in units of words of width AXIS_WIDTH_G)
      -- Setting to zero disables memory.
      MEM_DEPTH_G      : natural  range 0 to 65535  := 4;
      -- Memory type inference (Vivado) - use 'auto', 'block' or 'distributed'
      MEM_STYLE_G      : string                     := "auto"
   );
   port (
      axisClk          : in sl;
      axisRst          : in sl;

      mAxisReq         : in  AxiStreamMasterType;
      sAxisReq         : out AxiStreamSlaveType;

      mAxisTdo         : out AxiStreamMasterType;
      sAxisTdo         : in  AxiStreamSlaveType;

      -- JTAG

      tck              : out sl;
      tdi              : out sl;
      tms              : out sl;
      tdo              : in  sl
   );
end entity AxisToJtag;

architecture AxisToJtagImpl of AxisToJtag is

   constant WORD_SIZE_C : positive := 8*AXIS_WIDTH_G;

   type     MemType   is array (0 to MEM_DEPTH_G - 1) of slv(WORD_SIZE_C - 1 downto 0);

   subtype  AddrType  is unsigned( bitSize(MEM_DEPTH_G) downto 0 ); -- one guard bit

   type     StateType is (IDLE_S, SEND_REP_S, WAIT_STARTED_S, WAIT_HDR_READY_S, WAIT_STOPPED_S, REPLAY_S);

   constant ADDR_ZERO_C : AddrType := (others => '0');

   -- Stream selector port indices
   constant LOCL_OSTRM_PORT   : natural := 0;
   constant JTAG_OSTRM_PORT   : natural := 1;

   constant TCK_FREQ_REF_C    : real    := 2.0E+8;
   constant TCK_FREQ_C        : real    := ite( AXIS_FREQ_G = 0.0, TCK_FREQ_REF_C, AXIS_FREQ_G/(2.0*real(CLK_DIV2_G)) );
   constant TCK_LOG_RAT_C     : real    := ieee.math_real.log10( TCK_FREQ_REF_C / TCK_FREQ_C );
   constant TCK_BITS_C        : natural range 0 to 255 := natural( ieee.math_real.round( TCK_LOG_RAT_C * 256.0/4.0 ) );

   -- State Record
   type RegType is record
      state       : StateType;
      nstate      : StateType;
      replyData   : AxiStreamMasterType;
      tLastSeen   : sl;
      ackInput    : sl;
      passTdo     : sl;
      passTdi     : sl;
      ridx        : AddrType;
      widx        : AddrType;
      memValid    : boolean;
      xid         : XidType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      nstate      => IDLE_S,
      replyData   => AXI_STREAM_MASTER_INIT_C,
      tLastSeen   => '0',
      ackInput    => '0',
      passTdo     => '0',
      passTdi     => '0',
      ridx        => ADDR_ZERO_C,
      widx        => ADDR_ZERO_C,
      memValid    => false,
      xid         => (others => '0')
   );

   function xidIsNew(
      data       : in slv;
      xid        : in XidType;
      memValid   : in boolean
   ) return boolean is
   begin
      if ( MEM_DEPTH_G = 0 or not memValid ) then
         return true;
      else
         return getXid(data) /= xid;
      end if;
   end function xidIsNew;

   function checkLen(
      data      : in slv
   ) return boolean is
      -- one guard bit more than LenType
      subtype  UNum  is unsigned(LenType'left + 1 downto LenType'right);
      constant ALGN_C : natural := log2( WORD_SIZE_C );
      constant ONE_C  : UNum    := to_unsigned( 1, UNum'length );
      variable len    : UNum;
      variable inc    : UNum;
   begin
      if ( MEM_DEPTH_G > 0 ) then
         -- passed value is true length - 1
         len := ( '0' & unsigned(getLen( data )) ) + 1;
         inc := shift_left( ONE_C, ALGN_C ) - 1;
         len := shift_right( len + inc, ALGN_C );
         return len <= MEM_DEPTH_G;
      else
         return true;
      end if;
   end function;

   procedure setQueryData(
      wordLength : in natural range 4 to    16;
      memDepth   : in natural range 0 to 65535;
      data : inout slv
   ) is
   begin
      data(LEN_SHIFT_C + LEN_WIDTH_C - 1 downto LEN_SHIFT_C) := (others => '0');
      data(QWL_SHIFT_C + QWL_WIDTH_C - 1 downto QWL_SHIFT_C) := toSlv( wordLength - 1, QWL_WIDTH_C );
      data(QMS_SHIFT_C + QMS_WIDTH_C - 1 downto QMS_SHIFT_C) := toSlv( memDepth      , QMS_WIDTH_C );
      data(QPD_SHIFT_C + QPD_WIDTH_C - 1 downto QPD_SHIFT_C) := toSlv( TCK_BITS_C    , QPD_WIDTH_C );
   end procedure setQueryData;

   procedure sendHeaderNow(
      v          : inout RegType
   ) is
   begin
      v.replyData.tValid := '1';
      v.replyData.tLast  := '1';
      v.state            := SEND_REP_S;
   end procedure sendHeaderNow;

   signal r           : RegType := REG_INIT_C;

   signal rin         : RegType;

   -- group signals so it's easier not to forget one
   -- in the combinatorial sensitivity list...
   type CombSigType is record
      mIb         : AxiStreamMasterArray(1 downto 0);
      sIb         : AxiStreamSlaveArray (1 downto 0);
      mOb         : AxiStreamMasterType;
      sOb         : AxiStreamSlaveType;

      mTdo        : AxiStreamMasterType;
      sTdo        : AxiStreamSlaveType;

      mTdi        : AxiStreamMasterType;
      sTdi        : AxiStreamSlaveType;

      coreRunning : sl;

      locConsumed : sl;

      sAxisReqLoc : AxiStreamSlaveType;

      lastTdi     : sl;
      lastReq     : sl;
      lastTdo     : sl;
      tdoXfer     : sl;
      tdoWen      : sl;
      tdoRen      : sl;
   end record CombSigType;

   signal s            : CombSigType;

   -- buffer memory
   signal bufMem       : MemType;

   attribute ram_style : string;

   attribute ram_style of bufMem : signal is MEM_STYLE_G;

   -- memory readout port
   signal memOut : slv(WORD_SIZE_C - 1 downto 0);

begin
   assert (AXIS_FREQ_G >= 0.0)
      report "AXIS_FREQ_G cannot be negative"
      severity failure;

   assert (MEM_STYLE_G = "auto" or MEM_STYLE_G = "distributed" or MEM_STYLE_G = "block")
      report "MEM_STYLE_G must be one of 'auto', 'distributed' or 'block'"
      severity failure;

   -- Control flow of the input stream to the AxisToJtagCore.
   -- We stop the flow while inspecting the header or during
   -- playback from memory (when we discard the input stream)
   P_MUX_TDI : process(r, mAxisReq, s)
      variable vM : AxiStreamMasterType;
      variable vS : AxiStreamSlaveType;
   begin
      vM := mAxisReq;
      vS := s.sTdi;
      if ( r.passTdi = '0' ) then
         vM.tValid := '0';
         vS.tReady := r.ackInput;
      end if;
      s.mTdi        <= vM;
      s.sAxisReqLoc <= vS;
   end process P_MUX_TDI;

   -- stream wiring
      -- request/input stream slave
   sAxisReq      <= s.sAxisReqLoc;

   -- output stream; splice in TKEEP
   P_TKEEP : process(s.mOb) is
      variable v : AxiStreamMasterType;
   begin
      v := s.mOb;
      if (v.tKeep'left > AXIS_WIDTH_G) then -- avoid critical warning
         v.tKeep(v.tKeep'left     downto AXIS_WIDTH_G) := (others => '0');
      end if;
      v.tKeep(AXIS_WIDTH_G - 1 downto            0) := (others => '1');
      v.tStrb                                       := v.tKeep;
      mAxisTdo   <= v;
   end process P_TKEEP;

   s.sOb         <= sAxisTdo;

      -- streams into the StreamSelector
      -- port 0 is locally generated data
      -- port 1 is output from the AxisToJtagCore
   s.mIb(LOCL_OSTRM_PORT)      <= r.replyData;
   s.mIb(JTAG_OSTRM_PORT)      <= s.mTdo;

   s.sTdo        <= s.sIb(JTAG_OSTRM_PORT);

   -- various combinatorial signals
     -- word consumed by stream 0 into the selector/mux
     -- (this is the stream generated by this module)
   s.locConsumed <= s.sIb(LOCL_OSTRM_PORT).tReady and s.mIb(LOCL_OSTRM_PORT).tValid;

     -- last word of incoming stream transferred
   s.lastReq     <= (mAxisReq.tValid and s.sAxisReqLoc.tReady and mAxisReq.tLast);
     -- last word passed through to the AxisToJtagCore
   s.lastTdi     <= (r.passTdi and s.lastReq);
     -- output stream transfer
   s.tdoXfer     <= (s.sTdo.tReady and s.mTdo.tValid);
     -- last output stream transfer
   s.lastTdo     <= (s.tdoXfer     and s.mTdo.tLast );
     -- write-enable for buffer memory
   s.tdoWen      <= (s.tdoXfer     and r.passTdo    );

     -- read-enable for buffer memory
   s.tdoRen <= ite( (r.state = REPLAY_S) , s.locConsumed, '1' );


   -- A stream multiplexer; depending on 'sel' either Ib(0) or Ib(1)
   -- is routed to Ob.
   -- We use this to splice locally generated info (reply header and
   -- memory playback data) into the output stream.
   U_MUX  : entity surf.AxiStreamSelector
      generic map (
         TPD_G           => TPD_G
      )
      port map (
         clk             => axisClk,
         rst             => axisRst,

         sel             => r.passTdo,

         mIb             => s.mIb,
         sIb             => s.sIb,
         mOb             => s.mOb,
         sOb             => s.sOb
      );

   -- The core which does all the JTAG work (while this module deals with
   -- the protocol and housekeeping.
   U_JTAG : entity surf.AxisToJtagCore
      generic map (
         TPD_G           => TPD_G,
         AXIS_WIDTH_G    => AXIS_WIDTH_G,
         LEN_POS0_G      => LEN_SHIFT_C,
         LEN_POSN_G      => (LEN_SHIFT_C + LEN_WIDTH_C - 1),
         CLK_DIV2_G      => CLK_DIV2_G
      )
      port map (
         axisClk         => axisClk,
         axisRst         => axisRst,

         mAxisTmsTdi     => s.mTdi,
         sAxisTmsTdi     => s.sTdi,

         mAxisTdo        => s.mTdo,
         sAxisTdo        => s.sTdo,

         running         => s.coreRunning,

         tck             => tck,
         tdi             => tdi,
         tms             => tms,
         tdo             => tdo
      );

   P_COMB : process(r, mAxisReq, sAxisTdo, s, memOut)
      variable v : RegType;
   begin

      v := r;

      case r.state is
         when IDLE_S =>
            v.tLastSeen := '0';
            if ( mAxisReq.tValid = '1' ) then
               -- got a request

               -- echo as reply
               v.replyData        := mAxisReq;
               v.replyData.tValid := '0';

               v.ackInput         := '1'; -- consume the header word
               v.tLastSeen        := mAxisReq.tLast;

               v.ridx             := ADDR_ZERO_C;

               if ( getVersion( mAxisReq.tData ) /= PRO_VERSN_C ) then
                  -- let them know which version we support
                  setVersion( PRO_VERSN_C, v.replyData.tData );
                  setErr( ERR_BAD_VERSION_C, v.replyData.tData );
                  sendHeaderNow( v );
               else
                  case getCommand( mAxisReq.tData ) is

                     when CMD_QUERY_C =>
                        setQueryData( AXIS_WIDTH_G, MEM_DEPTH_G, v.replyData.tData );
                        sendHeaderNow( v );
                        -- assume a new connection
                        v.memValid := false;

                     when CMD_TRANS_C =>
                        if ( mAxisReq.tLast = '1' ) then
                           setErr( ERR_TRUNCATED_C, v.replyData.tData );
                           sendHeaderNow( v );
                        else
                           if ( not checkLen( mAxisReq.tData )  ) then
                              setErr( ERR_TRUNCATED_C, v.replyData.tData );
                              sendHeaderNow( v );
                           elsif xidIsNew( mAxisReq.tData, r.xid, r.memValid ) then
                              v.widx             := ADDR_ZERO_C;
                              v.xid              := getXid( maxisReq.tData );
                              v.state            := WAIT_STARTED_S;
                              v.ackInput         := '0'; -- pass on to processor
                              v.passTdi          := '1';
                              v.memValid         := false;
                           else
                              v.replyData.tValid := '1';
                              v.replyData.tLast  := '0';
                              v.state            := REPLAY_S;
                              v.ridx             := ADDR_ZERO_C + 1;
                           end if;
                        end if;

                     when others =>
                        setErr( ERR_BAD_COMMAND_C, v.replyData.tData );
                        sendHeaderNow( v );
                  end case;
               end if;

            end if;

         -- when we enter this state then the outgoing header is
         -- not released yet (replyData.tValid = 0); so we can
         -- send an error if we receive a tLast on the requesting
         -- stream before the processor has even started.
         when WAIT_STARTED_S =>
            if ( s.coreRunning = '1' ) then
               if ( s.lastTdi = '1' ) then
                  v.passTdi := '0';
               end if;
               v.state            := WAIT_HDR_READY_S;
               -- release header
               v.replyData.tValid := '1';
            elsif ( s.lastReq = '1' ) then
               -- early TLAST, before the core has started
               setErr( ERR_TRUNCATED_C, v.replyData.tData );
               v.passTdi   := '0'; -- switch back to listening to the header
               v.tLastSeen := '1';
               sendHeaderNow( v );
            end if;

         when SEND_REP_S =>
            -- wait in this state until the request has been consumed by us
            -- and the reply has gone out (absorbed by the Selector).
            if ( r.tLastSeen = '0' and s.lastReq = '1' ) then
               v.tLastSeen := '1';
            end if;
            if ( v.tLastSeen = '1' ) then
            	v.ackInput := '0';
            end if;
            if ( s.locConsumed = '1' ) then
               v.replyData.tValid := '0';
            end if;
            -- use just updated values
            if ( v.replyData.tValid = '0' and v.tLastSeen = '1' ) then
               v.state             := v.nstate;
            end if;

         when WAIT_HDR_READY_S =>
            if ( s.lastTdi = '1' ) then
               v.passTdi := '0';
            end if;
            if ( s.locConsumed = '1' ) then
               -- we may switch the outgoing stream
               -- over to the processor
               v.passTdo          := '1';
               v.replyData.tValid := '0';
               v.state            := WAIT_STOPPED_S;
            end if;

         when WAIT_STOPPED_S =>
            if ( s.lastTdi = '1' ) then
               -- switch input stream back to header processing
               v.passTdi := '0';
            end if;
            if ( s.lastTdo = '1' ) then
               -- switch output stream back to our header processing
               v.passTdo           := '0';
            end if;
            if ( v.passTdi = '0' and v.passTdo = '0' ) then
               v.state             := IDLE_S;
            end if;
            if ( MEM_DEPTH_G > 0 and s.tdoWen = '1' ) then
               if ( s.mTdo.tLast = '1' ) then
                  v.memValid := true;
               end if;
               v.widx           := r.widx + 1;
            end if;

         when REPLAY_S =>
            if ( s.lastReq = '1' ) then
               -- absorb the input stream
               v.ackInput := '0';
            end if;
            if ( s.locConsumed = '1' ) then
               v.ridx            := r.ridx + 1;
               v.replyData.tData(WORD_SIZE_C - 1  downto 0) := memOut;
               if ( r.ridx = r.widx ) then
                  -- bogus data loaded into memOut on next cycle
                  v.replyData.tLast := '1';
                  v.ridx            := ADDR_ZERO_C;
               elsif ( r.replyData.tLast = '1' ) then
                  -- bogus data now sitting in memOut (but not read since tValid will be 0)
                  v.replyData.tValid := '0';
                  v.ridx            := ADDR_ZERO_C;
               end if;
            end if;
            if ( v.ackInput = '0' and v.replyData.tValid = '0' ) then
               v.state            := IDLE_S;
            end if;
      end case;

      rin <= v;

   end process P_COMB;

   GEN_RAM : if ( MEM_DEPTH_G > 0 ) generate
      P_RAM : process ( axisClk )
      begin
         if ( rising_edge( axisClk ) ) then
            if ( s.tdoWen = '1' ) then
               bufMem( to_integer( r.widx ) ) <= s.mTdo.tData( WORD_SIZE_C - 1 downto 0 ) after TPD_G;
            end if;
            if ( s.tdoRen = '1' ) then
               memOut <= bufMem( to_integer( r.ridx ) ) after TPD_G;
            end if;
         end if;
      end process P_RAM;
   end generate;

   P_SEQ : process( axisClk )
   begin
      if ( rising_edge( axisClk ) ) then
         if ( axisRst /= '0' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

end architecture AxisToJtagImpl;
