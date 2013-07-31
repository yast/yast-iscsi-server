# encoding: utf-8

# |***************************************************************************
# |
# | Copyright (c) [2012] Novell, Inc.
# | All Rights Reserved.
# |
# | This program is free software; you can redistribute it and/or
# | modify it under the terms of version 2 of the GNU General Public License as
# | published by the Free Software Foundation.
# |
# | This program is distributed in the hope that it will be useful,
# | but WITHOUT ANY WARRANTY; without even the implied warranty of
# | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# | GNU General Public License for more details.
# |
# | You should have received a copy of the GNU General Public License
# | along with this program; if not, contact Novell, Inc.
# |
# | To contact Novell about this file by physical or electronic mail,
# | you may find current contact information at www.novell.com
# |
# |***************************************************************************
# File:	clients/iscsi-server.ycp
# Package:	Configuration of iscsi-server
# Summary:	Main file
# Authors:	Michal Zugec <mzugec@suse.cz>
#
# $Id$
#
# Main file for iscsi-server configuration. Uses all other files.
module Yast
  module IscsiServerDialogsInclude
    def initialize_iscsi_server_dialogs(include_target)
      textdomain "iscsi-server"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "IscsiServer"
      Yast.import "CWMTab"
      Yast.import "CWM"
      Yast.import "CWMServiceStart"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "TablePopup"

      Yast.include include_target, "iscsi-server/helps.rb"
      Yast.include include_target, "iscsi-server/widgets.rb"

      # store current here
      @current_tab = "service"

      @tabs_descr = {
        # first tab - service status and firewall
        "service"        => {
          "header"       => _("Service"),
          "contents"     => VBox(
            VStretch(),
            HBox(
              HStretch(),
              HSpacing(1),
              VBox(
                "auto_start_up",
                VSpacing(1),
                "isns",
                VSpacing(1),
                "firewall",
                VSpacing(1),
                "save",
                VSpacing(1)
              ),
              HSpacing(1),
              HStretch()
            ),
            VStretch()
          ),
          "widget_names" => ["auto_start_up", "isns", "firewall", "save"]
        },
        # second tab - global authentication
        "global"         => {
          "header"       => _("Global"),
          "contents"     => VBox(
            VStretch(),
            HBox(
              HStretch(),
              HSpacing(1),
              VBox("global_config", VSpacing(2)),
              HSpacing(1),
              HStretch()
            ),
            VStretch()
          ),
          "widget_names" => ["global_config"]
        },
        # third tab - targets / luns
        "targets"        => {
          "header"       => _("Targets"),
          "contents"     => VBox(
            VStretch(),
            HBox(
              HStretch(),
              HSpacing(1),
              VBox("server_table", VSpacing(2)),
              HSpacing(1),
              HStretch()
            ),
            VStretch()
          ),
          "widget_names" => ["server_table"]
        },
        "target-details" => {
          "contents" => VBox(
            HBox(
              InputField(
                Id(:target),
                Opt(:hstretch),
                _("Target"),
                "iqn.2001-04.com.example"
              ),
              InputField(
                Id(:identifier),
                Opt(:hstretch),
                _("Identifier"),
                "test"
              )
            ),
            VBox(
              Table(Id(:lun_table), Header(_("LUN"), _("Value")), []),
              Left(
                HBox(
                  PushButton(Id(:add), _("Add")),
                  PushButton(Id(:edit), _("Edit")),
                  PushButton(Id(:delete), _("Delete"))
                )
              )
            ),
            Left(PushButton(Id(:expert), Opt(:disabled), _("Expert Settings")))
          )
        },
        "auth"           => {
          "contents" => VBox(
            Left(
              CheckBox(
                Id(:auth_none),
                Opt(:notify),
                _("No Authentication"),
                true
              )
            ),
            VSpacing(2),
            Left(
              CheckBox(
                Id(:auth_in),
                Opt(:notify),
                _("Incoming Authentication"),
                false
              )
            ),
            VBox(
              Table(
                Id(:incoming_table),
                Header(_("Username"), _("Password")),
                []
              ),
              Left(
                HBox(
                  PushButton(Id(:add), _("Add")),
                  PushButton(Id(:edit), _("Edit")),
                  PushButton(Id(:delete), _("Delete"))
                )
              )
            ),
            VSpacing(2),
            Left(
              CheckBox(
                Id(:auth_out),
                Opt(:notify),
                _("Outgoing Authentication"),
                false
              )
            ),
            HBox(
              InputField(Id(:user_out), Opt(:hstretch), _("Username")),
              Password(Id(:pass_out), _("Password"))
            )
          )
        }
      }



      @widgets = {
        "auto_start_up" => CWMServiceStart.CreateAutoStartWidget(
          {
            "get_service_auto_start" => fun_ref(
              IscsiServer.method(:GetStartService),
              "boolean ()"
            ),
            "set_service_auto_start" => fun_ref(
              IscsiServer.method(:SetStartService),
              "void (boolean)"
            ),
            # radio button (starting iscsitarget service - option 1)
            "start_auto_button"      => _(
              "When &Booting"
            ),
            # radio button (starting iscsitarget service - option 2)
            "start_manual_button"    => _(
              "&Manually"
            ),
            "help"                   => Builtins.sformat(
              CWMServiceStart.AutoStartHelpTemplate,
              # part of help text, used to describe radiobuttons (matching starting iscsitarget service but without "&")
              _("When Booting"),
              # part of help text, used to describe radiobuttons (matching starting iscsitarget service but without "&")
              _("Manually")
            )
          }
        ),
        # firewall
        "firewall"      => CWMFirewallInterfaces.CreateOpenFirewallWidget(
          { "services" => ["service:iscsitarget"], "display_details" => true }
        ),
        "save"          => {
          "widget" => :push_button,
          "label"  => Label.SaveButton,
          "handle" => fun_ref(
            method(:saveConfiguration),
            "symbol (string, map)"
          ),
          "opt"    => [],
          "help"   => Ops.get_string(@HELPS, "save_configuration", "")
        },
        "isns"          => {
          "widget"            => :custom,
          "custom_widget"     => HBox(
            CheckBoxFrame(
              Id(:isns_ac),
              _("iSNS Access Control"),
              true,
              VBox(InputField(Id(:isns_ip), Opt(:hstretch), _("iSNS Server")))
            )
          ),
          "init"              => fun_ref(method(:initiSNS), "void (string)"),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:validateiSNS),
            "boolean (string, map)"
          ),
          "store"             => fun_ref(
            method(:storeiSNS),
            "void (string, map)"
          )
        },
        # discovery authentication dialog
        "global_config" => {
          "widget"            => :custom,
          "custom_widget"     => Ops.get(@tabs_descr, ["auth", "contents"]),
          "init"              => fun_ref(method(:initGlobal), "void (string)"),
          "handle"            => fun_ref(
            method(:handleAuth),
            "symbol (string, map)"
          ),
          "store"             => fun_ref(
            method(:storeGlobal),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:validateGlobal),
            "boolean (string, map)"
          ),
          "help"              => Ops.get_string(@HELPS, "global_config", "")
        },
        # targets dialog
        "server_table"  => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            Table(Id(:server), Header(_("Targets")), []),
            Left(
              HBox(
                PushButton(Id(:add), _("Add")),
                PushButton(Id(:edit), _("Edit")),
                PushButton(Id(:delete), _("Delete"))
              )
            )
          ),
          "init"          => fun_ref(method(:initTable), "void (string)"),
          "handle"        => fun_ref(
            method(:handleTable),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "server_table", "")
        },
        # dialog for add new target
        "target-add"    => {
          "widget"            => :custom,
          "custom_widget"     => Ops.get(
            @tabs_descr,
            ["target-details", "contents"]
          ),
          "init"              => fun_ref(
            method(:initAddTarget),
            "void (string)"
          ),
          "store"             => fun_ref(
            method(:storeAddTarget),
            "void (string, map)"
          ),
          "handle"            => fun_ref(
            method(:handleModify),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:validateAddTarget),
            "boolean (string, map)"
          ),
          "help"              => Ops.get_string(@HELPS, "target-add", "")
        },
        # dialog for expert settings
        "expert"        => {
          "widget"        => :custom,
          "custom_widget" => VBox(
            VBox(
              Table(Id(:expert_table), Header(_("Key"), _("Value")), []),
              Left(
                HBox(
                  PushButton(Id(:add), _("Add")),
                  PushButton(Id(:edit), _("Edit")),
                  PushButton(Id(:delete), _("Delete"))
                )
              )
            )
          ),
          #        "init"   : initGlobal,
          #        "handle" : handleAuth,
          #        "store"  : storeGlobal,
          "help"          => Ops.get_string(
            @HELPS,
            "expert",
            ""
          )
        },
        # dialog for LUN details
        #      "lun-details" : $[
        #         "widget" : `custom,
        #         "custom_widget" : tabs_descr["lun-details", "contents"]:nil,
        # //        "init"   : initLUN,
        #         "handle" : handleLUN,
        #         "store"  : storeLUN,
        #         "help" : HELPS["lun-details"]:""
        #         ],
        # dialog for add/edit authentication for target
        "target-auth"   => {
          "widget"            => :custom,
          "custom_widget"     => Ops.get(@tabs_descr, ["auth", "contents"]),
          "init"              => fun_ref(method(:initGlobal), "void (string)"),
          "handle"            => fun_ref(
            method(:handleAuth),
            "symbol (string, map)"
          ),
          "store"             => fun_ref(
            method(:storeGlobal),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:validateGlobal),
            "boolean (string, map)"
          ),
          "help"              => Ops.get_string(@HELPS, "global_config", "")
        },
        # dialog for modifying target
        "target-modify" => {
          "widget"        => :custom,
          "custom_widget" => Ops.get(
            @tabs_descr,
            ["target-details", "contents"]
          ),
          "init"          => fun_ref(method(:initModify), "void (string)"),
          "handle"        => fun_ref(
            method(:handleModify),
            "symbol (string, map)"
          ),
          "store"         => fun_ref(method(:storeModify), "void (string, map)"),
          "help"          => Ops.get_string(@HELPS, "target-modify", "")
        }
      }
    end

    # Summary dialog
    # @return dialog result
    # Main dialog - tabbed
    def SummaryDialog
      caption = _("iSCSI Target Overview")
      @curr_target = ""
      widget_descr = {
        "tab" => CWMTab.CreateWidget(
          {
            "tab_order"    => ["service", "global", "targets"],
            "tabs"         => @tabs_descr,
            "widget_descr" => @widgets,
            "initial_tab"  => @current_tab,
            "tab_help"     => _("<h1>iSCSI Target</h1>")
          }
        )
      }
      contents = VBox("tab")
      w = CWM.CreateWidgets(
        ["tab"],
        Convert.convert(
          widget_descr,
          :from => "map",
          :to   => "map <string, map <string, any>>"
        )
      )
      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        Label.NextButton,
        Label.FinishButton
      )
      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.HideBackButton

      ret = CWM.Run(
        w,
        { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }
      )
      ret
    end

    # dialog for add target
    def AddDialog
      @current_tab = "targets"
      caption = _("Add iSCSI Target")
      w = CWM.CreateWidgets(["target-add"], @widgets)
      contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          HSpacing(1),
          VBox(Ops.get_term(w, [0, "widget"]) { VSpacing(1) }, VSpacing(2)),
          HSpacing(1),
          HStretch()
        ),
        VStretch()
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "target-add", ""),
        Label.BackButton,
        Label.NextButton
      )

      ret = CWM.Run(
        w,
        { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }
      )
      deep_copy(ret)
    end

    # discovery authentication dialog
    def AuthDialog
      @current_tab = "targets"
      caption = _("Modify iSCSI Target")
      w = CWM.CreateWidgets(["target-auth"], @widgets)
      contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          HSpacing(1),
          VBox(Ops.get_term(w, [0, "widget"]) { VSpacing(1) }, VSpacing(2)),
          HSpacing(1),
          HStretch()
        ),
        VStretch()
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "global_config", ""),
        Label.BackButton,
        Label.NextButton
      )

      ret = CWM.Run(
        w,
        { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }
      )
      deep_copy(ret)
    end

    # edit target dialog
    def EditDialog
      @current_tab = "targets"
      caption = _("Modify iSCSI Target")
      w = CWM.CreateWidgets(["target-modify"], @widgets)
      contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          HSpacing(1),
          VBox(Ops.get_term(w, [0, "widget"]) { VSpacing(1) }, VSpacing(2)),
          HSpacing(1),
          HStretch()
        ),
        VStretch()
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "target-modify", ""),
        Label.BackButton,
        Label.NextButton
      )

      ret = CWM.Run(
        w,
        { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }
      )
      deep_copy(ret)
    end

    # expert target dialog
    def ExpertDialog
      caption = _("iSCSI Target Expert Settings")
      w = CWM.CreateWidgets(["expert"], @widgets)
      contents = VBox(
        VStretch(),
        HBox(
          HStretch(),
          HSpacing(1),
          VBox(Ops.get_term(w, [0, "widget"]) { VSpacing(1) }, VSpacing(2)),
          HSpacing(1),
          HStretch()
        ),
        VStretch()
      )

      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "expert", ""),
        Label.BackButton,
        Label.NextButton
      )

      ret = CWM.Run(
        w,
        { :abort => fun_ref(method(:ReallyAbort), "boolean ()") }
      )
      deep_copy(ret)
    end
  end
end
