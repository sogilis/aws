------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2011-2012, AdaCore                     --
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

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AWS.Client;
with AWS.MIME;
with AWS.Messages;
with AWS.Net.Std;
with AWS.Parameters;
with AWS.Response.Set;
with AWS.Resources.Streams.Disk;
with AWS.Resources.Streams.Memory.ZLib;
with AWS.Resources.Streams.ZLib;
with AWS.Server;
with AWS.Session;
with AWS.Services.Dispatchers.URI;
with AWS.Services.Split_Pages;
with AWS.SMTP.Client;
with AWS.Status;
with AWS.Templates;
with AWS.Translator;
with AWS.Utils;

with SOAP.Client;
with SOAP.Message.Payload;
with SOAP.Message.Response;
with SOAP.Message.XML;
with SOAP.Parameters;
with SOAP.Types;

with API_Service.CB;
with API_Service.Client;
with API_Service.Server;

with Get_Free_Port;

procedure Check_Mem_Nossl is

   use Ada;
   use Ada.Exceptions;
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

   use AWS;

   function CB (Request : Status.Data) return Response.Data;

   procedure Check (Str : String);

   procedure Client;

   function SOAP_CB (Request : Status.Data) return Response.Data;

   procedure Check_Zlib;

   procedure Check_Memory_Streams;

   procedure Check_Dynamic_Message (Encoding : Messages.Content_Encoding);

   procedure Check_Socket;

   function Get_Free_Port return Positive;

   task Server is
      entry Started;
      entry Stopped;
   end Server;

   HTTP      : AWS.Server.HTTP;

   -------------------
   -- Get_Free_Port --
   -------------------

   function Get_Free_Port return Positive is
      Free_Port : Positive := 8188;
   begin
      Get_Free_Port (Free_Port);
      return Free_Port;
   end Get_Free_Port;

   Port      : constant Positive := Get_Free_Port;
   S_Port    : constant String   := AWS.Utils.Image (Port);

   Iteration : Positive;

   -----------
   -- Check --
   -----------

   procedure Check (Str : String) is
   begin
      Put_Line (Str);
   end Check;

   --------
   -- CB --
   --------

   function CB (Request : Status.Data) return Response.Data is
      SOAP_Action : constant String          := Status.SOAPAction (Request);
      URI         : constant String          := Status.URI (Request);
      P_List      : constant Parameters.List := Status.Parameters (Request);
      SID         : constant Session.ID      := Status.Session (Request);

      N           : Natural := 0;
      Strm        : Resources.Streams.Stream_Access;
   begin
      if Session.Exist (SID, "key") then
         N := Session.Get (SID, "key");
         N := N + 1;
      end if;

      Session.Set (SID, "key", N);
      Session.Set (SID, "key" & Utils.Image (N), "a value");

      if SOAP_Action = "/soap_demo" then
         return SOAP_CB (Request);

      elsif SOAP_Action = "Set"
        or else SOAP_Action = "Get"
        or else SOAP_Action = "Get_Last_Key"
      then
         declare
            Payload : constant SOAP.Message.Payload.Object :=
                        SOAP.Message.XML.Load_Payload
                          (AWS.Status.Payload (Request));
         begin
            return API_Service.CB.SOAP_CB (SOAP_Action, Payload, Request);
         end;

      elsif URI = "/simple" then
         Check (Natural'Image (Parameters.Count (P_List)));
         Check (Parameters.Get (P_List, "p1"));
         Check (Parameters.Get (P_List, "p2"));

         return Response.Build (MIME.Text_HTML, "simple ok");

      elsif URI = "/complex" then
         Check (Natural'Image (Parameters.Count (P_List)));
         Check (Parameters.Get (P_List, "p1"));
         Check (Parameters.Get (P_List, "p2"));

         for K in 1 .. Parameters.Count (P_List) loop
            Check (Parameters.Get_Name (P_List, K));
            Check (Parameters.Get_Value (P_List, K));
         end loop;

         return Response.Build (MIME.Text_HTML, "complex ok");

      elsif URI = "/multiple" then
         Check (Natural'Image (Parameters.Count (P_List)));
         Check (Parameters.Get (P_List, "par", 1));
         Check (Parameters.Get (P_List, "par", 2));
         Check (Parameters.Get (P_List, "par", 3));
         Check (Parameters.Get (P_List, "par", 4));
         Check (Parameters.Get (P_List, "par", 5));

         return Response.Build (MIME.Text_HTML, "multiple ok");

      elsif URI = "/file" then
         return Response.File (MIME.Text_Plain, "check_mem.adb");

      elsif URI = "/filea.txt"
        or else URI = "/fileb.txt"
        or else URI = "/filec.txt"
      then
         return Response.File ("text/plain", URI (URI'First + 1 .. URI'Last));

      elsif URI = "/no-template" then
         declare
            Trans : constant Templates.Translate_Table
              := (1 => Templates.Assoc ("ONE", 1));

            Result : Unbounded_String;

         begin
            Result
              := Templates.Parse ("_._.tmplt", Trans, Cached => False);
         exception
            when Ada.IO_Exceptions.Name_Error =>
               null;
         end;

         return Response.Build (MIME.Text_HTML, "dummy");

      elsif URI = "/template" then

         declare
            use type Templates.Vector_Tag;

            Vect   : Templates.Vector_Tag := +"V1" & "V2" & "V3";
            Matrix : constant Templates.Matrix_Tag := +Vect & Vect;

            Trans : constant Templates.Translate_Table :=
                      (1 => Templates.Assoc ("ONE", 1),
                       2 => Templates.Assoc ("TWO", 2),
                       3 => Templates.Assoc ("EXIST", True),
                       4 => Templates.Assoc ("V", Vect),
                       5 => Templates.Assoc ("M", Matrix));
         begin
            Templates.Clear (Vect);
            Vect := +"V1" & "V2" & "V3";

            return Response.Build
              (MIME.Text_HTML,
               String'(Templates.Parse ("check_mem_nossl.tmplt", Trans)));
         end;

      elsif URI = "/stream" then
         Strm := new Resources.Streams.Disk.Stream_Type;

         Resources.Streams.Disk.Open
           (Resources.Streams.Disk.Stream_Type (Strm.all),
            "check_mem_nossl.adb");

         return Response.Stream
           (MIME.Text_Plain,
            Resources.Streams.ZLib.Deflate_Create
              (Strm, Header => Resources.Streams.ZLib.ZL.Gzip),
            Encoding => Messages.GZip);

      elsif URI = "/stream-unknown" then
         Strm := new Resources.Streams.Disk.Stream_Type;

         Resources.Streams.Disk.Open
           (Resources.Streams.Disk.Stream_Type (Strm.all),
            "check_mem2.adb");

         return Response.Stream
           (MIME.Text_Plain, Strm, Encoding => Messages.GZip);

      else
         Check ("Unknown URI " & URI);
         return Response.Build
           (MIME.Text_HTML, URI & " not found", Messages.S404);
      end if;
   end CB;

   ------------
   -- Server --
   ------------

   task body Server is
   begin
      AWS.Server.Start
        (HTTP, "check_mem2",
         CB'Unrestricted_Access,
         Port           => Port,
         Max_Connection => 5,
         Session        => True);

      Put_Line ("Server started");
      New_Line;

      accept Started;

      select
         accept Stopped;
      or
         delay 4.0 * Iteration;
         Put_Line ("Too much time to do the job !");
      end select;

      AWS.Server.Shutdown (HTTP);
   exception
      when E : others =>
         Put_Line ("Server Error " & Exception_Information (E));
   end Server;

   -------------
   -- SOAP_CB --
   -------------

   function SOAP_CB (Request : Status.Data) return Response.Data is
      use SOAP.Types;
      use SOAP.Parameters;

      Payload      : constant SOAP.Message.Payload.Object :=
                       SOAP.Message.XML.Load_Payload
                         (AWS.Status.Payload (Request));

      SOAP_Proc    : constant String :=
                       SOAP.Message.Payload.Procedure_Name (Payload);

      Parameters   : constant SOAP.Parameters.List :=
                       SOAP.Message.Parameters (Payload);

      Response     : SOAP.Message.Response.Object;
      R_Parameters : SOAP.Parameters.List;

   begin
      Response := SOAP.Message.Response.From (Payload);

      declare
         X : constant Integer := SOAP.Parameters.Get (Parameters, "x");
         Y : constant Integer := SOAP.Parameters.Get (Parameters, "y");
      begin
         if SOAP_Proc = "multProc" then
            R_Parameters := +I (X * Y, "result");
         elsif SOAP_Proc = "addProc" then
            R_Parameters := +I (X + Y, "result");
         end if;
      end;

      SOAP.Message.Set_Parameters (Response, R_Parameters);

      return SOAP.Message.Response.Build (Response);
   end SOAP_CB;

   ------------
   -- Client --
   ------------

   procedure Client is

      procedure Request (URL : String);

      procedure Request (Proc : String; X, Y : Integer);

      -------------
      -- Request --
      -------------

      procedure Request (URL : String) is
         R : Response.Data;
      begin
         R := AWS.Client.Get ("http://localhost:" & S_Port & URL);
         Check (Response.Message_Body (R));
      end Request;

      procedure Request (Proc : String; X, Y : Integer) is
         use SOAP.Types;
         use type SOAP.Parameters.List;

         P_Set   : constant SOAP.Parameters.List := +I (X, "x") & I (Y, "y");
         Payload : SOAP.Message.Payload.Object;
      begin
         Payload := SOAP.Message.Payload.Build (Proc, P_Set);

         declare
            Response     : constant SOAP.Message.Response.Object'Class :=
                             SOAP.Client.Call
                               ("http://localhost:" & S_Port & "/soap_demo",
                                Payload,
                                "/soap_demo");
            R_Parameters : constant SOAP.Parameters.List :=
                             SOAP.Message.Parameters (Response);
            Result       : constant Integer :=
                             SOAP.Parameters.Get (R_Parameters, "result");
         begin
            null;
         end;
      end Request;

   begin
      Request ("/simple");
      Request ("/simple?p1=8&p2=azerty%20qwerty");
      Request ("/simple?p2=8&p1=azerty%20qwerty");
      Request ("/doesnotexist?p=8");

      Request ("/complex?p1=1&p2=2&p3=3&p4=4&p5=5&p6=6"
                 & "&p7=7&p8=8&p9=9&p10=10&p11=11&p12=12&p13=13&p14=14&p15=15"
                 & "&very_long_name_in_a_get_form=alongvalueforthistest");

      Request ("/multiple?par=1&par=2&par=3&par=4&par=whatever");

      Request ("/simple?p1=8&p2=azerty%20qwerty");
      Request ("/file");
      Request ("/template");
      Request ("/no-template");
      Request ("/stream");
      Request ("/stream-unknown");

      Request ("multProc", 2, 3);
      Request ("multProc", 98, 123);
      Request ("multProc", 5, 9);
      Request ("addProc", 2, 3);
      Request ("addProc", 98, 123);
      Request ("addProc", 5, 9);
   end Client;

   ---------------------------
   -- Check_Dynamic_Message --
   ---------------------------

   procedure Check_Dynamic_Message (Encoding : Messages.Content_Encoding) is
      Answer : Response.Data;
   begin
      Response.Set.Data_Encoding (Answer, Encoding);

      Response.Set.Message_Body
        (Answer, Streams.Stream_Element_Array'(1 .. 64 => 10));
   end Check_Dynamic_Message;

   --------------------------
   -- Check_Memory_Streams --
   --------------------------

   procedure Check_Memory_Streams is
      use AWS.Resources.Streams.Memory;

      use type Streams.Stream_Element_Array;

      Sample : Streams.Stream_Element_Array := (1 .. 64 => 20);

      Plain  : Stream_Type;
      Unpack : ZLib.Stream_Type;
      Packed : Utils.Stream_Element_Array_Access;

      procedure Test
        (Stream : in out Stream_Type'Class;
         Data   : Streams.Stream_Element_Array);
      --  Append dynamically allocated data, test content and close the stream

      ----------
      -- Test --
      ----------

      procedure Test
        (Stream : in out Stream_Type'Class;
         Data   : Streams.Stream_Element_Array)
      is
         Test   : Streams.Stream_Element_Array (Sample'Range);
         Last   : Streams.Stream_Element_Offset;
      begin
         Append (Stream, Data);
         Read (Stream, Test, Last);

         if Test (1 .. Last) /= Sample or else not End_Of_File (Stream) then
            raise Program_Error;
         end if;

         Close (Stream);
      end Test;

   begin
      ZLib.Inflate_Initialize (Unpack);

      Packed := Translator.Compress (Sample);

      Test (Unpack, Packed.all);
      Utils.Unchecked_Free (Packed);

      Test (Plain, Sample);
   end Check_Memory_Streams;

   ----------------
   -- Check_Zlib --
   ----------------

   procedure Check_Zlib is

      use type Streams.Stream_Element_Array;

      procedure Test (Str : String);

      ----------
      -- Test --
      ----------

      procedure Test (Str : String) is
         Data   : constant Streams.Stream_Element_Array :=
                    Translator.To_Stream_Element_Array (Str);
         Comp   : Utils.Stream_Element_Array_Access;
         Decomp : Utils.Stream_Element_Array_Access;
      begin
         Comp   := Translator.Compress (Data);
         Decomp := Translator.Decompress (Comp.all);

         if Data = Decomp.all then
            Text_IO.Put_Line ("Ok");
         else
            Text_IO.Put_Line ("Nok: " & Translator.To_String (Decomp.all));
         end if;

         Text_IO.Put_Line
           (Integer'Image (Data'Length) & " bytes compressed to"
              & Integer'Image (Comp'Length));

         Utils.Unchecked_Free (Comp);
         Utils.Unchecked_Free (Decomp);
      end Test;

   begin
      Test ("simple");

      Test ("A longer text to test the real factor compression which is "
              & "almost null on very small chunk of data. So this test is "
              & "one on which we will display real size.");
   end Check_Zlib;

   ---------------------
   -- Check_Transient --
   ---------------------

   procedure Check_Transient is

      use Templates;

      T1 : constant Translate_Table :=
             (1 => Assoc ("ONE", "one"),
              2 => Assoc ("TWO", "2"),
              3 => Assoc ("THREE", "3"));

      T2 : constant Translate_Table :=
             (1 => Assoc ("V1", Vector_Tag'(+"t11" & "t12" & "t13")),
              2 => Assoc ("V2", Vector_Tag'(+"t21" & "t22" & "t23")));

      R : Response.Data;
   begin
      R := Services.Split_Pages.Parse ("cm2_split.tmplt", T1, T2, 2);
   end Check_Transient;

   -----------------
   -- Check_ZOpen --
   -----------------

   procedure Check_ZOpen is
      use Templates;
      R : Response.Data;
   begin
      R := AWS.Client.Get ("http://localhost:" & S_Port & "/filea.txt");
      R := AWS.Client.Get ("http://localhost:" & S_Port & "/fileb.txt");
      R := AWS.Client.Get ("http://localhost:" & S_Port & "/filec.txt");
   end Check_ZOpen;

   ---------------------
   -- Check_Reconnect --
   ---------------------

   procedure Check_Reconnect is
      use Ada.Streams;
      use AWS.Net;

      N      : constant := 2;
      Server : Std.Socket_Type;
      Peer   : Socket_Type'Class := Socket (False);
      Buffer : Stream_Element_Array (1 .. 64);
      Last   : Stream_Element_Offset;

      task Connector is
         entry Start;
      end Connector;

      task body Connector is
         Client : Socket_Type'Class := Socket (False);
      begin
         Set_Timeout (Client, 0.5);

         accept Start;

         for J in 1 .. N loop
            Connect (Client, Server.Get_Addr, Server.Get_Port);
            Send (Client, (1 .. 10 => 11));
            Receive (Client, Buffer, Last);
            Shutdown (Client);
         end loop;
      exception
         when E : others =>
            Put_Line ("On connect " & Exception_Information (E));
      end Connector;

   begin
      Std.Bind (Server, 0);
      Std.Listen (Server);

      Std.Set_Timeout (Server, 0.5);

      Connector.Start;

      for J in 1 .. N loop
         Accept_Socket (Server, Peer);
         Receive (Peer, Buffer, Last);
         Send (Peer, Data => (1 .. 11 => 12));
         begin
            --  Wait for opposite shutdown
            Receive (Peer, Buffer, Last);
            raise Program_Error;
         exception
            when Socket_Error =>
               Shutdown (Peer);
         end;
      end loop;
   end Check_Reconnect;

   ----------------
   -- Check_SMTP --
   ----------------

   procedure Check_SMTP is
      From      : AWS.SMTP.E_Mail_Data;
      Recipient : AWS.SMTP.E_Mail_Data;
      Server    : AWS.SMTP.Receiver;
      Status    : AWS.SMTP.Status;

      SMTP_Host : constant String := "bad_smtp_host";
   begin
      From := AWS.SMTP.E_Mail
        (Name    => "Pascal Obry",
         Address => "pascal@obry.net");

      Recipient := AWS.SMTP.E_Mail
        (Name    => "Somebody",
         Address => "somebody@obry.net");

      Server := AWS.SMTP.Client.Initialize
        (Server_Name => SMTP_Host,
         Port        => 25);

      AWS.SMTP.Client.Send
        (Server  => Server,
         From    => From,
         To      => Recipient,
         Subject => "Test subject",
         Message => "Test message",
         Status  => Status);

      if AWS.SMTP.Is_Ok (Status) then
         Put_Line ("Status OK");
      end if;
   exception
      when others =>
         null;
   end Check_SMTP;

   ------------------
   -- Check_Socket --
   ------------------

   procedure Check_Socket is
   begin
      for K in 1 .. 10 loop
         declare
            S1 : Net.Std.Socket_Type;
            pragma Unreferenced (S1);
         begin
            null;
         end;
      end loop;
   end Check_Socket;

begin
   Put_Line ("Start main, wait for server to start...");

   Iteration := Integer'Value (Command_Line.Argument (1));

   Server.Started;

   --  This is the main loop. Be sure to run everything inside this
   --  loop. Check_Mem is checked between 2 runs with a different number of
   --  iterations.

   for K in 1 ..  Iteration loop

      declare
         R : Response.Data;
      begin
         R := AWS.Client.Get ("http://www.nowayitexists.com/me/aws");
      exception
         when E : others =>
            Put_Line ("*** " & Exception_Message (E));
      end;

      Client;
      Check_Zlib;
      Check_Memory_Streams;
      Check_Dynamic_Message (Messages.Identity);
      Check_Dynamic_Message (Messages.Deflate);
      Check_Transient;
      Check_Zopen;
      Check_Socket;
      Check_Reconnect;
      Check_SMTP;
      API_Service.Client.Set
        ("voiture", 2, Endpoint => "http://localhost:" & S_Port);
      Put_Line
        (Integer'Image
           (API_Service.Client.Get
              ("voiture",
               Endpoint => "http://localhost:" & S_Port)));
      Put_Line
        (API_Service.Client.Get_Last_Key
           (Endpoint => "http://localhost:" & S_Port));
   end loop;

   Server.Stopped;

   --  Clear session cache to normalize rest allocated memory

   Command_Line.Set_Exit_Status (Command_Line.Success);
exception
   when E : others =>
      Put_Line ("Main Error " & Exception_Information (E));
      Command_Line.Set_Exit_Status (Command_Line.Failure);
end Check_Mem_Nossl;
