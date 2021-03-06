------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2008-2012, AdaCore                     --
--                                                                          --
--  This is free software;  you can redistribute it  and/or modify it       --
--  under terms of the  GNU General Public License as published  by the     --
--  Free Software  Foundation;  either version 3,  or (at your option) any  --
--  later version.  This software is distributed in the hope  that it will  --
--  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty --
--  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     --
--  General Public License for  more details.                               --
--                                                                          --
--  You should have  received  a copy of the GNU General  Public  License   --
--  distributed  with  this  software;   see  file COPYING3.  If not, go    --
--  to http://www.gnu.org/licenses for a complete copy of the license.      --
------------------------------------------------------------------------------

with Ada.Text_IO;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;

with AWS.Client;
with AWS.Config.Set;
with AWS.Headers.Set;
with AWS.Messages;
with AWS.MIME;
with AWS.Net.Log;
with AWS.Parameters;
with AWS.Response;
with AWS.Server.Status;
with AWS.Status;
with AWS.Translator;
with AWS.Utils;

procedure Client_Headers is

   use Ada;
   use Ada.Streams;
   use Ada.Strings.Unbounded;
   use AWS;

   WS : Server.HTTP;

   --------
   -- CB --
   --------

   function CB (Request : Status.Data) return Response.Data is
      H : constant Headers.List := Status.Header (Request);

      procedure Output (Header : String);
      --  Output corresping header value

      ------------
      -- Output --
      ------------

      procedure Output (Header : String) is
      begin
         if Headers.Exist (H, Header) then
            declare
               Value : Unbounded_String :=
                         To_Unbounded_String
                           (Strings.Fixed.Translate
                              (Headers.Get (H, Header),
                               Strings.Maps.To_Mapping
                                 ("0123456789", "xxxxxxxxxx")));
               K     : Natural;
            begin
               loop
                  K := Index (Value, "xx.");

                  exit when K = 0;

                  Replace_Slice (Value, K, K + 2, "x.");
               end loop;

               loop
                  K := Index (Value, ":xx");

                  exit when K = 0;

                  Replace_Slice (Value, K, K + 2, ":x");
               end loop;

               if Element (Value, Length (Value)) = 'w' then
                  Replace_Slice (Value, Length (Value), Length (Value), "");
               end if;

               Text_IO.Put_Line (Header & ": " & To_String (Value));
            end;

         else
            Text_IO.Put_Line (Header & ": NOT FOUND");
         end if;
      end Output;

   begin
      Text_IO.Put_Line (">>>>> " & Status.URI (Request));
      Output (Messages.User_Agent_Token);
      Output (Messages.Accept_Language_Token);
      Output (Messages.Accept_Encoding_Token);
      Output (Messages.Accept_Token);
      Output (Messages.Host_Token);
      Output (Messages.Range_Token);
      Output (Messages.If_Modified_Since_Token);
      Text_IO.New_Line;
      return Response.Build (MIME.Text_HTML, "ok");
   end CB;

   ----------
   -- Dump --
   ----------

   procedure Dump
     (Direction : Net.Log.Data_Direction;
      Socket    : Net.Socket_Type'Class;
      Data      : Stream_Element_Array;
      Last      : Stream_Element_Offset)
   is
      use type Net.Log.Data_Direction;
   begin
      if Direction = Net.Log.Sent then
         Text_IO.Put_Line
           ("********** " & Net.Log.Data_Direction'Image (Direction));
         Text_IO.Put_Line
           (Translator.To_String (Data (Data'First .. Last)));
         Text_IO.New_Line;
      end if;
   end Dump;

   R   : Response.Data;
   H   : Headers.List;
   CFG : Config.Object;

begin
   Config.Set.Server_Name (CFG, "Client Headers");
   Config.Set.Server_Port (CFG, 0);
   Config.Set.Protocol_Family (CFG, "Family_Inet");

   Server.Start (WS, CB'Unrestricted_Access, CFG);

   --  AWS.Net.Log.Start (Dump'Unrestricted_Access);

   declare
      URL : constant String := Server.Status.Local_URL (WS);
   begin
      R := AWS.Client.Get (URL => URL & "/1");
      R := AWS.Client.Head (URL => URL & "/2");
      R := AWS.Client.Post (URL & "/3", Data => "V=1");

      Headers.Set.Add (H, Messages.Accept_Language_Token, "fr");
      Headers.Set.Add (H, Messages.If_Modified_Since_Token, "yesterday :)");

      R := AWS.Client.Get (URL => URL & "/4", Headers => H);

      Headers.Set.Add (H, Messages.User_Agent_Token, "Very_Secret");

      R := AWS.Client.Head (URL => URL & "/5", Headers => H);

      Headers.Set.Update (H, Messages.User_Agent_Token, "Or_Not");
      Headers.Set.Add (H, Messages.Host_Token, "me");

      R := AWS.Client.Post (URL => URL & "/6", Data => "V=2", Headers => H);
   end;

   Server.Shutdown (WS);
   Text_IO.Put_Line ("shutdown");
end Client_Headers;
