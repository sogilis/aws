------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2007-2012, AdaCore                     --
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

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with GNAT.SHA1;

package AWS.Services.Web_Block.Context is

   type Object is tagged private;
   --  A context object, can be used to record key/name values

   Empty : constant Object;

   type Id is private;
   --  An object Id, the Id depends only on the context content. Two context
   --  with the very same content will have the same Id.

   function Image (CID : Id) return String;
   --  Returns CID string representation

   function Value (CID : String) return Id;
   --  Returns Id given it's string representation

   function Register (Context : Object) return Id;
   --  Register the context into the database, returns its Id

   function Exist (CID : Id) return Boolean;
   --  Returns True if CID context exists into the database

   function Get (CID : Id) return Object;
   --  Returns the context object corresponding to CID

   procedure Set_Value (Context : in out Object; Name, Value : String);
   --  Add a new name/value pair

   function Get_Value (Context : Object; Name : String) return String;
   --  Returns the value for the key Name or an empty string if does not exist

   generic
      type Data is private;
      Null_Data : Data;
   package Generic_Data is

      procedure Set_Value
        (Context : in out Object;
         Name    : String;
         Value   : Data);
      --  Set key/pair value for the SID

      function Get_Value (Context : Object; Name : String) return Data;
      pragma Inline (Get_Value);
      --  Returns the Value for Key in the session SID or Null_Data if
      --  key does not exist.

   end Generic_Data;

   function Exist (Context : Object; Name : String) return Boolean;
   --  Returns true if the key Name exist in this context

   procedure Remove (Context : in out Object; Name : String);
   --  Remove the context for key Name

private

   use GNAT;
   use Ada;

   package KV is new Containers.Indefinite_Hashed_Maps
     (String, String, Strings.Hash, "=");

   type Object is new KV.Map with null record;

   type Id is new SHA1.Message_Digest;

   Empty : constant Object := Object'(KV.Map with null record);

end AWS.Services.Web_Block.Context;
