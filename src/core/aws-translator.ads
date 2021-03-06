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

with Ada.Streams;
with Ada.Strings.Unbounded;

with AWS.Resources.Streams.Memory.ZLib;
with AWS.Utils;

package AWS.Translator is

   use Ada.Strings.Unbounded;

   package ZL renames AWS.Resources.Streams.Memory.ZLib;

   ------------
   -- Base64 --
   ------------

   procedure Base64_Encode
     (Data     : Unbounded_String;
      B64_Data : out Unbounded_String);

   function Base64_Encode
     (Data : Ada.Streams.Stream_Element_Array) return String;
   --  Encode Data using the base64 algorithm

   function Base64_Encode (Data : String) return String;
   --  Same as above but takes a string as input

   procedure Base64_Decode
     (B64_Data : Unbounded_String;
      Data     : out Unbounded_String);

   function Base64_Decode
     (B64_Data : String) return Ada.Streams.Stream_Element_Array;
   --  Decode B64_Data using the base64 algorithm

   function Base64_Decode (B64_Data : String) return String;

   --------
   -- QP --
   --------

   function QP_Decode (QP_Data : String) return String;
   --  Decode QP_Data using the Quoted Printable algorithm

   ------------------------------------
   -- String to Stream_Element_Array --
   ------------------------------------

   function To_String
     (Data : Ada.Streams.Stream_Element_Array) return String;
   pragma Inline (To_String);
   --  Convert a Stream_Element_Array to a string. Note that as this routine
   --  returns a String it should not be used with large array as this could
   --  break the stack size limit. Use the routine below for large array.

   function To_Stream_Element_Array
     (Data : String) return Ada.Streams.Stream_Element_Array;
   pragma Inline (To_Stream_Element_Array);
   --  Convert a String to a Stream_Element_Array

   function To_Unbounded_String
     (Data : Ada.Streams.Stream_Element_Array)
      return Ada.Strings.Unbounded.Unbounded_String;
   --  Convert a Stream_Element_Array to an Unbounded_String

   --------------------------
   --  Compress/Decompress --
   --------------------------

   subtype Compression_Level is ZL.Compression_Level;

   Default_Compression : constant Compression_Level := ZL.Default_Compression;

   function Compress
     (Data   : Ada.Streams.Stream_Element_Array;
      Level  : Compression_Level                := Default_Compression;
      Header : ZL.Header_Type                   := ZL.Default_Header)
      return Utils.Stream_Element_Array_Access;
   --  Returns Data compressed with a standard deflate algorithm based on the
   --  zlib library. The result is dynamically allocated and must be
   --  explicitly freed.

   function Decompress
     (Data   : Ada.Streams.Stream_Element_Array;
      Header : ZL.Header_Type                   := ZL.Default_Header)
      return Utils.Stream_Element_Array_Access;
   --  Returns Data decompressed based on the zlib library. The results is
   --  dynamically allocated and must be explicitly freed.

end AWS.Translator;
