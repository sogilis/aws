############################################################################
#                              Ada Web Server                              #
#                                                                          #
#                      Copyright (C) 2007-2012, AdaCore                    #
#                                                                          #
#  This is free software;  you can redistribute it  and/or modify it       #
#  under terms of the  GNU General Public License as published  by the     #
#  Free Software  Foundation;  either version 3,  or (at your option) any  #
#  later version.  This software is distributed in the hope  that it will  #
#  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty #
#  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     #
#  General Public License for  more details.                               #
#                                                                          #
#  You should have  received  a copy of the GNU General  Public  License   #
#  distributed  with  this  software;   see  file COPYING3.  If not, go    #
#  to http://www.gnu.org/licenses for a complete copy of the license.      #
############################################################################

.SILENT:

DIRS = menu_css notebook rounded_boxes icons javascripts

setup:

build:

clean:

init:
	$(CP) readme.txt $(DESTDIR)$(I_WEL)
	$(CP) mime.types $(DESTDIR)$(I_WEL)

force:

$(DIRS): force
	$(MKDIR) $(DESTDIR)$(I_WEL)/$@
	$(CP) $@/*.* $(DESTDIR)$(I_WEL)/$@

install: init $(DIRS)
