------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2000-2012, AdaCore                     --
--                                                                          --
--  This library is free software;  you can redistribute it and/or modify   --
--  it under terms of the  GNU General Public License  as published by the  --
--  Free Software  Foundation;  either version 3,  or (at your  option) any --
--  later version. This library is distributed in the hope that it will be  --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    --
--                                                                          --
--  As a special exception under Section 7 of GPL version 3, you are        --
--  granted additional permissions described in the GCC Runtime Library     --
--  Exception, version 3.1, as published by the Free Software Foundation.   --
--                                                                          --
--  You should have received a copy of the GNU General Public License and   --
--  a copy of the GCC Runtime Library Exception along with this program;    --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see   --
--  <http://www.gnu.org/licenses/>.                                         --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with Ada.Calendar;
with Ada.Streams;
with Ada.Strings.Unbounded;

package AWS.Messages is

   use Ada;
   use Ada.Strings.Unbounded;
   use Ada.Streams;

   -----------------
   -- HTTP tokens --
   -----------------

   HTTP_Token    : constant String := "HTTP/";
   Options_Token : constant String := "OPTIONS";
   Get_Token     : constant String := "GET";
   Head_Token    : constant String := "HEAD";
   Post_Token    : constant String := "POST";
   Put_Token     : constant String := "PUT";
   Delete_Token  : constant String := "DELETE";
   Trace_Token   : constant String := "TRACE";
   Connect_Token : constant String := "CONNECT";
   --  Sorted like in RFC 2616 Method definition

   ------------------------
   -- HTTP header tokens --
   ------------------------

   --  General header tokens RFC 2616
   Cache_Control_Token       : constant String := "Cache-Control";
   Connection_Token          : constant String := "Connection";
   Date_Token                : constant String := "Date";
   Pragma_Token              : constant String := "Pragma";
   Trailer_Token             : constant String := "Trailer";
   Transfer_Encoding_Token   : constant String := "Transfer-Encoding";
   Upgrade_Token             : constant String := "Upgrade";
   Via_Token                 : constant String := "Via";
   Warning_Token             : constant String := "Warning";

   --  Request header tokens RFC 2616
   Accept_Token              : constant String := "Accept";
   Accept_Charset_Token      : constant String := "Accept-Charset";
   Accept_Encoding_Token     : constant String := "Accept-Encoding";
   Accept_Language_Token     : constant String := "Accept-Language";
   Authorization_Token       : constant String := "Authorization";
   Expect_Token              : constant String := "Expect";
   From_Token                : constant String := "From";
   Host_Token                : constant String := "Host";
   If_Match_Token            : constant String := "If-Match";
   If_Modified_Since_Token   : constant String := "If-Modified-Since";
   If_None_Match_Token       : constant String := "If-None-Match";
   If_Range_Token            : constant String := "If-Range";
   If_Unmodified_Since_Token : constant String := "If-Unmodified-Since";
   Max_Forwards_Token        : constant String := "Max-Forwards";
   Proxy_Authorization_Token : constant String := "Proxy-Authorization";
   Range_Token               : constant String := "Range";
   Referer_Token             : constant String := "Referer";
   TE_Token                  : constant String := "TE";
   User_Agent_Token          : constant String := "User-Agent";

   --  Response header tokens RFC 2616
   Accept_Ranges_Token       : constant String := "Accept-Ranges";
   Age_Token                 : constant String := "Age";
   ETag_Token                : constant String := "ETag";
   Location_Token            : constant String := "Location";
   Proxy_Authenticate_Token  : constant String := "Proxy-Authenticate";
   Retry_After_Token         : constant String := "Retry-After";
   Server_Token              : constant String := "Server";
   Vary_Token                : constant String := "Vary";
   WWW_Authenticate_Token    : constant String := "WWW-Authenticate";

   --  Entity header tokens RFC 2616
   Allow_Token               : constant String := "Allow";
   Content_Encoding_Token    : constant String := "Content-Encoding";
   Content_Language_Token    : constant String := "Content-Language";
   Content_Length_Token      : constant String := "Content-Length";
   Content_Location_Token    : constant String := "Content-Location";
   Content_MD5_Token         : constant String := "Content-MD5";
   Content_Range_Token       : constant String := "Content-Range";
   Content_Type_Token        : constant String := "Content-Type";
   Expires_Token             : constant String := "Expires";
   Last_Modified_Token       : constant String := "Last-Modified";

   --  Cookie token RFC 2109
   Cookie_Token              : constant String := "Cookie";
   Set_Cookie_Token          : constant String := "Set-Cookie";
   Comment_Token             : constant String := "Comment";
   Domain_Token              : constant String := "Domain";
   Max_Age_Token             : constant String := "Max-Age";
   Path_Token                : constant String := "Path";
   Secure_Token              : constant String := "Secure";

   --  Other tokens
   Proxy_Connection_Token    : constant String := "Proxy-Connection";
   Content_Disposition_Token : constant String := "Content-Disposition";
   SOAPAction_Token          : constant String := "SOAPAction";
   Content_Id_Token          : constant String := "Content-ID";
   Content_Transfer_Encoding_Token : constant String
     := "Content-Transfer-Encoding";

   S100_Continue : constant String := "100-continue";
   --  Supported expect header value

   -----------------
   -- Status Code --
   -----------------

   type Status_Code is
     (S100, S101, S102,
      --  1xx : Informational - Request received, continuing process

      S200, S201, S202, S203, S204, S205, S206, S207,
      --  2xx : Success - The action was successfully received, understood and
      --  accepted

      S300, S301, S302, S303, S304, S305, S307,
      --  3xx : Redirection - Further action must be taken in order to
      --  complete the request

      S400, S401, S402, S403, S404, S405, S406, S407, S408, S409,
      S410, S411, S412, S413, S414, S415, S416, S417, S422, S423, S424,
      --  4xx : Client Error - The request contains bad syntax or cannot be
      --  fulfilled

      S500, S501, S502, S503, S504, S505, S507
      --  5xx : Server Error - The server failed to fulfill an apparently
      --  valid request
      );

   subtype Informational is Status_Code range S100 .. S102;
   subtype Success       is Status_Code range S200 .. S207;
   subtype Redirection   is Status_Code range S300 .. S307;
   subtype Client_Error  is Status_Code range S400 .. S424;
   subtype Server_Error  is Status_Code range S500 .. S507;

   function Image (S : Status_Code) return String;
   --  Returns Status_Code image. This value does not contain the leading S

   function Reason_Phrase (S : Status_Code) return String;
   --  Returns the reason phrase for the status code S, see [RFC 2616 - 6.1.1]

   ----------------------
   -- Content encoding --
   ----------------------

   type Content_Encoding is (Identity, GZip, Deflate);
   --  Encoding mode for the response, Identity means that no encoding is
   --  done, Gzip/Deflate to select the Gzip or Deflate encoding algorithm.

   -------------------
   -- Cache_Control --
   -------------------

   type Cache_Option is new String;
   --  Cache_Option is a string and any specific option can be specified. We
   --  define four options:
   --
   --  Unspecified   : No cache option will used.
   --  No_Cache      : Ask browser and proxy to not cache data (no-cache,
   --                  max-age, and s-maxage are specified).
   --  No_Store      : Ask browser and proxy to not store any data. This can be
   --                  used to protect sensitive data.
   --  Prevent_Cache : Equivalent to No_Store + No_Cache

   Unspecified   : constant Cache_Option;
   No_Cache      : constant Cache_Option;
   No_Store      : constant Cache_Option;
   Prevent_Cache : constant Cache_Option;

   type Cache_Kind is (Request, Response);

   type Delta_Seconds is new Integer range -1 .. Integer'Last;
   --  Represents a delta-seconds parameter for some Cache_Data fields like
   --  max-age, max-stale (value -1 is used for Unset).

   Unset         : constant Delta_Seconds;
   No_Max_Stale  : constant Delta_Seconds;
   Any_Max_Stale : constant Delta_Seconds;

   type Private_Option is new Unbounded_String;

   All_Private   : constant Private_Option;
   Private_Unset : constant Private_Option;

   --  Cache_Data is a record that represents cache control information

   type Cache_Data (CKind : Cache_Kind) is record
      No_Cache       : Boolean       := False;
      No_Store       : Boolean       := False;
      No_Transform   : Boolean       := False;
      Max_Age        : Delta_Seconds := Unset;

      case CKind is
         when Request =>
            Max_Stale      : Delta_Seconds := Unset;
            Min_Fresh      : Delta_Seconds := Unset;
            Only_If_Cached : Boolean       := False;

         when Response =>
            S_Max_Age        : Delta_Seconds  := Unset;
            Public           : Boolean        := False;
            Private_Field    : Private_Option := Private_Unset;
            Must_Revalidate  : Boolean        := False;
            Proxy_Revalidate : Boolean        := False;
      end case;
   end record;

   function To_Cache_Option (Data : Cache_Data) return Cache_Option;
   --  Returns a cache control value for an HTTP request/response, fields are
   --  described into RFC 2616 [14.9 Cache-Control].

   function To_Cache_Data
     (Kind : Cache_Kind; Value : Cache_Option) return Cache_Data;
   --  Returns a Cache_Data record parsed out of Cache_Option

   ----------
   -- ETag --
   ----------

   type ETag_Value is new String;

   function Create_ETag
     (Name : String; Weak : Boolean := False) return ETag_Value;
   --  Returns an ETag value (strong by default and Weak if specified). For a
   --  discussion about ETag see RFC 2616 [3.11 Entity Tags] and [14.19 ETag].

   -------------------------------
   -- HTTP message constructors --
   -------------------------------

   function Accept_Encoding (Encoding : String) return String;
   pragma Inline (Accept_Encoding);

   function Accept_Type (Mode : String) return String;
   pragma Inline (Accept_Type);

   function Accept_Language (Mode : String) return String;
   pragma Inline (Accept_Language);

   function Authorization (Mode, Password : String) return String;
   pragma Inline (Authorization);

   function Connection (Mode : String) return String;
   pragma Inline (Connection);

   function Content_Length (Size : Stream_Element_Offset) return String;
   pragma Inline (Content_Length);

   function Cookie (Value : String) return String;
   pragma Inline (Cookie);

   function Content_Type
     (Format : String; Boundary : String := "") return String;
   pragma Inline (Content_Type);

   function Cache_Control (Option : Cache_Option) return String;
   pragma Inline (Cache_Control);

   function Cache_Control (Data : Cache_Data) return String;
   pragma Inline (Cache_Control);

   function Content_Disposition
     (Format, Name, Filename : String) return String;
   pragma Inline (Content_Disposition);
   --  Note that this is not part of HTTP/1.1 standard, it is there because
   --  there is a lot of implementation around using it. This header is used
   --  in multipart data.

   function ETag (Value : ETag_Value) return String;
   pragma Inline (ETag);

   function Expires (Date : Calendar.Time) return String;
   pragma Inline (Expires);
   --  The date should not be more than a year in the future, see RFC 2616
   --  [14.21 Expires].

   function Host (Name : String) return String;
   pragma Inline (Host);

   function Last_Modified (Date : Calendar.Time) return String;
   pragma Inline (Last_Modified);

   function Location (URL : String) return String;
   pragma Inline (Location);

   function Proxy_Authorization (Mode, Password : String) return String;
   pragma Inline (Proxy_Authorization);

   function Proxy_Connection (Mode : String) return String;
   pragma Inline (Proxy_Connection);

   function Data_Range (Value : String) return String;
   pragma Inline (Data_Range);

   function SOAPAction (URI : String) return String;
   pragma Inline (SOAPAction);

   function Status_Line (Code : Status_Code) return String;
   pragma Inline (Status_Line);

   function Transfer_Encoding (Encoding : String) return String;
   pragma Inline (Transfer_Encoding);

   function User_Agent (Name : String) return String;
   pragma Inline (User_Agent);

   function WWW_Authenticate (Realm : String) return String;
   pragma Inline (WWW_Authenticate);
   --  Basic authentication request

   function WWW_Authenticate
     (Realm, Nonce : String; Stale : Boolean) return String;
   pragma Inline (WWW_Authenticate);
   --  Digest authentication request

   -----------------------
   --  helper functions --
   -----------------------

   function To_HTTP_Date (Time : Calendar.Time) return String;
   --  Returns an Ada time as a string using the HTTP normalized format.
   --  Format is RFC 822, updated by RFC 1123.

   function To_Time (HTTP_Date : String) return Calendar.Time;
   --  Returns an Ada time from an HTTP one. This is To_HTTP_Date opposite
   --  function.

private

   Unspecified   : constant Cache_Option := "";
   No_Cache      : constant Cache_Option := "no-cache, max-age=0, s-maxage=0";
   No_Store      : constant Cache_Option := "no-store";
   Prevent_Cache : constant Cache_Option := No_Store & ", " & No_Cache;

   Unset         : constant Delta_Seconds := -1;
   No_Max_Stale  : constant Delta_Seconds := Unset;
   Any_Max_Stale : constant Delta_Seconds := Delta_Seconds'Last;

   All_Private   : constant Private_Option := To_Unbounded_String ("*");
   Private_Unset : constant Private_Option :=
                     Private_Option (Null_Unbounded_String);

end AWS.Messages;
