------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2004-2012, AdaCore                     --
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

--  Test hotplug feature

with Ada.Exceptions;
with Ada.Text_IO;

with AWS.Client.Hotplug;
with AWS.Config.Set;
with AWS.Messages;
with AWS.Response;
with AWS.Server.Hotplug;
with AWS.Server.Status;
with AWS.Utils;

with SOAP_Hotplug_Pack;
with SOAP_Hotplug_CB;
with SOAP_Hotplug_Pack_Service.Client;
with Get_Free_Port;

procedure Test_SOAP_Hotplug is

   use Ada;
   use Ada.Exceptions;
   use AWS;

   Filter : constant String := "/jo.*";

   task Hotplug_Server is
      entry Start;
      entry Started;
      entry Stop;
   end Hotplug_Server;

   procedure Request (X, Y : Integer);
   --  Request URI resource to main server, output result

   Hotplug_Port : Natural := 1135;
   Com_Port     : Natural := 2122;

   --------------------
   -- Hotplug_Server --
   --------------------

   task body Hotplug_Server is
      use type Messages.Status_Code;
      WS : Server.HTTP;
      R  : Response.Data;
      CF : Config.Object;
   begin
      accept  Start;

      Config.Set.Server_Name    (CF, "Hotplug");
      Config.Set.Admin_URI      (CF, "/Admin-Page");
      Config.Set.Server_Host    (CF, "localhost");
      Config.Set.Server_Port    (CF, Hotplug_Port);
      Config.Set.Max_Connection (CF, 3);

      Server.Start (WS, SOAP_Hotplug_CB.Hotplug'Access, CF);

      R := Client.Hotplug.Register
        ("hp_test", SOAP_Hotplug_CB.Password,
         "http://localhost:" & Utils.Image (Com_Port),
         Filter, "http://localhost:" & Utils.Image (Hotplug_Port));

      if Response.Status_Code (R) = Messages.S200 then
         Text_IO.Put_Line ("Register OK");
      else
         Text_IO.Put_Line
           ("Register Error : " & Response.Message_Body (R));
         raise Constraint_Error;
      end if;
      Text_IO.Flush;

      accept  Started;

      accept Stop do
         R := AWS.Client.Hotplug.Unregister
           ("hp_test", SOAP_Hotplug_CB.Password,
            "http://localhost:" & Utils.Image (Com_Port), Filter);

         if Response.Status_Code (R) = Messages.S200 then
            Text_IO.Put_Line ("Unregister OK");
         else
            Text_IO.Put_Line
              ("Unregister Error : " & Response.Message_Body (R));
         end if;
         Text_IO.Flush;

         Server.Shutdown (WS);
      end Stop;
   exception
      when others =>
         Server.Shutdown (WS);
   end Hotplug_Server;

   -------------
   -- Request --
   -------------

   procedure Request (X, Y : Integer) is
      R : Integer;
      URL : constant String :=
        Server.Status.Local_URL (SOAP_Hotplug_CB.Main_Server);
   begin
      R := SOAP_Hotplug_Pack_Service.Client.Job1 (X, Y, URL & "/job");
      Text_IO.Put_Line ("Response: " & Utils.Image (R));
      R := SOAP_Hotplug_Pack_Service.Client.Job2 (X, Y, URL & "/job");
      Text_IO.Put_Line ("Response: " & Utils.Image (R));
      Text_IO.Flush;
   end Request;

begin
   Text_IO.Put_Line ("Starting main server...");

   Get_Free_Port (Hotplug_Port);
   Get_Free_Port (Com_Port);

   --  Write access file

   declare
      F : Text_IO.File_Type;
   begin
      Text_IO.Create (F, Text_IO.Out_File, "hotplug_access.ini");
      Text_IO.Put_Line
        (F, "hp_test:f8de61f1f97df3613fbe29b031eb52c6:localhost:"
         & Utils.Image (Hotplug_Port));
      Text_IO.Close (F);
   end;

   Server.Start
     (SOAP_Hotplug_CB.Main_Server, "Main",
      Admin_URI      => "/Admin-Page",
      Port           => 0,
      Max_Connection => 3,
      Callback       => SOAP_Hotplug_CB.Main'Access);

   Server.Hotplug.Activate
     (SOAP_Hotplug_CB.Main_Server'Access, Com_Port, "hotplug_access.ini",
      Host => "localhost");

   --  Send some requests

   Request (3, 7);
   Request (9, 2);

   --  Start hotplug now

   Hotplug_Server.Start;
   Hotplug_Server.Started;

   Request (3, 7);
   Request (9, 2);

   Text_IO.Put_Line ("Stop hotplug server");
   Text_IO.Flush;

   Hotplug_Server.Stop;

   Text_IO.Put_Line ("Shutdown hotplug server support");
   Text_IO.Flush;

   AWS.Server.Hotplug.Shutdown;

   Text_IO.Put_Line ("Shutdown main server");
   Text_IO.Flush;

   Server.Shutdown (SOAP_Hotplug_CB.Main_Server);

exception
   when E : others =>
      Text_IO.Put_Line ("Exception raised:" & Exception_Information (E));
      Text_IO.Flush;
      Hotplug_Server.Stop;
      AWS.Server.Hotplug.Shutdown;
      Server.Shutdown (SOAP_Hotplug_CB.Main_Server);
end Test_SOAP_Hotplug;
