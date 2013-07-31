# Sources for iscsi-server

module_DATA = \
  modules/IscsiServer.rb \
  modules/IscsiServerFunctions.pm

client_DATA = \
  clients/iscsi-server.rb \
  clients/iscsi-server_auto.rb \
  clients/iscsi-server_proposal.rb

yncludedir = @yncludedir@/iscsi-server
ynclude_DATA = \
  include/iscsi-server/widgets.rb \
  include/iscsi-server/wizards.rb \
  include/iscsi-server/dialogs.rb \
  include/iscsi-server/complex.rb \
  include/iscsi-server/helps.rb

scrconf_DATA = \
  scrconf/ietd.scr

desktop_DATA = \
  desktop/iscsi-server.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common