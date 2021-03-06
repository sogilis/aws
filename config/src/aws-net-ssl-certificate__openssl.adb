------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2003-2012, AdaCore                     --
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

with System;
with Interfaces.C.Strings;

package body AWS.Net.SSL.Certificate is

   function NAME_oneline (Name : TSSL.X509_Name) return String;
   --  Return the value for Name

   ---------
   -- Get --
   ---------

   function Get (Socket : Socket_Type) return Object is
      use type System.Address;

      X509 : constant TSSL.X509 := TSSL.SSL_get_peer_certificate (Socket.SSL);

      Result : Object;
   begin
      if X509 = TSSL.Null_Pointer then
         return Undefined;

      else
         Result
           := (To_Unbounded_String
                 (NAME_oneline (TSSL.X509_get_subject_name (X509))),
               To_Unbounded_String
                 (NAME_oneline
                    (TSSL.X509_get_issuer_name (X509))));

         TSSL.X509_free (X509);
         return Result;
      end if;
   end Get;

   ------------
   -- Issuer --
   ------------

   function Issuer  (Certificate : Object) return String is
   begin
      return To_String (Certificate.Issuer);
   end Issuer;

   ------------------
   -- NAME_oneline --
   ------------------

   function NAME_oneline (Name : TSSL.X509_Name) return String is
   begin
      return Interfaces.C.Strings.Value
        (TSSL.X509_NAME_oneline (Name, TSSL.Null_Pointer, 0));
   end NAME_oneline;

   -------------
   -- Subject --
   -------------

   function Subject (Certificate : Object) return String is
   begin
      return To_String (Certificate.Subject);
   end Subject;

end AWS.Net.SSL.Certificate;
