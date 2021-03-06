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

with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Text_IO;

with GNAT.Calendar.Time_IO;

with AWS.Templates;
with AWS.Utils;
with SOAP.Utils;

package body SOAP.Generator is

   use Ada;

   function Format_Name (O : Object; Name : String) return String;
   --  Returns Name formated with the Ada style if O.Ada_Style is true and
   --  Name unchanged otherwise.

   function Time_Stamp return String;
   --  Returns a time stamp Ada comment line

   function Version_String return String;
   --  Returns a version string Ada comment line

   procedure Put_File_Header (O : Object; File : Text_IO.File_Type);
   --  Add a standard file header into file

   procedure Put_Types_Header_Spec
     (O : Object; File : Text_IO.File_Type; Unit_Name : String);
   --  Put standard header for types body packages

   procedure Put_Types_Header_Body
     (O : Object; File : Text_IO.File_Type; Unit_Name : String);
   --  Put standard header for types spec packages

   procedure Put_Types
     (O      : Object;
      Proc   : String;
      Input  : WSDL.Parameters.P_Set;
      Output : WSDL.Parameters.P_Set);
   --  This must be called to create the data types for composite objects

   type Header_Mode is
     (Stub_Spec, Stub_Body,     -- URL based stub spec/body
      C_Stub_Spec, C_Stub_Body, -- Connection based stub spec/body
      Skel_Spec, Skel_Body);    -- skeleton spec/body

   subtype Stub_Header is Header_Mode range Stub_Spec .. C_Stub_Body;
   subtype Con_Stub_Header is Header_Mode range C_Stub_Spec .. C_Stub_Body;

   procedure Put_Header
     (File   : Text_IO.File_Type;
      O      : Object;
      Proc   : String;
      Input  : WSDL.Parameters.P_Set;
      Output : WSDL.Parameters.P_Set;
      Mode   : Header_Mode);
   --  Output procedure header into File. The terminating ';' or 'is' is
   --  outputed depending on Spec value. If Mode is in Con_Stub_Header the
   --  connection based spec is generated, otherwise it is the endpoint based.

   function Result_Type
     (O      : Object;
      Proc   : String;
      Output : WSDL.Parameters.P_Set) return String;
   --  Returns the result type given the output parameters

   procedure Header_Box
     (O    : Object;
      File : Text_IO.File_Type;
      Name : String);
   --  Generate header box

   function To_Unit_Name (Filename : String) return String;
   --  Returns the unit name given a filename following the GNAT
   --  naming scheme.

   type Elab_Pragma is (Off, Single, Children);
   --  Off      - no pragma Elaborate
   --  Single   - a single pragma for the unit
   --  Children - a pragma for each child unit

   procedure With_Unit
     (File       : Text_IO.File_Type;
      Name       : String;
      Elab       : Elab_Pragma := Single;
      Use_Clause : Boolean := False);
   --  Output a with clause for unit Name, also output a use clause if
   --  Use_Clause is set. A pragma Elaborate_All is issued for this unit if
   --  Elab is set.

   Root     : Text_IO.File_Type; -- Parent packages
   Type_Ads : Text_IO.File_Type; -- Child with all type definitions
   Tmp_Ads  : Text_IO.File_Type; -- Temp file for spec types
   Stub_Ads : Text_IO.File_Type; -- Child with client interface
   Stub_Adb : Text_IO.File_Type;
   Skel_Ads : Text_IO.File_Type; -- Child with server interface
   Skel_Adb : Text_IO.File_Type;
   CB_Ads   : Text_IO.File_Type; -- Child with all callback routines
   CB_Adb   : Text_IO.File_Type;

   --  Stub generator routines

   package Stub is

      procedure Start_Service
        (O             : in out Object;
         Name          : String;
         Documentation : String;
         Location      : String);

      procedure End_Service
        (O    : in out Object;
         Name : String);

      procedure New_Procedure
        (O          : in out Object;
         Proc       : String;
         SOAPAction : String;
         Namespace  : Name_Space.Object;
         Input      : WSDL.Parameters.P_Set;
         Output     : WSDL.Parameters.P_Set;
         Fault      : WSDL.Parameters.P_Set);

   end Stub;

   --  Skeleton generator routines

   package Skel is

      procedure Start_Service
        (O             : in out Object;
         Name          : String;
         Documentation : String;
         Location      : String);

      procedure End_Service
        (O    : in out Object;
         Name : String);

      procedure New_Procedure
        (O          : in out Object;
         Proc       : String;
         SOAPAction : String;
         Namespace  : Name_Space.Object;
         Input      : WSDL.Parameters.P_Set;
         Output     : WSDL.Parameters.P_Set;
         Fault      : WSDL.Parameters.P_Set);

   end Skel;

   --  Callback generator routines

   package CB is

      procedure Start_Service
        (O             : in out Object;
         Name          : String;
         Documentation : String;
         Location      : String);

      procedure End_Service
        (O    : in out Object;
         Name : String);

      procedure New_Procedure
        (O          : in out Object;
         Proc       : String;
         SOAPAction : String;
         Namespace  : Name_Space.Object;
         Input      : WSDL.Parameters.P_Set;
         Output     : WSDL.Parameters.P_Set;
         Fault      : WSDL.Parameters.P_Set);

   end CB;

   --  Simple name set used to keep record of all generated types

   package Name_Set is

      procedure Add (Name : String);
      --  Add new name into the set

      function Exists (Name : String) return Boolean;
      --  Returns true if Name is in the set

   end Name_Set;

   ---------------
   -- Ada_Style --
   ---------------

   procedure Ada_Style (O : in out Object) is
   begin
      O.Ada_Style := True;
   end Ada_Style;

   --------
   -- CB --
   --------

   package body CB is separate;

   -------------
   -- CVS_Tag --
   -------------

   procedure CVS_Tag (O : in out Object) is
   begin
      O.CVS_Tag := True;
   end CVS_Tag;

   -----------
   -- Debug --
   -----------

   procedure Debug (O : in out Object) is
   begin
      O.Debug := True;
   end Debug;

   -----------------
   -- End_Service --
   -----------------

   overriding procedure End_Service
     (O    : in out Object;
      Name : String)
   is
      U_Name : constant String := To_Unit_Name (Format_Name (O, Name));
      Buffer : String (1 .. 512);
      Last   : Natural;
   begin
      --  Root

      Text_IO.New_Line (Root);
      Text_IO.Put_Line (Root, "end " & U_Name & ";");

      Text_IO.Close (Root);

      --  Types

      --  Copy Tmp_Ads into Type_Ads

      Text_IO.Reset (Tmp_Ads, Text_IO.In_File);

      while not Text_IO.End_Of_File (Tmp_Ads) loop
         Text_IO.Get_Line (Tmp_Ads, Buffer, Last);
         Text_IO.Put_Line (Type_Ads, Buffer (1 .. Last));
      end loop;

      Text_IO.Close (Tmp_Ads);

      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "end " & U_Name & ".Types;");

      Text_IO.Close (Type_Ads);

      --  Stub

      if O.Gen_Stub then
         Stub.End_Service (O, Name);
         Text_IO.Close (Stub_Ads);
         Text_IO.Close (Stub_Adb);
      end if;

      --  Skeleton

      if O.Gen_Skel then
         Skel.End_Service (O, Name);
         Text_IO.Close (Skel_Ads);
         Text_IO.Close (Skel_Adb);
      end if;

      --  Callbacks

      if O.Gen_CB then
         CB.End_Service (O, Name);
         Text_IO.Close (CB_Ads);
         Text_IO.Close (CB_Adb);
      end if;
   end End_Service;

   --------------
   -- Endpoint --
   --------------

   procedure Endpoint (O : in out Object; URL : String) is
   begin
      O.Endpoint := To_Unbounded_String (URL);
   end Endpoint;

   -----------------
   -- Format_Name --
   -----------------

   function Format_Name (O : Object; Name : String) return String is

      function Ada_Format (Name : String) return String;
      --  Returns Name with the Ada style

      ----------------
      -- Ada_Format --
      ----------------

      function Ada_Format (Name : String) return String is
         Result : Unbounded_String;
      begin
         --  No need to reformat this name
         if not O.Ada_Style then
            return Name;
         end if;

         for K in Name'Range loop
            if K = Name'First then
               Append (Result, Characters.Handling.To_Upper (Name (K)));

            elsif Characters.Handling.Is_Upper (Name (K))
              and then not Characters.Handling.Is_Upper (Name (K - 1))
              and then K > Name'First
              and then Name (K - 1) /= '_'
              and then Name (K - 1) /= '.'
              and then K < Name'Last
              and then Name (K + 1) /= '_'
              and then Name (K + 1) /= '.'
            then
               Append (Result, "_" & Name (K));

            else
               Append (Result, Name (K));
            end if;
         end loop;

         return To_String (Result);
      end Ada_Format;

      Ada_Name : constant String := Ada_Format (Name);

   begin
      if Utils.Is_Ada_Reserved_Word (Name) then
         return "v_" & Ada_Name;
      else
         return Ada_Name;
      end if;
   end Format_Name;

   ------------
   -- Gen_CB --
   ------------

   procedure Gen_CB (O : in out Object) is
   begin
      O.Gen_CB := True;
   end Gen_CB;

   ----------------
   -- Header_Box --
   ----------------

   procedure Header_Box
     (O    : Object;
      File : Text_IO.File_Type;
      Name : String)
   is
      pragma Unreferenced (O);
   begin
      Text_IO.Put_Line
        (File, "   " & String'(1 .. 6 + Name'Length => '-'));
      Text_IO.Put_Line
        (File, "   -- " & Name & " --");
      Text_IO.Put_Line
        (File, "   " & String'(1 .. 6 + Name'Length => '-'));
   end Header_Box;

   ----------
   -- Main --
   ----------

   procedure Main (O : in out Object; Name : String) is
   begin
      O.Main := To_Unbounded_String (Name);
   end Main;

   --------------
   -- Name_Set --
   --------------

   package body Name_Set is separate;

   -------------------
   -- New_Procedure --
   -------------------

   overriding procedure New_Procedure
     (O          : in out Object;
      Proc       : String;
      SOAPAction : String;
      Namespace  : Name_Space.Object;
      Input      : WSDL.Parameters.P_Set;
      Output     : WSDL.Parameters.P_Set;
      Fault      : WSDL.Parameters.P_Set) is
   begin
      if not O.Quiet then
         Text_IO.Put_Line ("   > " & Proc);
      end if;

      Put_Types (O, Proc, Input, Output);

      if O.Gen_Stub then
         Stub.New_Procedure
           (O, Proc, SOAPAction, Namespace, Input, Output, Fault);
      end if;

      if O.Gen_Skel then
         Skel.New_Procedure
           (O, Proc, SOAPAction, Namespace, Input, Output, Fault);
      end if;

      if O.Gen_CB then
         CB.New_Procedure
           (O, Proc, SOAPAction, Namespace, Input, Output, Fault);
      end if;
   end New_Procedure;

   -------------
   -- No_Skel --
   -------------

   procedure No_Skel (O : in out Object) is
   begin
      O.Gen_Skel := False;
   end No_Skel;

   -------------
   -- No_Stub --
   -------------

   procedure No_Stub (O : in out Object) is
   begin
      O.Gen_Stub := False;
   end No_Stub;

   -------------
   -- Options --
   -------------

   procedure Options (O : in out Object; Options : String) is
   begin
      O.Options := To_Unbounded_String (Options);
   end Options;

   ---------------
   -- Overwrite --
   ---------------

   procedure Overwrite (O : in out Object) is
   begin
      O.Force := True;
   end Overwrite;

   ----------------
   -- Procs_Spec --
   ----------------

   function Procs_Spec (O : Object) return String is
   begin
      if O.Spec /= Null_Unbounded_String then
         return To_String (O.Spec);
      elsif O.Types_Spec /= Null_Unbounded_String then
         return To_String (O.Types_Spec);
      else
         return "";
      end if;
   end Procs_Spec;

   ---------------------
   -- Put_File_Header --
   ---------------------

   procedure Put_File_Header (O : Object; File : Text_IO.File_Type) is
   begin
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "--  wsdl2aws SOAP Generator v" & Version);
      Text_IO.Put_Line (File, "--");
      Text_IO.Put_Line (File, Version_String);
      Text_IO.Put_Line (File, Time_Stamp);
      Text_IO.Put_Line (File, "--");
      Text_IO.Put_Line (File, "--  $ wsdl2aws " & To_String (O.Options));
      Text_IO.New_Line (File);

      if O.CVS_Tag then
         Text_IO.Put_Line (File, "--  $" & "Id$");
         Text_IO.New_Line (File);
      end if;
   end Put_File_Header;

   ----------------
   -- Put_Header --
   ----------------

   procedure Put_Header
     (File   : Text_IO.File_Type;
      O      : Object;
      Proc   : String;
      Input  : WSDL.Parameters.P_Set;
      Output : WSDL.Parameters.P_Set;
      Mode   : Header_Mode)
   is
      use Ada.Strings.Fixed;
      use type SOAP.WSDL.Parameters.P_Set;
      use type SOAP.WSDL.Parameters.Kind;

      procedure Put_Indent (Last : Character := ' ');
      --  Ouput proper indentation spaces

      procedure Input_Parameters;
      --  Output input parameters

      procedure Output_Parameters_And_End;
      --  Output output parameters for function

      Max_Len : Positive := 8;
      N       : WSDL.Parameters.P_Set;

      ----------------------
      -- Input_Parameters --
      ----------------------

      procedure Input_Parameters is
      begin
         if Input /= null then
            --  Input parameters

            N := Input;

            while N /= null loop
               declare
                  Name : constant String
                    := Format_Name (O, To_String (N.Name));
               begin
                  Text_IO.Put (File, Name);
                  Text_IO.Put (File, (Max_Len - Name'Length) * ' ');
               end;

               Text_IO.Put (File, " : ");

               case N.Mode is
                  when WSDL.Parameters.K_Simple =>
                     Text_IO.Put (File, WSDL.To_Ada (N.P_Type));

                  when WSDL.Parameters.K_Derived =>
                     Text_IO.Put (File, To_String (N.D_Name) & "_Type");

                  when WSDL.Parameters.K_Enumeration =>
                     Text_IO.Put (File, To_String (N.E_Name) & "_Type");

                  when WSDL.Parameters.K_Record | WSDL.Parameters.K_Array =>
                     Text_IO.Put
                       (File, Format_Name (O, To_String (N.T_Name) & "_Type"));
               end case;

               if N.Next /= null then
                  Text_IO.Put_Line (File, ";");
                  Put_Indent;
               end if;

               N := N.Next;
            end loop;
         end if;
      end Input_Parameters;

      -------------------------------
      -- Output_Parameters_And_End --
      -------------------------------

      procedure Output_Parameters_And_End is
      begin
         if Output /= null then
            Text_IO.New_Line (File);
            Put_Indent;
            Text_IO.Put (File, "return ");

            Text_IO.Put (File, Result_Type (O, Proc, Output));
         end if;

         --  End header depending on the mode

         case Mode is
            when Stub_Spec | Skel_Spec | C_Stub_Spec =>
               Text_IO.Put_Line (File, ";");

            when Stub_Body | C_Stub_Body =>
               Text_IO.New_Line (Stub_Adb);
               Text_IO.Put_Line (Stub_Adb, "   is");

            when Skel_Body =>
               null;
         end case;
      end Output_Parameters_And_End;

      ----------------
      -- Put_Indent --
      ----------------

      procedure Put_Indent (Last : Character := ' ') is
      begin
         if Mode = Skel_Spec then
            Text_IO.Put (File, "   ");
         end if;
         Text_IO.Put (File, "     " & Last);
      end Put_Indent;

      L_Proc : constant String := Format_Name (O, Proc);

   begin
      --  Compute maximum name length

      if Mode in Con_Stub_Header then
         --  Size of connection parameter
         Max_Len := 10;
      end if;

      N := Input;

      while N /= null loop
         Max_Len := Positive'Max
           (Max_Len, Format_Name (O, To_String (N.Name))'Length);
         N := N.Next;
      end loop;

      if Mode in Con_Stub_Header then
         --  Ouput header for connection based spec

         if Output = null then
            Text_IO.Put (File, "   procedure " & L_Proc);

            if Mode in Stub_Header or else Input /= null then
               Text_IO.New_Line (File);
            end if;

         else
            Text_IO.Put_Line (File, "   function " & L_Proc);
         end if;

         if Mode in Stub_Header then
            Put_Indent ('(');
            Text_IO.Put (File, "Connection : AWS.Client.HTTP_Connection");
         end if;

         if Input /= null then
            Text_IO.Put_Line (File, ";");
            Put_Indent;
            Input_Parameters;
         end if;

         if Input /= null or else Mode in Stub_Header then
            Text_IO.Put (File, ")");
         end if;

      else
         --  Ouput header for endpoint based spec

         if Output = null then
            Text_IO.Put (File, "procedure " & L_Proc);

            if Mode in Stub_Header or else Input /= null then
               Text_IO.New_Line (File);
            end if;

         else
            Text_IO.Put_Line (File, "function " & L_Proc);
         end if;

         if Input /= null or else Mode in Stub_Header then
            Put_Indent ('(');
         end if;

         Input_Parameters;

         if Mode in Stub_Header then
            if Input /= null then
               Text_IO.Put_Line (File, ";");
               Put_Indent;
            end if;

            Text_IO.Put (File, "Endpoint");
            Text_IO.Put (File, (Max_Len - 8) * ' ');
            Text_IO.Put_Line
              (File, " : String := " & To_String (O.Unit) & ".URL;");

            Put_Indent;
            Text_IO.Put (File, "Timeouts");
            Text_IO.Put (File, (Max_Len - 8) * ' ');
            Text_IO.Put
              (File, " : AWS.Client.Timeouts_Values := "
               & To_String (O.Unit) & ".Timeouts");
         end if;

         if Input /= null or else Mode in Stub_Header then
            Text_IO.Put (File, ")");
         end if;
      end if;

      Output_Parameters_And_End;
   end Put_Header;

   ---------------
   -- Put_Types --
   ---------------

   procedure Put_Types
     (O      : Object;
      Proc   : String;
      Input  : WSDL.Parameters.P_Set;
      Output : WSDL.Parameters.P_Set)
   is
      use Characters.Handling;
      use type WSDL.Parameters.Kind;
      use type WSDL.Parameters.P_Set;

      procedure Generate_Record
        (Name   : String;
         P      : WSDL.Parameters.P_Set;
         Output : Boolean               := False);
      --  Output record definitions (type and routine conversion)

      function Type_Name (N : WSDL.Parameters.P_Set) return String;
      --  Returns the name of the type for parameter on node N

      procedure Generate_Array
        (Name  : String;
         P     : WSDL.Parameters.P_Set;
         Regen : Boolean);
      --  Generate array definitions (type and routine conversion)

      procedure Generate_Derived
        (Name : String;
         P    : WSDL.Parameters.P_Set);
      --  Generate derived type definition

      procedure Generate_Enumeration
        (Name : String;
         P    : WSDL.Parameters.P_Set);
      --  Generate enumeration type definition

      function Generate_Namespace
        (NS     : Name_Space.Object;
         Create : Boolean) return String;
      --  Generate the namespace package from NS

      procedure Generate_References
        (File : Text_IO.File_Type;
         P    : WSDL.Parameters.P_Set);
      --  Generates with/use clauses for all referenced types

      procedure Initialize_Types_Package
        (P            : WSDL.Parameters.P_Set;
         Name         : String;
         Output       : Boolean;
         Prefix       : out Unbounded_String;
         F_Ads, F_Adb : out Text_IO.File_Type;
         Regen        : Boolean := False);
      --  Creates the full namespaces if needed and return it in Prefix.
      --  Creates also the package hierarchy. Returns a spec and body file
      --  descriptor.

      procedure Finalize_Types_Package
        (Prefix       : Unbounded_String;
         F_Ads, F_Adb : in out Text_IO.File_Type;
         No_Body      : Boolean := False);
      --  Generate code to terminate the package and close files

      procedure Output_Types (P : WSDL.Parameters.P_Set);
      --  Output types conversion routines

      function Get_Routine (P : WSDL.Parameters.P_Set) return String;
      --  Returns the Get routine for the given type

      function Set_Routine (P : WSDL.Parameters.P_Set) return String;
      --  Returns the constructor routine for the given type

      function Set_Type (Name : String) return String;
      --  Returns the SOAP type for Name

      function Is_Inside_Record (Name : String) return Boolean;
      --  Returns True if Name is defined inside a record in the Input
      --  or Output parameter list.

      ----------------------------
      -- Finalize_Types_Package --
      ----------------------------

      procedure Finalize_Types_Package
        (Prefix       : Unbounded_String;
         F_Ads, F_Adb : in out Text_IO.File_Type;
         No_Body      : Boolean := False) is
      begin
         Text_IO.New_Line (F_Ads);
         Text_IO.Put_Line
           (F_Ads, "end " & To_Unit_Name (To_String (Prefix)) & ';');
         Text_IO.Close (F_Ads);

         if No_Body then
            Text_IO.Delete (F_Adb);
         else
            Text_IO.New_Line (F_Adb);
            Text_IO.Put_Line
              (F_Adb, "end " & To_Unit_Name (To_String (Prefix)) & ';');
            Text_IO.Close (F_Adb);
         end if;
      end Finalize_Types_Package;

      --------------------
      -- Generate_Array --
      --------------------

      procedure Generate_Array
        (Name  : String;
         P     : WSDL.Parameters.P_Set;
         Regen : Boolean)
      is
         function To_Ada_Type (Name : String) return String;
         --  Returns the Ada corresponding type

         -----------------
         -- To_Ada_Type --
         -----------------

         function To_Ada_Type (Name : String) return String is
         begin
            if WSDL.Is_Standard (Name) then
               return WSDL.To_Ada
                 (WSDL.To_Type (Name), Context => WSDL.Component);

            else
               return Format_Name (O, Name) & "_Type";
            end if;
         end To_Ada_Type;

         S_Name  : constant String := Name (Name'First .. Name'Last - 5);
         --  Simple name without the ending _Type

         F_Name  : constant String := Format_Name (O, Name);
         T_Name  : constant String := To_String (P.E_Type);

         Prefix  : Unbounded_String;
         Arr_Ads : Text_IO.File_Type;
         Arr_Adb : Text_IO.File_Type;

      begin
         Initialize_Types_Package
           (P, F_Name, False, Prefix, Arr_Ads, Arr_Adb, Regen);

         if not Regen then
            Text_IO.New_Line (Tmp_Ads);
            Text_IO.Put_Line
              (Tmp_Ads, "   " & String'(1 .. 12 + F_Name'Length => '-'));
            Text_IO.Put_Line
              (Tmp_Ads, "   -- Array " & F_Name & " --");
            Text_IO.Put_Line
              (Tmp_Ads, "   " & String'(1 .. 12 + F_Name'Length => '-'));

            Text_IO.New_Line (Tmp_Ads);
         end if;

         --  Is types are to be reused from an Ada  spec ?

         if Types_Spec (O) = "" then
            --  No user's spec, generate all type definitions

            --  Array type

            if P.Length = 0 then
               --  Unconstrained array
               Text_IO.Put_Line
                 (Arr_Ads,
                  "   type " & F_Name & " is array (Positive range <>) of "
                    & To_Ada_Type (T_Name) & ";");

            else
               --  A constrained array

               Text_IO.Put_Line
                 (Arr_Ads,
                  "   subtype " & F_Name & "_Index is Positive range 1 .. "
                    & AWS.Utils.Image (P.Length) & ";");
               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads,
                  "   type " & F_Name & " is array (" & F_Name & "_Index)"
                    & " of " & To_Ada_Type (T_Name) & ";");
            end if;

            if not Regen then
               Text_IO.Put_Line
                 (Tmp_Ads, "   subtype " & F_Name);
               Text_IO.Put_Line
                 (Tmp_Ads, "     is "
                  & To_Unit_Name (To_String (Prefix)) & '.' & F_Name & ';');
            end if;

            --  Access to it

            --  Safe pointer, needed only for unconstrained arrays

            if P.Length = 0 then
               Text_IO.Put_Line
                 (Arr_Ads, "   type "
                    & F_Name & "_Access" & " is access all " & F_Name & ';');

               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads, "   package " & F_Name & "_Safe_Pointer is");
               Text_IO.Put_Line
                 (Arr_Ads, "      new SOAP.Utils.Safe_Pointers");
               Text_IO.Put_Line
                 (Arr_Ads,
                  "            (" & F_Name & ", " & F_Name & "_Access);");

               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads, "   subtype " & F_Name & "_Safe_Access");
               Text_IO.Put_Line
                 (Arr_Ads, "      is " & F_Name
                    & "_Safe_Pointer.Safe_Pointer;");

               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads, "   function ""+""");
               Text_IO.Put_Line
                 (Arr_Ads, "     (O : " & F_Name & ')');
               Text_IO.Put_Line
                 (Arr_Ads, "      return " & F_Name & "_Safe_Access");
               Text_IO.Put_Line
                 (Arr_Ads, "      renames "
                  & F_Name & "_Safe_Pointer.To_Safe_Pointer;");
               Text_IO.Put_Line
                 (Arr_Ads, "   --  Convert an array to a safe pointer");

               if not Regen then
                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads, "   function ""+""");
                  Text_IO.Put_Line
                    (Tmp_Ads, "     (O : "
                     & To_Unit_Name (To_String (Prefix)) & '.' & F_Name & ')');
                  Text_IO.Put_Line
                    (Tmp_Ads, "      return "
                     & To_Unit_Name (To_String (Prefix))
                     & '.' & F_Name & "_Safe_Access");
                  Text_IO.Put_Line
                    (Tmp_Ads, "      renames "
                     & To_Unit_Name (To_String (Prefix)) & '.' & F_Name
                     & "_Safe_Pointer.To_Safe_Pointer;");
                  Text_IO.Put_Line
                    (Tmp_Ads, "   --  Convert an array to a safe pointer");
               end if;
            end if;

         else
            --  Here we have a reference to a spec, just build alias to it

            Text_IO.New_Line (Arr_Ads);

            if P.Length /= 0 then
               --  This is a constrained array, create the index subtype
               Text_IO.Put_Line
                 (Arr_Ads,
                  "   subtype " & F_Name & "_Index is Positive range 1 .. "
                  & AWS.Utils.Image (P.Length) & ";");

               if not Regen then
                  Text_IO.Put_Line
                    (Tmp_Ads,
                     "   subtype " & F_Name & "_Index is Positive range 1 .. "
                     & AWS.Utils.Image (P.Length) & ";");
               end if;
            end if;

            Text_IO.Put_Line
              (Arr_Ads, "   subtype " & F_Name & " is "
               & Types_Spec (O) & "." & To_String (P.T_Name) & ";");

            if not Regen then
               Text_IO.Put_Line
                 (Tmp_Ads, "   subtype " & F_Name & " is "
                  & Types_Spec (O) & "." & To_String (P.T_Name) & ";");
            end if;

            if Is_Inside_Record (S_Name) then
               --  Only if this array is inside a record and we don't have
               --  generated this support yet.

               if not Regen then
                  Text_IO.New_Line (Tmp_Ads);

                  Header_Box (O, Tmp_Ads, "Safe Array " & F_Name);

                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads, "   subtype " & F_Name & "_Safe_Access");
                  Text_IO.Put_Line
                    (Tmp_Ads, "      is " & Types_Spec (O) & "."
                     & To_String (P.T_Name) & "_Safe_Pointer.Safe_Pointer;");

                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads, "   function ""+""");
                  Text_IO.Put_Line
                    (Tmp_Ads, "     (O : " & F_Name & ')');
                  Text_IO.Put_Line
                    (Tmp_Ads, "      return " & F_Name & "_Safe_Access");
                  Text_IO.Put_Line
                    (Tmp_Ads, "      renames " & Procs_Spec (O) & "."
                     & To_String (P.T_Name)
                     & "_Safe_Pointer.To_Safe_Pointer;");
                  Text_IO.Put_Line
                    (Tmp_Ads, "   --  Convert an array to a safe pointer");
               end if;

               Text_IO.New_Line (Arr_Ads);

               Header_Box (O, Arr_Ads, "Safe Array " & F_Name);

               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads, "   subtype " & F_Name & "_Safe_Access");
               Text_IO.Put_Line
                 (Arr_Ads, "      is " & Types_Spec (O) & "."
                  & To_String (P.T_Name) & "_Safe_Pointer.Safe_Pointer;");

               Text_IO.New_Line (Arr_Ads);
               Text_IO.Put_Line
                 (Arr_Ads, "   function ""+""");
               Text_IO.Put_Line
                 (Arr_Ads, "     (O : " & F_Name & ')');
               Text_IO.Put_Line
                 (Arr_Ads, "      return " & F_Name & "_Safe_Access");
               Text_IO.Put_Line
                 (Arr_Ads, "      renames " & Procs_Spec (O) & "."
                  & To_String (P.T_Name) & "_Safe_Pointer.To_Safe_Pointer;");
               Text_IO.Put_Line
                 (Arr_Ads, "   --  Convert an array to a safe pointer");
            end if;
         end if;

         Text_IO.New_Line (Arr_Ads);

         if P.Length = 0 then
            Text_IO.Put_Line
              (Arr_Ads, "   function To_" & F_Name
               & " is new SOAP.Utils.To_T_Array");
         else
            Text_IO.Put_Line
              (Arr_Ads, "   function To_" & F_Name
                 & " is new SOAP.Utils.To_T_Array_C");
         end if;

         if not Regen then
            Text_IO.New_Line (Tmp_Ads);
            Text_IO.Put_Line
              (Tmp_Ads, "   function To_" & F_Name);
            Text_IO.Put_Line
              (Tmp_Ads, "     (From : SOAP.Types.Object_Set)");
            Text_IO.Put_Line (Tmp_Ads, "      return " & F_Name);
            Text_IO.Put_Line
              (Tmp_Ads, "      renames "
               & To_Unit_Name (To_String (Prefix)) & ".To_" & F_Name & ';');
         end if;

         Text_IO.Put
           (Arr_Ads, "     (" & To_Ada_Type (T_Name) & ", ");

         if P.Length = 0 then
            Text_IO.Put (Arr_Ads, F_Name);
         else
            Text_IO.Put (Arr_Ads, F_Name & "_Index, " & F_Name);
         end if;

         Text_IO.Put_Line (Arr_Ads, ", " & Get_Routine (P) & ");");

         Text_IO.New_Line (Arr_Ads);

         if P.Length = 0 then
            Text_IO.Put_Line
              (Arr_Ads, "   function To_Object_Set"
                 & " is new SOAP.Utils.To_Object_Set");
         else
            Text_IO.Put_Line
              (Arr_Ads, "   function To_Object_Set"
                 & " is new SOAP.Utils.To_Object_Set_C");
         end if;

         if not Regen then
            Text_IO.New_Line (Tmp_Ads);
            Text_IO.Put_Line
              (Tmp_Ads, "   function To_Object_Set");
            Text_IO.Put_Line
              (Tmp_Ads, "     (From : " & F_Name & ')');
            Text_IO.Put_Line (Tmp_Ads, "      return SOAP.Types.Object_Set");
            Text_IO.Put_Line
              (Tmp_Ads, "      renames "
               & To_Unit_Name (To_String (Prefix)) & ".To_Object_Set;");
         end if;

         Text_IO.Put
           (Arr_Ads, "     (" & To_Ada_Type (T_Name) & ", ");

         if P.Length = 0 then
            Text_IO.Put_Line (Arr_Ads, F_Name & ",");
         else
            Text_IO.Put_Line (Arr_Ads, F_Name & "_Index, " & F_Name & ",");
         end if;

         Text_IO.Put_Line
           (Arr_Ads,
            "      " & Set_Type (T_Name) & ", " & Set_Routine (P) & ");");

         Finalize_Types_Package (Prefix, Arr_Ads, Arr_Adb, No_Body => True);
      end Generate_Array;

      ----------------------
      -- Generate_Derived --
      ----------------------

      procedure Generate_Derived
        (Name : String;
         P    : WSDL.Parameters.P_Set)
      is
         F_Name : constant String := Format_Name (O, Name);
         T_Name : constant String := WSDL.To_Ada (P.Parent_Type);

         Prefix  : Unbounded_String;
         Der_Ads : Text_IO.File_Type;
         Der_Adb : Text_IO.File_Type;

      begin
         Initialize_Types_Package (P, F_Name, False, Prefix, Der_Ads, Der_Adb);

         Text_IO.New_Line (Tmp_Ads);

         --  Is types are to be reused from an Ada  spec ?

         if Types_Spec (O) = "" then
            Text_IO.Put_Line
              (Der_Ads, "   type " & F_Name & " is new " & T_Name & ";");
         else
            Text_IO.Put_Line
              (Der_Ads, "   subtype " & F_Name & " is "
               & Types_Spec (O) & "." & To_String (P.D_Name) & ";");
         end if;

         Text_IO.Put_Line
           (Tmp_Ads, "   subtype " & F_Name);
         Text_IO.Put_Line
           (Tmp_Ads, "     is " & To_Unit_Name (To_String (Prefix)) & '.'
            & F_Name & ';');

         Finalize_Types_Package (Prefix, Der_Ads, Der_Adb, No_Body => True);
      end Generate_Derived;

      --------------------------
      -- Generate_Enumeration --
      --------------------------

      procedure Generate_Enumeration
        (Name : String;
         P    : WSDL.Parameters.P_Set)
      is
         use type WSDL.Parameters.E_Node_Access;

         F_Name : constant String := Format_Name (O, Name);

         function Image (E : WSDL.Parameters.E_Node_Access) return String;
         --  Returns the enumeration definition

         -----------
         -- Image --
         -----------

         function Image (E : WSDL.Parameters.E_Node_Access) return String is
            Col    : constant Natural := 13 + F_Name'Length;
            Sep    : constant String := ASCII.LF & "     ";
            Result : Unbounded_String;
            N      : WSDL.Parameters.E_Node_Access := E;
         begin
            while N /= null loop

               if Result = Null_Unbounded_String then
                  Append (Result, "(");
               else
                  Append (Result, ", ");
               end if;

               Append (Result, To_String (N.Value));

               N := N.Next;
            end loop;

            Append (Result, ")");

            if Col + Length (Result) > 80 then
               --  Split the result in multiple line
               Result := Sep & Result;

               declare
                  Line_Size : constant := 70;
                  K         : Natural := Line_Size;
               begin
                  while K < Length (Result) loop
                     for I in reverse 1 .. K loop
                        if Element (Result, I) = ',' then
                           Insert (Result, I + 1, Sep);
                           exit;
                        end if;
                     end loop;

                     K := K + Line_Size;
                  end loop;
               end;
            end if;

            return To_String (Result);
         end Image;

         N       : WSDL.Parameters.E_Node_Access := P.E_Def;
         Prefix  : Unbounded_String;
         Enu_Ads : Text_IO.File_Type;
         Enu_Adb : Text_IO.File_Type;

      begin
         Initialize_Types_Package (P, F_Name, False, Prefix, Enu_Ads, Enu_Adb);

         Text_IO.New_Line (Enu_Ads);

         --  Is types are to be reused from an Ada  spec ?

         if Types_Spec (O) = "" then
            Text_IO.Put_Line
              (Enu_Ads, "   type " & F_Name & " is " & Image (P.E_Def) & ";");
         else
            Text_IO.Put_Line
              (Enu_Ads, "   subtype " & F_Name & " is "
               & Types_Spec (O) & "." & To_String (P.E_Name) & ";");
         end if;

         Text_IO.New_Line (Tmp_Ads);

         Text_IO.Put_Line
           (Tmp_Ads, "   subtype " & F_Name & " is "
            & To_Unit_Name (To_String (Prefix)) & "." & F_Name & ';');

         --  Generate Image function

         Text_IO.New_Line (Enu_Ads);
         Text_IO.Put_Line
           (Enu_Ads,
            "   function Image (E : " & F_Name & ") return String;");

         Text_IO.New_Line (Tmp_Ads);
         Text_IO.Put_Line
           (Tmp_Ads, "   function Image (E : " & F_Name & ")");
         Text_IO.Put_Line
           (Tmp_Ads, "      return String ");
         Text_IO.Put_Line
           (Tmp_Ads, "      renames "
            & To_Unit_Name (To_String (Prefix)) & ".Image;");

         Text_IO.New_Line (Enu_Adb);
         Text_IO.Put_Line
           (Enu_Adb,
            "   function Image (E : " & F_Name & ") return String is");
         Text_IO.Put_Line (Enu_Adb, "   begin");
         Text_IO.Put_Line (Enu_Adb, "      case E is");

         while N /= null loop
            Text_IO.Put (Enu_Adb, "         when ");

            if Types_Spec (O) /= "" then
               Text_IO.Put (Enu_Adb, Types_Spec (O) & '.');
            end if;

            Text_IO.Put_Line
              (Enu_Adb, To_String (N.Value)
                 & " => return """ & To_String (N.Value) & """;");

            N := N.Next;
         end loop;

         Text_IO.Put_Line (Enu_Adb, "      end case;");
         Text_IO.Put_Line (Enu_Adb, "   end Image;");

         Finalize_Types_Package (Prefix, Enu_Ads, Enu_Adb);
      end Generate_Enumeration;

      ------------------------
      -- Generate_Namespace --
      ------------------------

      function Generate_Namespace
        (NS     : Name_Space.Object;
         Create : Boolean) return String
      is
         use type Name_Space.Object;

         function Gen_Dir (Prefix, Name : String) return String;
         --  ???

         function Gen_Package (Prefix, Name : String) return String;
         --  ???

         -------------
         -- Gen_Dir --
         -------------

         function Gen_Dir (Prefix, Name : String) return String is
            F : constant Natural := Name'First;
            L : Natural;
         begin
            L := Strings.Fixed.Index
              (Name (F .. Name'Last), Strings.Maps.To_Set (":/."));

            if L = 0 then
               return Gen_Package (Prefix, Name (F .. Name'Last));
            else
               return Gen_Dir
                 (Gen_Package (Prefix, Name (F .. L - 1)),
                  Name (L + 1 .. Name'Last));
            end if;
         end Gen_Dir;

         -----------------
         -- Gen_Package --
         -----------------

         function Gen_Package (Prefix, Name : String) return String is

            function Get_Prefix return String;
            --  Retruns Prefix & '-' if prefix is not empty

            function Get_Name (Name : String) return String;
            --  Returns n is a valid identifier, prefix with 'n' is number

            --------------
            -- Get_Name --
            --------------

            function Get_Name (Name : String) return String is
               N : constant String := Format_Name (O, Name);
            begin
               if Strings.Fixed.Count
                 (Name, Strings.Maps.To_Set ("0123456789")) = Name'Length
               then
                  return 'n' & N;
               else
                  return N;
               end if;
            end Get_Name;

            ----------------
            -- Get_Prefix --
            ----------------

            function Get_Prefix return String is
            begin
               if Prefix = "" then
                  return "";
               else
                  return Prefix & '-';
               end if;
            end Get_Prefix;

            N    : constant String
              := Get_Prefix & Get_Name
                (Strings.Fixed.Translate
                     (Name,
                      Strings.Maps.To_Mapping ("./:", "___")));
            File : Text_IO.File_Type;
         begin
            if Create then
               Text_IO.Create (File, Text_IO.Out_File, To_Lower (N) & ".ads");
               Put_File_Header (O, File);

               Text_IO.Put_Line (File, "package " & To_Unit_Name (N) & " is");
               Text_IO.Put_Line (File, "   pragma Pure;");
               Text_IO.Put_Line (File, "end " & To_Unit_Name (N) & ';');

               Text_IO.Close (File);
            end if;
            return N;
         end Gen_Package;

      begin
         if NS = Name_Space.No_Name_Space
           or else Name_Space.Value (NS) = ""
         then
            return Generate_Namespace (Name_Space.AWS, True);

         else
            declare
               V     : constant String := Name_Space.Value (NS);
               First : Positive := V'First;
               Last  : Positive := V'Last;
               K     : Natural;
            begin
               --  Remove http:// prefix if present
               if V (V'First .. V'First + 6) = "http://" then
                  First := First + 7;
               end if;

               --  Remove trailing / if present

               while V (Last) = '/' loop
                  Last := Last - 1;
               end loop;

               K := Strings.Fixed.Index
                 (V (First .. Last), "/", Strings.Backward);

               if K = 0 then
                  return Gen_Dir ("", V (First .. Last));
               else
                  return Gen_Package
                    (Gen_Dir ("", V (First .. K - 1)), V (K + 1 .. Last));
               end if;
            end;
         end if;
      end Generate_Namespace;

      ---------------------
      -- Generate_Record --
      ---------------------

      procedure Generate_Record
        (Name   : String;
         P      : WSDL.Parameters.P_Set;
         Output : Boolean               := False)
      is
         use type SOAP.Name_Space.Object;

         F_Name  : constant String := Format_Name (O, Name);

         R       : WSDL.Parameters.P_Set;
         N       : WSDL.Parameters.P_Set;

         Max     : Positive;

         Prefix  : Unbounded_String;

         Rec_Ads : Text_IO.File_Type;
         Rec_Adb : Text_IO.File_Type;

      begin
         Initialize_Types_Package
           (P, F_Name, Output, Prefix, Rec_Ads, Rec_Adb);

         if Output then
            R := P;
         else
            R := P.P;
         end if;

         --  Generate record type

         Text_IO.New_Line (Tmp_Ads);
         Header_Box (O, Tmp_Ads, "Record " & F_Name);

         --  Is types are to be reused from an Ada spec ?

         if Types_Spec (O) = "" then

            --  Compute max field width

            N := R;

            Max := 1;

            while N /= null loop
               Max := Positive'Max
                 (Max, Format_Name (O, To_String (N.Name))'Length);
               N := N.Next;
            end loop;

            --  Output field

            N := R;

            Text_IO.New_Line (Rec_Ads);

            Text_IO.Put_Line
              (Rec_Ads, "   type " & F_Name & " is record");

            while N /= null loop
               declare
                  F_Name : constant String
                    := Format_Name (O, To_String (N.Name));
               begin
                  Text_IO.Put
                    (Rec_Ads, "      "
                       & F_Name
                       & String'(1 .. Max - F_Name'Length => ' ') & " : ");
               end;

               Text_IO.Put (Rec_Ads, Format_Name (O, Type_Name (N)));

               Text_IO.Put_Line (Rec_Ads, ";");

               if N.Mode = WSDL.Parameters.K_Array then
                  Text_IO.Put_Line
                    (Rec_Ads,
                     "      --  Access items with : result.Item (n)");
               end if;

               N := N.Next;
            end loop;

            Text_IO.Put_Line
              (Rec_Ads, "   end record;");

            Text_IO.Put_Line (Tmp_Ads, "   subtype " & F_Name);
            Text_IO.Put_Line
              (Tmp_Ads, "     is "
               & To_Unit_Name (To_String (Prefix)) & '.' & F_Name & ';');

         else
            Text_IO.New_Line (Rec_Ads);
            Text_IO.Put_Line
              (Rec_Ads, "   subtype " & F_Name & " is "
               & Types_Spec (O) & "." & To_String (P.T_Name) & ";");

            Text_IO.New_Line (Tmp_Ads);
            Text_IO.Put_Line
              (Tmp_Ads, "   subtype " & F_Name & " is "
               & Types_Spec (O) & "." & To_String (P.T_Name) & ";");
         end if;

         --  Generate conversion spec

         Text_IO.New_Line (Rec_Ads);
         Text_IO.Put_Line (Rec_Ads, "   function To_" & F_Name);
         Text_IO.Put_Line (Rec_Ads, "     (O : SOAP.Types.Object'Class)");
         Text_IO.Put_Line (Rec_Ads, "      return " & F_Name & ';');

         Text_IO.New_Line (Tmp_Ads);
         Text_IO.Put_Line (Tmp_Ads, "   function To_" & F_Name);
         Text_IO.Put_Line (Tmp_Ads, "     (O : SOAP.Types.Object'Class)");
         Text_IO.Put_Line (Tmp_Ads, "      return " & F_Name);
         Text_IO.Put_Line
           (Tmp_Ads, "      renames "
            & To_Unit_Name (To_String (Prefix)) & ".To_" & F_Name & ';');

         Text_IO.New_Line (Rec_Ads);
         Text_IO.Put_Line (Rec_Ads, "   function To_SOAP_Object");
         Text_IO.Put_Line (Rec_Ads, "     (R    : " & F_Name & ';');
         Text_IO.Put_Line (Rec_Ads, "      Name : String := ""item"")");
         Text_IO.Put_Line (Rec_Ads, "      return SOAP.Types.SOAP_Record;");

         Text_IO.New_Line (Tmp_Ads);
         Text_IO.Put_Line (Tmp_Ads, "   function To_SOAP_Object");
         Text_IO.Put_Line (Tmp_Ads, "     (R    : " & F_Name & ';');
         Text_IO.Put_Line (Tmp_Ads, "      Name : String := ""item"")");
         Text_IO.Put_Line (Tmp_Ads, "      return SOAP.Types.SOAP_Record");
         Text_IO.Put_Line
           (Tmp_Ads, "      renames "
            & To_Unit_Name (To_String (Prefix)) & ".To_SOAP_Object;");

         --  Generate conversion body

         Header_Box (O, Rec_Adb, "Record " & F_Name);

         --  SOAP to Ada

         Text_IO.New_Line (Rec_Adb);
         Text_IO.Put_Line (Rec_Adb, "   function To_" & F_Name);
         Text_IO.Put_Line (Rec_Adb, "     (O : SOAP.Types.Object'Class)");
         Text_IO.Put_Line (Rec_Adb, "      return " & F_Name);
         Text_IO.Put_Line (Rec_Adb, "   is");

         --  Declare the SOAP record object

         Text_IO.Put_Line
           (Rec_Adb,
            "      R : constant SOAP.Types.SOAP_Record "
              & ":= SOAP.Types.SOAP_Record (O);");

         --  Declare all record's fields

         N := R;

         while N /= null loop
            Text_IO.Put_Line
              (Rec_Adb,
               "      " & Format_Name (O, To_String (N.Name))
               & " : constant SOAP.Types.Object'Class"
               & " := SOAP.Types.V (R, """
               & To_String (N.Name) & """);");

            N := N.Next;
         end loop;

         Text_IO.Put_Line (Rec_Adb, "   begin");
         Text_IO.Put      (Rec_Adb, "      return (");

         --  Aggregate to build the record object

         N := R;

         if N.Next = null then
            --  We have a single element into this record, we must use a named
            --  notation for the aggregate.
            Text_IO.Put (Rec_Adb, To_String (N.Name) & " => ");
         end if;

         while N /= null loop

            if N /= R then
               Text_IO.Put      (Rec_Adb, "              ");
            end if;

            case N.Mode is
               when WSDL.Parameters.K_Simple =>
                  declare
                     I_Type : constant String := WSDL.Set_Type (N.P_Type);
                  begin
                     Text_IO.Put
                       (Rec_Adb,
                        WSDL.V_Routine (N.P_Type, WSDL.Component)
                        & " (" & I_Type & " ("
                        & Format_Name (O, To_String (N.Name)) & "))");
                  end;

               when WSDL.Parameters.K_Derived =>
                  declare
                     I_Type : constant String := WSDL.Set_Type (N.Parent_Type);
                  begin
                     Text_IO.Put
                       (Rec_Adb,
                        To_String (N.D_Name) & "_Type ("
                        & WSDL.V_Routine (N.Parent_Type, WSDL.Component)
                        & " (" & I_Type & " ("
                        & Format_Name (O, To_String (N.Name)) & ")))");
                  end;

               when WSDL.Parameters.K_Enumeration =>
                  Text_IO.Put
                    (Rec_Adb,
                     To_String (N.E_Name) & "_Type'Value ("
                       & "SOAP.Types.V (SOAP.Types.SOAP_Enumeration ("
                       & Format_Name (O, To_String (N.Name)) & ")))");

               when WSDL.Parameters.K_Array =>
                  Text_IO.Put
                    (Rec_Adb, "+To_" & Format_Name (O, To_String (N.T_Name))
                       & "_Type (SOAP.Types.V (SOAP.Types.SOAP_Array ("
                       & Format_Name (O, To_String (N.Name)) & ")))");

               when WSDL.Parameters.K_Record =>
                  Text_IO.Put (Rec_Adb, Get_Routine (N));

                  Text_IO.Put
                    (Rec_Adb,
                     " (SOAP.Types.SOAP_Record ("
                     & Format_Name (O, To_String (N.Name)) & "))");
            end case;

            if N.Next = null then
               Text_IO.Put_Line (Rec_Adb, ");");
            else
               Text_IO.Put_Line (Rec_Adb, ",");
            end if;

            N := N.Next;
         end loop;

         --  Generate exception handler

         N := R;

         if N /= null then
            declare
               procedure Emit_Check (F_Name, I_Type : String);
               --  Emit a check for F_Name'Tag = I_Type'Tag

               ----------------
               -- Emit_Check --
               ----------------

               procedure Emit_Check (F_Name, I_Type : String) is
               begin
                  Text_IO.Put_Line
                    (Rec_Adb,
                     "         if " & F_Name & "'Tag /= "
                     & I_Type & "'Tag then");
                  Text_IO.Put_Line
                    (Rec_Adb, "            raise SOAP.SOAP_Error");
                  Text_IO.Put_Line
                    (Rec_Adb, "               with SOAP.Types.Name (R)");
                  Text_IO.Put_Line
                    (Rec_Adb, "                  & ""."
                     & F_Name & " expected "
                     & I_Type & ", """);
                  Text_IO.Put_Line
                    (Rec_Adb, "                  & ""found "" & External_Tag ("
                     & F_Name & "'Tag);");
                  Text_IO.Put_Line
                    (Rec_Adb, "         end if;");
               end Emit_Check;

            begin
               Text_IO.Put_Line (Rec_Adb, "   exception");
               Text_IO.Put_Line (Rec_Adb, "      when Constraint_Error =>");

               while N /= null loop
                  case N.Mode is
                     when WSDL.Parameters.K_Simple =>
                        Emit_Check
                          (Format_Name (O, To_String (N.Name)),
                           WSDL.Set_Type (N.P_Type));

                     when WSDL.Parameters.K_Derived =>
                        Emit_Check
                          (Format_Name (O, To_String (N.Name)),
                           WSDL.Set_Type (N.Parent_Type));

                     when WSDL.Parameters.K_Enumeration =>
                        Emit_Check
                          (Format_Name (O, To_String (N.Name)),
                           "SOAP.Types.SOAP_Enumeration");

                     when WSDL.Parameters.K_Array =>
                        Emit_Check
                          (Format_Name (O, To_String (N.Name)),
                           "SOAP.Types.SOAP_Array");

                     when WSDL.Parameters.K_Record =>
                        Emit_Check
                          (Format_Name (O, To_String (N.Name)),
                           "SOAP.Types.SOAP_Record");
                  end case;

                  N := N.Next;
               end loop;
            end;

            Text_IO.Put_Line
              (Rec_Adb,
               "         raise SOAP.SOAP_Error");
            Text_IO.Put_Line
              (Rec_Adb,
               "            with ""Record "" & SOAP.Types.Name (R) &"
               & " "" not well formed."";");
         end if;

         Text_IO.Put_Line (Rec_Adb, "   end To_" & F_Name & ';');

         --  To_SOAP_Object

         Text_IO.New_Line (Rec_Adb);
         Text_IO.Put_Line (Rec_Adb, "   function To_SOAP_Object");

         Text_IO.Put_Line (Rec_Adb, "     (R    : " & F_Name & ';');
         Text_IO.Put_Line (Rec_Adb, "      Name : String := ""item"")");
         Text_IO.Put_Line (Rec_Adb, "      return SOAP.Types.SOAP_Record");
         Text_IO.Put_Line (Rec_Adb, "   is");
         Text_IO.Put_Line (Rec_Adb, "      Result : SOAP.Types.SOAP_Record;");
         Text_IO.Put_Line (Rec_Adb, "   begin");

         N := R;

         Text_IO.Put_Line (Rec_Adb, "      Result := SOAP.Types.R");

         while N /= null loop

            if N = R then

               if R.Next = null then
                  --  We have a single element into this record, we must use a
                  --  named notation for the aggregate.
                  Text_IO.Put (Rec_Adb, "        ((1 => +");
               else
                  Text_IO.Put (Rec_Adb, "        ((+");
               end if;

            else
               Text_IO.Put      (Rec_Adb, "          +");
            end if;

            case N.Mode is
               when WSDL.Parameters.K_Simple =>
                  Text_IO.Put (Rec_Adb, Set_Routine (N));

                  Text_IO.Put
                    (Rec_Adb,
                     " (R." & Format_Name (O, To_String (N.Name))
                       & ", """ & To_String (N.Name) & """)");

               when WSDL.Parameters.K_Derived =>
                  Text_IO.Put (Rec_Adb, Set_Routine (N));

                  Text_IO.Put
                    (Rec_Adb,
                     " (" & WSDL.To_Ada (N.Parent_Type)
                       & " (R." & Format_Name (O, To_String (N.Name))
                       & "), """ & To_String (N.Name) & """)");

               when WSDL.Parameters.K_Enumeration =>
                  Text_IO.Put
                    (Rec_Adb,
                     " SOAP.Types.E (Image"
                       & " (R." & Format_Name (O, To_String (N.Name))
                       & "), """ & To_String (N.E_Name)
                       & """, """ & To_String (N.Name) & """)");

               when WSDL.Parameters.K_Array =>
                  Text_IO.Put
                    (Rec_Adb,
                     "SOAP.Types.A (To_Object_Set (R."
                       & Format_Name (O, To_String (N.Name))
                       & ".Item.all), """ & To_String (N.Name) & """)");

               when WSDL.Parameters.K_Record =>
                  Text_IO.Put (Rec_Adb, Set_Routine (N));

                  Text_IO.Put
                    (Rec_Adb,
                     " (R." & Format_Name (O, To_String (N.Name))
                       & ", """ & To_String (N.Name) & """)");
            end case;

            if N.Next = null then
               Text_IO.Put_Line (Rec_Adb, "),");
            else
               Text_IO.Put_Line (Rec_Adb, ",");
            end if;

            N := N.Next;
         end loop;

         if P.Mode = WSDL.Parameters.K_Simple then
            --  This is an unnamed record (output described as a set of part)

            Text_IO.Put_Line (Rec_Adb, "         Name);");

         else
            Text_IO.Put_Line
              (Rec_Adb,
               "         Name, """ & To_String (P.T_Name) & """);");
         end if;

         if P.NS /= Name_Space.No_Name_Space then
            Text_IO.Put_Line
              (Rec_Adb, "      SOAP.Types.Set_Name_Space");
            Text_IO.Put_Line
              (Rec_Adb, "        (Result,");
            Text_IO.Put_Line
              (Rec_Adb, "         SOAP.Name_Space.Create");
            Text_IO.Put_Line
              (Rec_Adb, "           (""" & Name_Space.Name (P.NS) & """,");
            Text_IO.Put_Line
              (Rec_Adb, "            """ & Name_Space.Value (P.NS) & """));");
         end if;

         Text_IO.Put_Line (Rec_Adb, "      return Result;");
         Text_IO.Put_Line (Rec_Adb, "   end To_SOAP_Object;");

         Finalize_Types_Package (Prefix, Rec_Ads, Rec_Adb);
      end Generate_Record;

      -------------------------
      -- Generate_References --
      -------------------------

      procedure Generate_References
        (File : Text_IO.File_Type;
         P    : WSDL.Parameters.P_Set)
      is
         use type Name_Space.Object;
         N : WSDL.Parameters.P_Set := P;
      begin
         while N /= null loop
            if N.NS /= Name_Space.No_Name_Space then
               declare
                  F_Name : constant String
                    := Format_Name (O, SOAP.WSDL.Parameters.Type_Name (N));
                  Prefix : constant String := Generate_Namespace (N.NS, False);
               begin
                  With_Unit
                    (File,
                     To_Unit_Name (Prefix) & '.' & F_Name & "_Type_Pkg",
                     Elab      => Off,
                     Use_Clause => True);
               end;
            end if;
            N := N.Next;
         end loop;

         Text_IO.New_Line (File);
      end Generate_References;

      -----------------
      -- Get_Routine --
      -----------------

      function Get_Routine (P : WSDL.Parameters.P_Set) return String is
      begin
         case P.Mode is
            when WSDL.Parameters.K_Simple =>
               return WSDL.Get_Routine (P.P_Type);

            when WSDL.Parameters.K_Derived =>
               return WSDL.Get_Routine (P.Parent_Type);

            when WSDL.Parameters.K_Enumeration =>
               return WSDL.Get_Routine (WSDL.P_String);

            when WSDL.Parameters.K_Array =>
               declare
                  T_Name : constant String := To_String (P.E_Type);
               begin
                  if WSDL.Is_Standard (T_Name) then
                     return WSDL.Get_Routine
                       (WSDL.To_Type (T_Name), WSDL.Component);
                  else
                     return "To_" & Format_Name (O, T_Name) & "_Type";
                  end if;
               end;

            when WSDL.Parameters.K_Record =>
               return "To_" & Type_Name (P);
         end case;
      end Get_Routine;

      ------------------------------
      -- Initialize_Types_Package --
      ------------------------------

      procedure Initialize_Types_Package
        (P            : WSDL.Parameters.P_Set;
         Name         : String;
         Output       : Boolean;
         Prefix       : out Unbounded_String;
         F_Ads, F_Adb : out Text_IO.File_Type;
         Regen        : Boolean := False)
      is
         use WSDL.Parameters;
         F_Name : constant String := Name & "_Pkg";
      begin
         Prefix := To_Unbounded_String
           (Generate_Namespace (P.NS, True) & '-' & F_Name);

         --  Add references into the main types package

         if not Regen then
            With_Unit
              (Type_Ads,
               To_Unit_Name (To_String (Prefix)),
               Use_Clause => True);
            Text_IO.New_Line (Type_Ads);
         end if;

         Text_IO.Create
           (F_Ads, Text_IO.Out_File, To_Lower (To_String (Prefix)) & ".ads");

         Text_IO.Create
           (F_Adb, Text_IO.Out_File, To_Lower (To_String (Prefix)) & ".adb");

         Put_File_Header (O, F_Ads);

         if P.Mode in Compound_Type then
            if Output then
               Generate_References (F_Ads, P);
            else
               Generate_References (F_Ads, P.P);
            end if;
         end if;

         Put_Types_Header_Spec (O, F_Ads, To_Unit_Name (To_String (Prefix)));

         Put_File_Header (O, F_Adb);
         Put_Types_Header_Body (O, F_Adb, To_Unit_Name (To_String (Prefix)));
      end Initialize_Types_Package;

      ----------------------
      -- Is_Inside_Record --
      ----------------------

      function Is_Inside_Record (Name : String) return Boolean is
         In_Record : Boolean := False;

         procedure Check_Record
           (P_Set : WSDL.Parameters.P_Set;
            Mode  : out Boolean);
         --  Checks all record fields for Name

         procedure Check_Parameters
           (P_Set : WSDL.Parameters.P_Set);
         --  Checks P_Set for Name declared inside a record

         ----------------------
         -- Check_Parameters --
         ----------------------

         procedure Check_Parameters
           (P_Set : WSDL.Parameters.P_Set)
         is
            P : WSDL.Parameters.P_Set := P_Set;
         begin
            while P /= null loop
               if P.Mode = WSDL.Parameters.K_Record then
                  Check_Record (P.P, In_Record);
               end if;

               P := P.Next;
            end loop;
         end Check_Parameters;

         ------------------
         -- Check_Record --
         ------------------

         procedure Check_Record
           (P_Set : WSDL.Parameters.P_Set;
            Mode  : out Boolean)
         is
            P : WSDL.Parameters.P_Set := P_Set;
         begin
            Mode := False;

            while P /= null loop
               if P.Mode = WSDL.Parameters.K_Array
                 and then To_String (P.T_Name) = Name
               then
                  Mode := True;
               end if;

               if P.Mode = WSDL.Parameters.K_Record then
                  Check_Record (P.P, Mode);
               end if;

               P := P.Next;
            end loop;
         end Check_Record;

      begin
         Check_Parameters (Input);
         Check_Parameters (Output);

         return In_Record;
      end Is_Inside_Record;

      ------------------
      -- Output_Types --
      ------------------

      procedure Output_Types (P : WSDL.Parameters.P_Set) is
         N : WSDL.Parameters.P_Set := P;
      begin
         while N /= null loop
            case N.Mode is
               when WSDL.Parameters.K_Simple =>
                  null;

               when WSDL.Parameters.K_Derived =>
                  declare
                     Name : constant String := To_String (N.D_Name);
                  begin
                     if not Name_Set.Exists (Name) then

                        Name_Set.Add (Name);

                        Generate_Derived (Name & "_Type", N);
                     end if;
                  end;

               when WSDL.Parameters.K_Enumeration =>
                  declare
                     Name : constant String := To_String (N.E_Name);
                  begin
                     if not Name_Set.Exists (Name) then

                        Name_Set.Add (Name);

                        Generate_Enumeration (Name & "_Type", N);
                     end if;
                  end;

               when WSDL.Parameters.K_Array =>

                  Output_Types (N.P);

                  declare
                     Name  : constant String := To_String (N.T_Name);
                     Regen : Boolean;
                  begin
                     if not Name_Set.Exists (Name)
                       or else Is_Inside_Record (Name)
                     then
                        if Name_Set.Exists (Name)
                          and then Is_Inside_Record (Name)
                        then
                           --  We force the regeneration of the array
                           --  definition when it is inside a record to be sure
                           --  that we have a safe access generated.
                           Regen := True;
                        else
                           Regen := False;
                           Name_Set.Add (Name);
                        end if;

                        Generate_Array (Name & "_Type", N, Regen);
                     end if;
                  end;

               when WSDL.Parameters.K_Record =>

                  Output_Types (N.P);

                  declare
                     Name : constant String := To_String (N.T_Name);
                  begin
                     if not Name_Set.Exists (Name) then

                        Name_Set.Add (Name);

                        Generate_Record (Name & "_Type", N);
                     end if;
                  end;
            end case;

            N := N.Next;
         end loop;
      end Output_Types;

      -----------------
      -- Set_Routine --
      -----------------

      function Set_Routine (P : WSDL.Parameters.P_Set) return String is
      begin
         case P.Mode is
            when WSDL.Parameters.K_Simple =>
               return WSDL.Set_Routine (P.P_Type, Context => WSDL.Component);

            when WSDL.Parameters.K_Derived =>
               return WSDL.Set_Routine
                 (P.Parent_Type, Context => WSDL.Component);

            when WSDL.Parameters.K_Enumeration =>
               return WSDL.Set_Routine
                 (WSDL.P_String, Context => WSDL.Component);

            when WSDL.Parameters.K_Array =>
               declare
                  T_Name : constant String := To_String (P.E_Type);
               begin
                  if WSDL.Is_Standard (T_Name) then
                     return WSDL.Set_Routine
                       (WSDL.To_Type (T_Name), Context => WSDL.Component);
                  else
                     return "To_SOAP_Object";
                  end if;
               end;

            when WSDL.Parameters.K_Record =>
               return "To_SOAP_Object";
         end case;
      end Set_Routine;

      --------------
      -- Set_Type --
      --------------

      function Set_Type (Name : String) return String is
      begin
         if WSDL.Is_Standard (Name) then
            return WSDL.Set_Type (WSDL.To_Type (Name));
         else
            return "SOAP.Types.SOAP_Record";
         end if;
      end Set_Type;

      ---------------
      -- Type_Name --
      ---------------

      function Type_Name (N : WSDL.Parameters.P_Set) return String is
         use type WSDL.Parameter_Type;
      begin
         case N.Mode is
            when WSDL.Parameters.K_Simple =>
               --  This routine is called only for SOAP object in records
               --  or arrays.
               return WSDL.To_Ada (N.P_Type, Context => WSDL.Component);

            when WSDL.Parameters.K_Derived =>
               return Format_Name (O, To_String (N.D_Name)) & "_Type";

            when WSDL.Parameters.K_Enumeration =>
               return Format_Name (O, To_String (N.E_Name)) & "_Type";

            when WSDL.Parameters.K_Array =>
               return Format_Name (O, To_String (N.T_Name))
                 & "_Type_Safe_Access";

            when WSDL.Parameters.K_Record =>
               return Format_Name (O, To_String (N.T_Name)) & "_Type";
         end case;
      end Type_Name;

      L_Proc : constant String := Format_Name (O, Proc);

   begin
      Output_Types (Input);

      Output_Types (Output);

      if Output /= null then
         --  Something in the SOAP procedure output

         if Output.Next = null then
            --  A single parameter

            case Output.Mode is

               when WSDL.Parameters.K_Simple =>
                  null;

               when WSDL.Parameters.K_Derived =>
                  --  A single declaration, this is a derived type create a
                  --  subtype.

                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads,
                     "   subtype " & L_Proc & "_Result is "
                       & Format_Name (O, To_String (Output.D_Name))
                       & "_Type;");

               when WSDL.Parameters.K_Enumeration =>
                  --  A single declaration, this is an enumeration type create
                  --  a subtype.

                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads,
                     "   subtype " & L_Proc & "_Result is "
                       & Format_Name (O, To_String (Output.E_Name))
                       & "_Type;");

               when WSDL.Parameters.K_Record | WSDL.Parameters.K_Array =>
                  --  A single declaration, this is a composite type create
                  --  a subtype.

                  Text_IO.New_Line (Tmp_Ads);
                  Text_IO.Put_Line
                    (Tmp_Ads,
                     "   subtype " & L_Proc & "_Result is "
                       & Format_Name (O, To_String (Output.T_Name))
                       & "_Type;");
            end case;

         else
            --  Multiple parameters in the output, generate a record in this
            --  case.

            Generate_Record (L_Proc & "_Result", Output, Output => True);
         end if;
      end if;
   end Put_Types;

   ---------------------------
   -- Put_Types_Header_Body --
   ---------------------------

   procedure Put_Types_Header_Body
     (O : Object; File : Text_IO.File_Type; Unit_Name : String)
   is
      pragma Unreferenced (O);
   begin
      With_Unit (File, "Ada.Tags", Elab => Off);
      Text_IO.New_Line (File);

      With_Unit (File, "SOAP.Name_Space", Elab => Children);
      Text_IO.New_Line (File);

      Text_IO.Put_Line
        (File, "package body " & Unit_Name & " is");
      Text_IO.New_Line (File);
      Text_IO.Put_Line
        (File, "   pragma Warnings (Off, SOAP.Name_Space);");
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "   use Ada.Tags;");
      Text_IO.Put_Line (File, "   use SOAP.Types;");
      Text_IO.New_Line (File);
   end Put_Types_Header_Body;

   ---------------------------
   -- Put_Types_Header_Spec --
   ---------------------------

   procedure Put_Types_Header_Spec
     (O : Object; File : Text_IO.File_Type; Unit_Name : String) is
   begin
      With_Unit (File, "Ada.Calendar", Elab => Off);
      With_Unit (File, "Ada.Strings.Unbounded", Elab => Off);
      Text_IO.New_Line (File);
      With_Unit (File, "SOAP.Types", Elab => Children);
      With_Unit (File, "SOAP.Utils");
      Text_IO.New_Line (File);

      if Types_Spec (O) /= "" then
         With_Unit (File, Types_Spec (O));
         Text_IO.New_Line (File);
      end if;

      if Procs_Spec (O) /= "" and then Procs_Spec (O) /= Types_Spec (O) then
         With_Unit (File, Procs_Spec (O));
         Text_IO.New_Line (File);
      end if;

      Text_IO.Put_Line
        (File, "package " & Unit_Name & " is");
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "   pragma Warnings (Off, Ada.Calendar);");
      Text_IO.Put_Line
        (File, "   pragma Warnings (Off, Ada.Strings.Unbounded);");
      Text_IO.Put_Line (File, "   pragma Warnings (Off, SOAP.Types);");
      Text_IO.Put_Line (File, "   pragma Warnings (Off, SOAP.Utils);");

      if Types_Spec (O) /= "" then
         Text_IO.Put_Line
           (File,
            "   pragma Warnings (Off, " & Types_Spec (O) & ");");
         Text_IO.New_Line (File);
      end if;

      if Procs_Spec (O) /= "" and then Procs_Spec (O) /= Types_Spec (O) then
         Text_IO.Put_Line
           (File,
            "   pragma Warnings (Off, " & Procs_Spec (O) & ");");
         Text_IO.New_Line (File);
      end if;

      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "   pragma Style_Checks (Off);");
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "   use Ada.Strings.Unbounded;");
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "   function ""+""");
      Text_IO.Put_Line (File, "     (Str : String)");
      Text_IO.Put_Line (File, "      return Unbounded_String");
      Text_IO.Put_Line (File, "      renames To_Unbounded_String;");
   end Put_Types_Header_Spec;

   -----------
   -- Quiet --
   -----------

   procedure Quiet (O : in out Object) is
   begin
      O.Quiet := True;
   end Quiet;

   -----------------
   -- Result_Type --
   -----------------

   function Result_Type
     (O      : Object;
      Proc   : String;
      Output : WSDL.Parameters.P_Set) return String
   is
      use type WSDL.Parameters.Kind;

      L_Proc : constant String := Format_Name (O, Proc);
   begin
      if WSDL.Parameters.Length (Output) = 1
        and then Output.Mode = WSDL.Parameters.K_Simple
      then
         return WSDL.To_Ada (Output.P_Type);
      else
         return L_Proc & "_Result";
      end if;
   end Result_Type;

   ---------------
   -- Set_Proxy --
   ---------------

   procedure Set_Proxy
     (O : in out Object; Proxy, User, Password : String) is
   begin
      O.Proxy  := To_Unbounded_String (Proxy);
      O.P_User := To_Unbounded_String (User);
      O.P_Pwd  := To_Unbounded_String (Password);
   end Set_Proxy;

   ------------------
   -- Set_Timeouts --
   ------------------

   procedure Set_Timeouts
     (O        : in out Object;
      Timeouts : Client.Timeouts_Values) is
   begin
      O.Timeouts := Timeouts;
   end Set_Timeouts;

   ----------
   -- Skel --
   ----------

   package body Skel is separate;

   ----------------
   -- Specs_From --
   ----------------

   procedure Specs_From (O : in out Object; Spec : String) is
   begin
      O.Spec := To_Unbounded_String (Spec);
   end Specs_From;

   -------------------
   -- Start_Service --
   -------------------

   overriding procedure Start_Service
     (O             : in out Object;
      Name          : String;
      Documentation : String;
      Location      : String)
   is
      use type Client.Timeouts_Values;

      U_Name : constant String := To_Unit_Name (Format_Name (O, Name));

      procedure Create (File : in out Text_IO.File_Type; Filename : String);
      --  Create Filename, raise execption Generator_Error if the file already
      --  exists and overwrite mode not activated.

      procedure Generate_Main (Filename : String);
      --  Generate the main server's procedure. Either the file exists and is
      --  a template use it to generate the main otherwise just generate a
      --  standard main procedure.

      function Timeout_Image (Timeout : Duration) return String;

      ------------
      -- Create --
      ------------

      procedure Create
        (File     : in out Text_IO.File_Type;
         Filename : String) is
      begin
         if AWS.Utils.Is_Regular_File (Filename) and then not O.Force then
            raise Generator_Error
              with "File " & Filename & " exists, activate overwrite mode.";
         else
            Text_IO.Create (File, Text_IO.Out_File, Filename);
         end if;
      end Create;

      -------------------
      -- Generate_Main --
      -------------------

      procedure Generate_Main (Filename : String) is
         use Text_IO;

         L_Filename        : constant String :=
                               Characters.Handling.To_Lower (Filename);
         Template_Filename : constant String := L_Filename & ".amt";

         File : Text_IO.File_Type;

      begin
         Create (File, L_Filename & ".adb");

         Put_File_Header (O, File);

         if AWS.Utils.Is_Regular_File (Template_Filename) then
            --  Use template file
            declare
               Translations : constant Templates.Translate_Table :=
                                (1 => Templates.Assoc
                                   ("SOAP_SERVICE", U_Name),
                                 2 => Templates.Assoc
                                   ("SOAP_VERSION", SOAP.Version),
                                 3 => Templates.Assoc
                                   ("AWS_VERSION",  AWS.Version),
                                 4 => Templates.Assoc
                                   ("UNIT_NAME", To_Unit_Name (Filename)));
            begin
               Put (File, Templates.Parse (Template_Filename, Translations));
            end;

         else
            --  Generate a minimal main for the server
            With_Unit (File, "AWS.Config.Set");
            With_Unit (File, "AWS.Server");
            With_Unit (File, "AWS.Status");
            With_Unit (File, "AWS.Response");
            With_Unit (File, "SOAP.Dispatchers.Callback");
            New_Line (File);
            With_Unit (File, U_Name & ".CB");
            With_Unit (File, U_Name & ".Server");
            New_Line (File);
            Put_Line (File, "procedure " & To_Unit_Name (Filename) & " is");
            New_Line (File);
            Put_Line (File, "   use AWS;");
            New_Line (File);
            Put_Line (File, "   function CB ");
            Put_Line (File, "      (Request : Status.Data)");
            Put_Line (File, "       return Response.Data");
            Put_Line (File, "   is");
            Put_Line (File, "      R : Response.Data;");
            Put_Line (File, "   begin");
            Put_Line (File, "      return R;");
            Put_Line (File, "   end CB;");
            New_Line (File);
            Put_Line (File, "   WS   : AWS.Server.HTTP;");
            Put_Line (File, "   Conf : Config.Object;");
            Put_Line (File, "   Disp : " & U_Name & ".CB.Handler;");
            New_Line (File);
            Put_Line (File, "begin");
            Put_Line (File, "   Config.Set.Server_Port");
            Put_Line (File, "      (Conf, " & U_Name & ".Server.Port);");
            Put_Line (File, "   Disp := SOAP.Dispatchers.Callback.Create");
            Put_Line (File, "     (CB'Unrestricted_Access,");
            Put_Line (File, "      " & U_Name & ".CB.SOAP_CB'Access);");
            New_Line (File);
            Put_Line (File, "   AWS.Server.Start (WS, Disp, Conf);");
            New_Line (File);
            Put_Line (File, "   AWS.Server.Wait (AWS.Server.Forever);");
            Put_Line (File, "end " & To_Unit_Name (Filename) & ";");
         end if;

         Text_IO.Close (File);
      end Generate_Main;

      -------------------
      -- Timeout_Image --
      -------------------

      function Timeout_Image (Timeout : Duration) return String is
      begin
         if Timeout = Duration'Last then
            return "Duration'Last";
         else
            return AWS.Utils.Significant_Image (Timeout, 3);
         end if;
      end Timeout_Image;

      LL_Name : constant String :=
                  Characters.Handling.To_Lower (Format_Name (O, Name));

   begin
      O.Location := To_Unbounded_String (Location);

      if not O.Quiet then
         Text_IO.New_Line;
         Text_IO.Put_Line ("Service " & Name);
         Text_IO.Put_Line ("   " & Documentation);
      end if;

      Create (Root, LL_Name & ".ads");

      Create (Type_Ads, LL_Name & "-types.ads");
      Text_IO.Create (Tmp_Ads, Text_IO.Out_File);

      if O.Gen_Stub then
         Create (Stub_Ads, LL_Name & "-client.ads");
         Create (Stub_Adb, LL_Name & "-client.adb");
      end if;

      if O.Gen_Skel then
         Create (Skel_Ads, LL_Name & "-server.ads");
         Create (Skel_Adb, LL_Name & "-server.adb");
      end if;

      if O.Gen_CB then
         Create (CB_Ads, LL_Name & "-cb.ads");
         Create (CB_Adb, LL_Name & "-cb.adb");
      end if;

      --  Types

      Put_File_Header (O, Type_Ads);
      Put_Types_Header_Spec (O, Tmp_Ads, U_Name & ".Types");

      --  Root

      Put_File_Header (O, Root);

      if Documentation /= "" then
         Text_IO.Put_Line (Root, "--  " & Documentation);
         Text_IO.New_Line (Root);
      end if;

      Text_IO.Put_Line (Root, "with AWS.Client;");
      Text_IO.New_Line (Root);

      Text_IO.Put_Line (Root, "package " & U_Name & " is");
      Text_IO.New_Line (Root);

      if O.Endpoint = Null_Unbounded_String then
         Text_IO.Put_Line
           (Root,
            "   URL      : constant String := """ & Location & """;");
      else
         Text_IO.Put_Line
           (Root,
            "   URL      : constant String := """
            & To_String (O.Endpoint) & """;");
      end if;

      Text_IO.Put_Line
        (Root,
         "   Timeouts : constant AWS.Client.Timeouts_Values :=");

      if O.Timeouts = Client.No_Timeout then
         Text_IO.Put_Line
           (Root, "                AWS.Client.No_Timeout;");

      else
         Text_IO.Put_Line
           (Root, "                AWS.Client.Timeouts");
         Text_IO.Put_Line
           (Root, "                  (Connect  => "
            & Timeout_Image (Client.Connect_Timeout (O.Timeouts)) & ',');
         Text_IO.Put_Line
           (Root, "                   Send     => "
            & Timeout_Image (Client.Send_Timeout (O.Timeouts)) & ',');
         Text_IO.Put_Line
           (Root, "                   Receive  => "
            & Timeout_Image (Client.Receive_Timeout (O.Timeouts)) & ',');
         Text_IO.Put_Line
           (Root, "                   Response => "
            & Timeout_Image (Client.Response_Timeout (O.Timeouts)) & ");");
      end if;

      if O.WSDL_File /= Null_Unbounded_String then
         Text_IO.New_Line (Root);
         Text_IO.Put_Line (Root, "   pragma Style_Checks (Off);");

         declare
            File   : Text_IO.File_Type;
            Buffer : String (1 .. 1_024);
            Last   : Natural;
         begin
            Text_IO.Open (File, Text_IO.In_File, To_String (O.WSDL_File));

            while not Text_IO.End_Of_File (File) loop
               Text_IO.Get_Line (File, Buffer, Last);
               Text_IO.Put_Line (Root, "--  " & Buffer (1 .. Last));
            end loop;

            Text_IO.Close (File);
         end;

         Text_IO.Put_Line (Root, "   pragma Style_Checks (On);");
         Text_IO.New_Line (Root);
      end if;

      O.Unit := To_Unbounded_String (U_Name);

      --  Stubs

      if O.Gen_Stub then
         Put_File_Header (O, Stub_Ads);
         Put_File_Header (O, Stub_Adb);
         Stub.Start_Service (O, Name, Documentation, Location);
      end if;

      --  Skeletons

      if O.Gen_Skel then
         Put_File_Header (O, Skel_Ads);
         Put_File_Header (O, Skel_Adb);
         Skel.Start_Service (O, Name, Documentation, Location);
      end if;

      --  Callbacks

      if O.Gen_CB then
         Put_File_Header (O, CB_Ads);
         Put_File_Header (O, CB_Adb);
         CB.Start_Service (O, Name, Documentation, Location);
      end if;

      --  Main

      if O.Main /= Null_Unbounded_String then
         Generate_Main (To_String (O.Main));
      end if;
   end Start_Service;

   ----------
   -- Stub --
   ----------

   package body Stub is separate;

   ----------------
   -- Time_Stamp --
   ----------------

   function Time_Stamp return String is
   begin
      return "--  This file was generated on "
        & GNAT.Calendar.Time_IO.Image
            (Ada.Calendar.Clock, "%A %d %B %Y at %T");
   end Time_Stamp;

   ------------------
   -- To_Unit_Name --
   ------------------

   function To_Unit_Name (Filename : String) return String is
   begin
      return Strings.Fixed.Translate
        (Filename, Strings.Maps.To_Mapping ("-", "."));
   end To_Unit_Name;

   ----------------
   -- Types_From --
   ----------------

   procedure Types_From (O : in out Object; Spec : String) is
   begin
      O.Types_Spec := To_Unbounded_String (To_Unit_Name (Spec));
   end Types_From;

   ----------------
   -- Types_Spec --
   ----------------

   function Types_Spec (O : Object) return String is
   begin
      if O.Types_Spec /= Null_Unbounded_String then
         return To_String (O.Types_Spec);
      elsif O.Spec /= Null_Unbounded_String then
         return To_String (O.Spec);
      else
         return "";
      end if;
   end Types_Spec;

   --------------------
   -- Version_String --
   --------------------

   function Version_String return String is
   begin
      return "--  AWS " & AWS.Version & " - SOAP " & SOAP.Version;
   end Version_String;

   ---------------
   -- With_Unit --
   ---------------

   procedure With_Unit
     (File       : Text_IO.File_Type;
      Name       : String;
      Elab       : Elab_Pragma := Single;
      Use_Clause : Boolean := False) is
   begin
      Text_IO.Put_Line (File, "with " & Name & ';');

      if Elab = Children then
         declare
            Index : Natural := Name'First;
         begin
            loop
               Index := Strings.Fixed.Index (Name (Index .. Name'Last), ".");
               exit when Index = 0;
               Text_IO.Put_Line
                 (File,
                  "pragma Elaborate_All (" & Name (Name'First .. Index - 1)
                  & ");");
               Index := Index + 1;
            end loop;
         end;
      end if;

      case Elab is
         when Off =>
            null;

         when Single | Children =>
            Text_IO.Put_Line (File, "pragma Elaborate_All (" & Name & ");");
      end case;

      if Use_Clause then
         Text_IO.Put_Line (File, "use " & Name & ';');
      end if;
   end With_Unit;

   ---------------
   -- WSDL_File --
   ---------------

   procedure WSDL_File (O : in out Object; Filename : String) is
   begin
      O.WSDL_File := To_Unbounded_String (Filename);
   end WSDL_File;

end SOAP.Generator;
