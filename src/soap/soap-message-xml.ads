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

with AWS.Client;

with SOAP.Message.Payload;
with SOAP.Message.Response;

package SOAP.Message.XML is

   SOAP_Error : exception renames SOAP.SOAP_Error;

   function Load_Payload (XML : String) return Message.Payload.Object;
   --  Build a Payload object by parsing the XML payload string

   function Load_Response
     (Connection : AWS.Client.HTTP_Connection)
      return Message.Response.Object'Class;
   --  Build a Response object (either a standard response or an error
   --  response) by parsing the HTTP client connection output.

   function Load_Response
     (XML : String) return Message.Response.Object'Class;
   --  Build a Response object (either a standard response or an error
   --  response) by parsing the XML response string.

   function Load_Response
     (XML : Unbounded_String) return Message.Response.Object'Class;
   --  As above but using an Unbounded_String

   function Image (O : Object'Class) return String;
   --  Returns XML representation of object O

   function Image (O : Object'Class) return Unbounded_String;
   --  Idem as above but returns an Unbounded_String instead of a String

end SOAP.Message.XML;
