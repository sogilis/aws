------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2004                            --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  $Id$

--  Test the upload directory config

with Ada.Text_IO;
with Ada.Exceptions;

with GNAT.Directory_Operations;
with GNAT.OS_Lib;

with AWS.Server;
with AWS.Client;
with AWS.Status;
with AWS.MIME;
with AWS.Response;
with AWS.OS_Lib;
with AWS.Parameters;
with AWS.Messages;
with AWS.Utils;

with Get_Free_Port;

procedure Upload5 is

   use Ada;
   use Ada.Text_IO;
   use GNAT;
   use AWS;

   function CB (Request : in Status.Data) return Response.Data;

   task Server is
      entry Started;
      entry Stopped;
   end Server;

   HTTP : AWS.Server.HTTP;

   Port : Natural := 7645;

   --------
   -- CB --
   --------

   function CB (Request : in Status.Data) return Response.Data is
      URI    : constant String          := Status.URI (Request);
      P_List : constant Parameters.List := Status.Parameters (Request);
   begin
      if URI = "/upload" then
         Put_Line ("Client Filename = "
                     & Parameters.Get (P_List, "filename", 2));

         declare
            Server_Filename : constant String
              := Parameters.Get (P_List, "filename");
         begin
            Put_Line ("Server Filename = " & Server_Filename);

            --  Checks that the first are in the upload directory

            if AWS.OS_Lib.Is_Regular_File (Server_Filename) then
               declare
                  Result : Boolean;
               begin
                  GNAT.OS_Lib.Delete_File (Server_Filename, Result);
               end;

               return Response.Build (MIME.Text_HTML, "call ok");

            else
               return Response.Build
                 (MIME.Text_HTML, "Server file not found!");
            end if;
         end;

      else
         Put_Line ("Unknown URI " & URI);
         return Response.Build
           (MIME.Text_HTML, URI & " not found", Messages.S404);
      end if;
   end CB;

   ------------
   -- Server --
   ------------

   task body Server is
   begin
      Get_Free_Port (Port);

      AWS.Server.Start
        (HTTP, "upload",
         CB'Unrestricted_Access,
         Port             => Port,
         Max_Connection   => 5,
         Upload_Directory => "upload_dir");

      Put_Line ("Server started");
      New_Line;

      accept Started;

      select
         accept Stopped;
      or
         delay 5.0;
         Put_Line ("Too much time to do the job !");
      end select;

      AWS.Server.Shutdown (HTTP);
   exception
      when E : others =>
         Put_Line ("Server Error " & Exceptions.Exception_Information (E));
   end Server;

   -------------
   -- Request --
   -------------

   procedure Request (URL : in String; Filename : in String) is
      R : Response.Data;
   begin
      R := Client.Upload (URL, Filename);
      Put_Line ("=> " & Response.Message_Body (R));
      New_Line;
   end Request;

begin
   --  First create the upload directory

   Directory_Operations.Make_Dir ("upload_dir");

   Put_Line ("Start main, wait for server to start...");

   Server.Started;

   Request
     ("http://localhost:" & Utils.Image (Port) & "/upload", "upload.ali");
   Request
     ("http://localhost:" & Utils.Image (Port) & "/upload", "upload.adb");

   Server.Stopped;

   --  Remove directory

   Directory_Operations.Remove_Dir ("upload_dir");

exception
   when E : others =>
      Put_Line ("Main Error " & Exceptions.Exception_Information (E));
end Upload5;