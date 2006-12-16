------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2005-2006                          --
--                                 AdaCore                                  --
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

with Ada.Streams;

package body AWS.Net.Acceptors is

   Server_Index   : constant := 1;
   Signal_Index   : constant := 2;
   First_Index    : constant := 3;

   Socket_Command : constant := 1;

   ---------
   -- Get --
   ---------

   procedure Get
     (Acceptor        : in out Acceptor_Type;
      Socket          : out    Socket_Access;
      On_Accept_Error : access procedure
        (E : in Ada.Exceptions.Exception_Occurrence) := null)
   is
      use type Sets.Socket_Count;

      procedure Shutdown;
      pragma No_Return (Shutdown);

      --------------
      -- Shutdown --
      --------------

      procedure Shutdown is
      begin
         while Sets.Count (Acceptor.Set) > 0 loop
            Sets.Remove_Socket (Acceptor.Set, 1, Socket);
            Shutdown (Socket.all);

            --  We can free other sockets, because it is not
            --  used anywhere else when it is in socket set.

            Free (Socket);
         end loop;

         Free (Acceptor.W_Signal);

         raise Socket_Error;
      end Shutdown;

      First        : constant Boolean := True;
      Timeout      : array (Boolean) of Duration;

      Ready, Error : Boolean;
      Wait_Timeout : Duration;

   begin
      if Sets.Count (Acceptor.Set) = 0 then
         --  After shutdown of the server socket
         raise Socket_Error;
      end if;

      if Sets.Count (Acceptor.Set) > Acceptor.Force_Length then
         Timeout (First)     := Acceptor.Force_First_Timeout;
         Timeout (not First) := Acceptor.Force_Timeout;
      else
         Timeout (First)     := Acceptor.First_Timeout;
         Timeout (not First) := Acceptor.Timeout;
      end if;

      Wait_Timeout := Timeout (not First);

      loop
         Read_Ready : loop
            exit Read_Ready when Acceptor.Index > Acceptor.Last;

            Sets.Is_Read_Ready (Acceptor.Set, Acceptor.Index, Ready, Error);

            if Error or else Ready then
               Sets.Remove_Socket (Acceptor.Set, Acceptor.Index, Socket);

               Acceptor.Last := Acceptor.Last - 1;

               if Error then
                  Shutdown (Socket.all);
                  Free (Socket);

               elsif Ready then
                  return;
               else
                  raise Program_Error;
               end if;

            else
               --  Check for timeout

               declare
                  use Ada.Calendar;
                  Data : constant Socket_Data_Type
                    := Sets.Get_Data (Acceptor.Set, Acceptor.Index);
                  Diff : constant Duration
                    := Timeout (Data.First) - (Clock - Data.Time);
               begin
                  if Diff <= 0.0 then
                     Sets.Remove_Socket (Acceptor.Set, Acceptor.Index, Socket);
                     Acceptor.Last := Acceptor.Last - 1;
                     Shutdown (Socket.all);
                     Free (Socket);
                  else
                     if Diff < Wait_Timeout then
                        Wait_Timeout := Diff;
                     end if;

                     Acceptor.Index := Acceptor.Index + 1;
                  end if;
               end;
            end if;
         end loop Read_Ready;

         Sets.Wait (Acceptor.Set, Wait_Timeout);

         Acceptor.Last := Sets.Count (Acceptor.Set);

         Sets.Is_Read_Ready (Acceptor.Set, Server_Index, Ready, Error);

         if Error then
            Raise_Socket_Error
              (Acceptor.Server.all, "Accepting socket error.");

         elsif Ready then
            declare
               use Ada.Calendar;
               New_Socket : Socket_Type'Class := Acceptor.Constructor (False);
            begin
               --  We could not accept SSL socket because SSL handshake could
               --  take a long time inside Accept_Socket. We would make socket
               --  SSL later outside acceptor if necessary.

               Accept_Socket (Acceptor.Server.all, New_Socket);

               Sets.Add
                 (Acceptor.Set,
                  New_Socket,
                  Data => (Time => Clock, First => True),
                  Mode => Sets.Input);
            exception
               when E : Socket_Error =>
                  if On_Accept_Error /= null then
                     On_Accept_Error (E);
                  else
                     raise;
                  end if;
            end;
         end if;

         Sets.Is_Read_Ready (Acceptor.Set, Signal_Index, Ready, Error);

         if Error then
            Shutdown;

         elsif Ready then
            declare
               use Ada.Calendar;

               Socket : Socket_Access;
               Bytes  : Ada.Streams.Stream_Element_Array (1 .. 16);
               Last   : Ada.Streams.Stream_Element_Offset;
            begin
               --  Read bytes from signalling socket and take sockets from
               --  mailbox.

               begin
                  Receive (Acceptor.R_Signal.all, Bytes, Last);
               exception
                  when Socket_Error =>
                     Shutdown;
               end;

               for J in 1 .. Last loop
                  if Bytes (J) = Socket_Command then
                     Acceptor.Box.Get (Socket);
                     Sets.Add
                       (Acceptor.Set,
                        Socket,
                        Data  => (Time => Clock, First => False),
                        Mode  => Sets.Input);
                  else
                     raise Constraint_Error;
                  end if;
               end loop;
            end;
         end if;

         Acceptor.Index := First_Index;
      end loop;
   end Get;

   ---------------
   -- Give_Back --
   ---------------

   procedure Give_Back
     (Acceptor : in out Acceptor_Type;
      Socket   : in     Socket_Access) is
   begin
      Send (Acceptor.W_Signal.all, (1 => Socket_Command));
      Acceptor.Box.Add (Socket);
   end Give_Back;

   ------------
   -- Listen --
   ------------

   procedure Listen
     (Acceptor            : in out Acceptor_Type;
      Host                : in     String;
      Port                : in     Positive;
      Queue_Size          : in     Positive;
      Timeout             : in     Duration := Forever;
      First_Timeout       : in     Duration := Forever;
      Force_Timeout       : in     Duration := Forever;
      Force_First_Timeout : in     Duration := Forever;
      Force_Length        : in     Positive := Positive'Last)
   is
      use type Sets.Socket_Count;

      function New_Socket return Socket_Access;
      pragma Inline (New_Socket);

      ----------------
      -- New_Socket --
      ----------------

      function New_Socket return Socket_Access is
      begin
         return new Socket_Type'Class'(Acceptor.Constructor (False));
      end New_Socket;

   begin
      Acceptor.Server := New_Socket;
      Bind (Acceptor.Server.all, Host => Host, Port => Port);
      Listen (Acceptor.Server.all, Queue_Size => Queue_Size);

      Acceptor.R_Signal := New_Socket;
      Acceptor.W_Signal := New_Socket;
      Socket_Pair (Acceptor.W_Signal.all, Acceptor.R_Signal.all);
      Set_Timeout (Acceptor.R_Signal.all, 10.0);

      Sets.Reset (Acceptor.Set);
      Sets.Add (Acceptor.Set, Acceptor.Server, Sets.Input);
      Sets.Add (Acceptor.Set, Acceptor.R_Signal, Sets.Input);

      Acceptor.Index               := First_Index;
      Acceptor.Last                := Sets.Count (Acceptor.Set);
      Acceptor.Timeout             := Timeout;
      Acceptor.Force_Timeout       := Force_Timeout;
      Acceptor.First_Timeout       := First_Timeout;
      Acceptor.Force_First_Timeout := Force_First_Timeout;

      --  Take in account 2 auxiliary sockets, Server and R_Signal

      if Force_Length >= Positive'Last - 2 then
         Acceptor.Force_Length := Sets.Socket_Count (Force_Length);
      else
         Acceptor.Force_Length := Sets.Socket_Count (Force_Length + 2);
      end if;
   end Listen;

   -------------------
   -- Server_Socket --
   -------------------

   function Server_Socket
     (Acceptor : in Acceptor_Type) return Socket_Type'Class is
   begin
      return Acceptor.Server.all;
   end Server_Socket;

   ----------------------------
   -- Set_Socket_Constructor --
   ----------------------------

   procedure Set_Socket_Constructor
     (Acceptor : in out Acceptor_Type; Constructor : in Socket_Constructor) is
   begin
      Acceptor.Constructor := Constructor;
   end Set_Socket_Constructor;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown (Acceptor : in out Acceptor_Type) is
   begin
      if Acceptor.W_Signal /= null then
         declare
            W_Signal : Socket_Type'Class := Acceptor.W_Signal.all;
         begin
            --  Shutdown on a copy of the socket, because Free of the W_Signal
            --  on the accepting task could be faster than return from shutdown
            --  routine.

            Shutdown (W_Signal);
         end;
      end if;
   end Shutdown;

end AWS.Net.Acceptors;
