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
  module IscsiServerWidgetsInclude
    def initialize_iscsi_server_widgets(include_target)
      textdomain "iscsi-server"
      Yast.import "IscsiServerFunctions"
      Yast.import "Label"
      Yast.import "IP"
      #	**************** global funcions and variables *****
      @curr_target = ""
      @modify_record = ""
      @inc_auth = {}
    end

    def parseRow(value)
      ret = {}
      # if nothing only LUN
      return { "lun" => value } if Builtins.find(value, " ") == -1
      # extract Lun
      pos = Builtins.find(value, " ")
      Ops.set(ret, "lun", Builtins.substring(value, 0, pos))
      value = Builtins.substring(value, pos, Builtins.size(value))
      # extract Type
      pos = Builtins.find(value, "Type=")
      pos2 = Builtins.findfirstof(
        Builtins.substring(value, pos, Builtins.size(value)),
        " ,"
      )
      type = Builtins.substring(
        value,
        Ops.add(pos, Builtins.size("Type=")),
        pos2 != nil ?
          Ops.subtract(pos2, Builtins.size("Type=")) :
          Builtins.size(value)
      )
      if pos != -1
        if type == "fileio"
          Ops.set(ret, "fileio", true)
          Ops.set(ret, "nullio", false)
        else
          Ops.set(ret, "fileio", false)
          Ops.set(ret, "nullio", true)
        end
      end
      # extract Path
      pos = Builtins.find(value, "Path=")
      pos2 = Builtins.findfirstof(
        Builtins.substring(value, pos, Builtins.size(value)),
        " ,"
      )
      if pos != -1
        Ops.set(
          ret,
          "path",
          Builtins.substring(
            value,
            Ops.add(pos, Builtins.size("Path=")),
            pos2 != nil ?
              Ops.subtract(pos2, Builtins.size("Path=")) :
              Builtins.size(value)
          )
        )
      end
      #  extract ScsiId
      pos = Builtins.find(value, "ScsiId=")
      pos2 = Builtins.findfirstof(
        Builtins.substring(value, pos, Builtins.size(value)),
        " ,"
      )
      if pos != -1
        Ops.set(
          ret,
          "scsi_id",
          Builtins.substring(
            value,
            Ops.add(pos, Builtins.size("ScsiId=")),
            pos2 != nil ?
              Ops.subtract(pos2, Builtins.size("ScsiId=")) :
              Builtins.size(value)
          )
        )
      end
      #  extract ScsiId
      pos = Builtins.find(value, "Sectors=")
      pos2 = Builtins.findfirstof(
        Builtins.substring(value, pos, Builtins.size(value)),
        " ,"
      )
      if pos != -1
        Ops.set(
          ret,
          "sectors",
          Builtins.substring(
            value,
            Ops.add(pos, Builtins.size("Sectors=")),
            pos2 != nil ?
              Ops.subtract(pos2, Builtins.size("Sectors=")) :
              Builtins.size(value)
          )
        )
      end
      deep_copy(ret)
    end


    def LUNDetailDialog(values_before)
      values_before = deep_copy(values_before)
      previous = parseRow(Ops.get_string(values_before, "VALUE", ""))
      ret_map = {}
      lun_dialog = VBox(
        Left(
          HWeight(
            3,
            InputField(
              Id(:lun),
              Opt(:hstretch),
              "LUN",
              Ops.get_string(previous, "lun", "0")
            )
          )
        ),
        VSpacing(2),
        RadioButtonGroup(
          Id(:rb),
          VBox(
            Left(
              RadioButton(
                Id(:fileio),
                Opt(:notify),
                "Type=fileio",
                Ops.get_boolean(previous, "fileio", true)
              )
            ),
            HBox(
              InputField(
                Id(:file_path),
                Opt(:hstretch),
                _("Path:"),
                Ops.get_string(previous, "path", "")
              ),
              VBox(Label(""), PushButton(Id(:browse), _("Browse")))
            ),
            InputField(
              Id(:scsi_id),
              Opt(:hstretch),
              "ScsiId:",
              Ops.get_string(previous, "scsi_id", "")
            ),
            VSpacing(2),
            Left(
              RadioButton(
                Id(:nullio),
                Opt(:notify),
                "Type=nullio",
                Ops.get_boolean(previous, "nullio", false)
              )
            ),
            InputField(
              Id(:sectors),
              Opt(:hstretch),
              _("Sectors:"),
              Ops.get_string(previous, "sectors", "")
            )
          )
        ),
        Left(
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      UI.OpenDialog(lun_dialog)
      UI.ChangeWidget(Id(:lun), :ValidChars, "0123456789")
      ret = :nil
      while ret != :ok && ret != :cancel
        enable = false
        if Convert.to_boolean(UI.QueryWidget(:fileio, :Value)) == true
          enable = true
        end

        UI.ChangeWidget(:file_path, :Enabled, enable)
        UI.ChangeWidget(:browse, :Enabled, enable)
        UI.ChangeWidget(:scsi_id, :Enabled, enable)
        UI.ChangeWidget(:sectors, :Enabled, !enable)

        if ret == :browse
          file = UI.AskForExistingFile("/", "", _("Select file or device"))
          UI.ChangeWidget(:file_path, :Value, file) if file != nil
        end
        ret = Convert.to_symbol(UI.UserInput)
      end
      if ret == :cancel
        ret_map = {}
      else
        lun = Convert.to_string(UI.QueryWidget(:lun, :Value))
        value = lun
        if Convert.to_boolean(UI.QueryWidget(:fileio, :Value)) == true
          value = Builtins.sformat(
            "%1 Path=%2,Type=fileio",
            value,
            Convert.to_string(UI.QueryWidget(:file_path, :Value))
          )
          scsi_id = Convert.to_string(UI.QueryWidget(:scsi_id, :Value))
          if Ops.greater_than(Builtins.size(scsi_id), 0)
            value = Builtins.sformat("%1,ScsiId=%2", value, scsi_id)
          end
        else
          value = Builtins.sformat("%1 Type=nullio", value)
          sectors = Convert.to_string(UI.QueryWidget(:sectors, :Value))
          if Ops.greater_than(Builtins.size(sectors), 0)
            value = Builtins.sformat("%1,Sectors=%2", value, sectors)
          end
        end
        ret_map = { "KEY" => "Lun", "VALUE" => value }
      end
      UI.CloseDialog
      deep_copy(ret_map)
    end

    # set incoming authentication enabled/disabled status
    def setAuthIn(status)
      Builtins.y2milestone("Status of AuthIncoming %1", status)
      UI.ChangeWidget(Id(:incoming_table), :Enabled, status)
      UI.ChangeWidget(Id(:auth_in), :Value, status)

      UI.ChangeWidget(Id(:add), :Enabled, status)
      UI.ChangeWidget(Id(:edit), :Enabled, status)
      UI.ChangeWidget(Id(:delete), :Enabled, status)

      UI.ChangeWidget(Id(:auth_none), :Value, !status) if status

      nil
    end

    # set outgoing authentication enabled/disabled status
    def setAuthOut(status)
      Builtins.y2milestone("Status of AuthOutgoing %1", status)
      UI.ChangeWidget(Id(:user_out), :Enabled, status)
      UI.ChangeWidget(Id(:pass_out), :Enabled, status)
      UI.ChangeWidget(Id(:auth_out), :Value, status)
      UI.ChangeWidget(Id(:auth_none), :Value, !status) if status

      nil
    end

    # get values for incoming authentication
    def getIncomingValues
      values = []
      if Convert.to_boolean(UI.QueryWidget(Id(:auth_in), :Value)) == true
        count = -1
        while Ops.less_than(count, Ops.subtract(Builtins.size(@inc_auth), 1))
          count = Ops.add(count, 1)
          values = Builtins.add(
            values,
            Builtins.sformat(
              "%1 %2",
              Ops.get_string(@inc_auth, [count, "USER"], ""),
              Ops.get_string(@inc_auth, [count, "PASS"], "")
            )
          )
        end
        return deep_copy(values)
      else
        return []
      end
    end

    # get values for outgoing authentication
    def getOutgoingValues
      if Convert.to_boolean(UI.QueryWidget(Id(:auth_out), :Value)) == true
        values = Builtins.sformat(
          "%1 %2",
          UI.QueryWidget(Id(:user_out), :Value),
          UI.QueryWidget(Id(:pass_out), :Value)
        )
        return values
      else
        return ""
      end
    end

    # dialog to add/modify user and password
    def getDialogValues(user, pass)
      UI.OpenDialog(
        VBox(
          InputField(Id(:p_user), Opt(:hstretch), _("Username"), user),
          Password(Id(:p_pass), _("Password"), pass),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      cycle = true
      while cycle
        case Convert.to_symbol(UI.UserInput)
          when :ok
            user = Builtins.tostring(UI.QueryWidget(Id(:p_user), :Value))
            pass = Builtins.tostring(UI.QueryWidget(Id(:p_pass), :Value))
            UI.CloseDialog
            cycle = false
          when :cancel
            cycle = false
            UI.CloseDialog
        end
      end
      if Ops.greater_than(Builtins.size(user), 0) &&
          Ops.greater_than(Builtins.size(pass), 0)
        return [user, pass]
      else
        return []
      end
    end


    def saveConfiguration(key, event)
      event = deep_copy(event)
      if Ops.is_string?(Ops.get(event, "ID")) &&
          Ops.get_string(event, "ID", "") == "save"
        filename = UI.AskForSaveFileName("/", "*", _("Save as..."))
        if filename != nil && Convert.to_string(filename) != ""
          if IscsiServerFunctions.SaveIntoFile(Convert.to_string(filename))
            Popup.Message(
              Builtins.sformat(_("File %1 was saved successfully."), filename)
            )
            pathComponents = Builtins.splitstring(
              Convert.to_string(filename),
              "/"
            )
            s = Ops.subtract(Builtins.size(pathComponents), 1)
            base = Ops.get_string(pathComponents, s, "default")
          else
            Popup.Warning(_("An error occurred while saving the file."))
          end
        end
      end
      nil
    end




    #	**************** Server Dialog	*********************
    # dialog with targets

    # initialize target dialog
    def initTable(key)
      count = 0
      inc_items = []
      # create items from targets
      if Ops.greater_than(Builtins.size(IscsiServerFunctions.getTargets), 0)
        Builtins.foreach(IscsiServerFunctions.getTargets) do |key2, value|
          inc_items = Builtins.add(inc_items, Item(Id(count), key2))
          count = Ops.add(count, 1)
        end
      end
      # put it into table
      UI.ChangeWidget(Id(:server), :Items, inc_items)

      nil
    end

    def handleTable(table, event)
      event = deep_copy(event)
      ret = nil
      if Ops.get_string(event, "EventReason", "") == "Activated"
        case Ops.get_symbol(event, "ID")
          when :add
            # goto  AddDialog() (initAddTarget)
            ret = :add
          when :delete
            # add a new item
            if Popup.ContinueCancel(_("Really delete this item?"))
              del = Builtins.tointeger(
                UI.QueryWidget(Id(:server), :CurrentItem)
              )
              target = Ops.get_string(
                Convert.to_term(UI.QueryWidget(Id(:server), term(:Item, del))),
                1,
                ""
              )
              IscsiServerFunctions.setDelChanges(target)
              IscsiServerFunctions.removeTarget(
                Ops.get_string(
                  Convert.to_term(UI.QueryWidget(Id(:server), term(:Item, del))),
                  1,
                  ""
                )
              )
              initTable("")
            end
          when :edit
            # edit new item
            @edit = Builtins.tointeger(
              UI.QueryWidget(Id(:server), :CurrentItem)
            )
            @curr_target = Ops.get_string(
              Convert.to_term(UI.QueryWidget(Id(:server), term(:Item, @edit))),
              1,
              ""
            )
            if IscsiServerFunctions.setModifChanges(@curr_target) == 0
              Builtins.y2milestone("modified %1", @curr_target)
            else
              Builtins.y2error("%1 already modified", @curr_target)
            end
            # goto EditDialog() (initModify)
            ret = :edit
        end
      end
      if Builtins.size(Convert.to_list(UI.QueryWidget(:server, :Items))) == 0
        UI.ChangeWidget(:edit, :Enabled, false)
        UI.ChangeWidget(:delete, :Enabled, false)
      else
        UI.ChangeWidget(:edit, :Enabled, true)
        UI.ChangeWidget(:delete, :Enabled, true)
      end
      ret
    end

    # create items for incoming table
    def getAuthItems
      inc_items = []
      count = -1
      while Ops.less_than(count, Ops.subtract(Builtins.size(@inc_auth), 1))
        count = Ops.add(count, 1)
        inc_items = Builtins.add(
          inc_items,
          Item(
            Id(count),
            Ops.get_string(@inc_auth, [count, "USER"], ""),
            "*****"
          )
        )
      end
      deep_copy(inc_items)
    end

    def initiSNS(key)
      ac = false
      ip = ""
      Builtins.foreach(Ops.get_list(IscsiServerFunctions.getConfig, "iSNS", [])) do |row|
        if Ops.get_string(row, "KEY", "") == "iSNSAccessControl"
          ac = Ops.get_string(row, "VALUE", "No") == "Yes" ? true : false
        end
        if Ops.get_string(row, "KEY", "") == "iSNSServer"
          ip = Ops.get_string(row, "VALUE", "")
        end
      end
      UI.ChangeWidget(:isns_ac, :Value, ac)
      UI.ChangeWidget(:isns_ip, :Value, ip)

      nil
    end

    def validateiSNS(key, event)
      event = deep_copy(event)
      ip = Convert.to_string(UI.QueryWidget(:isns_ip, :Value))
      valid = true
      if Ops.greater_than(Builtins.size(ip), 0)
        valid = IP.Check(ip)
      else
        valid = true
      end
      Popup.Error(_("Invalid IP address.")) if !valid
      valid
    end

    def storeiSNS(option_id, option_map)
      option_map = deep_copy(option_map)
      ip = ""
      if Convert.to_boolean(UI.QueryWidget(:isns_ac, :Value))
        ip = Convert.to_string(UI.QueryWidget(:isns_ip, :Value))
      end
      ac = Convert.to_boolean(UI.QueryWidget(:isns_ac, :Value)) ? "Yes" : "No"
      ac = "" if ip == ""
      IscsiServerFunctions.setiSNS(ip, ac)

      nil
    end


    #	**************** Global Dialog	*********************
    def initGlobalValues(values)
      values = deep_copy(values)
      setAuthIn(false)
      setAuthOut(false)
      user = ""
      pass = ""
      # incoming authentication
      @inc_auth = {}
      count = 0
      Builtins.foreach(values) do |auth|
        if Ops.get_string(auth, "KEY", "") == "IncomingUser"
          user = Ops.get(
            Builtins.splitstring(Ops.get_string(auth, "VALUE", ""), " "),
            0,
            ""
          )
          pass = Ops.get(
            Builtins.splitstring(Ops.get_string(auth, "VALUE", ""), " "),
            1,
            ""
          )
          Ops.set(@inc_auth, count, { "USER" => user, "PASS" => pass })
          count = Ops.add(count, 1)
          setAuthIn(true)
        end
        if Ops.get_string(auth, "KEY", "") == "OutgoingUser"
          UI.ChangeWidget(
            Id(:user_out),
            :Value,
            Ops.get(
              Builtins.splitstring(Ops.get_string(auth, "VALUE", ""), " "),
              0,
              ""
            )
          )
          UI.ChangeWidget(
            Id(:pass_out),
            :Value,
            Ops.get(
              Builtins.splitstring(Ops.get_string(auth, "VALUE", ""), " "),
              1,
              ""
            )
          )
          setAuthOut(true)
        end
      end
      UI.ChangeWidget(Id(:incoming_table), :Items, getAuthItems)

      nil
    end

    # initialize discovery authentication or authentication for given target
    def initGlobal(key)
      if Ops.greater_than(Builtins.size(@curr_target), 0)
        initGlobalValues(
          Ops.get_list(IscsiServerFunctions.getConfig, @curr_target, [])
        )
      else
        #if (size(IscsiServerFunctions::getConfig()["auth"]:[])>0)
        initGlobalValues(
          Ops.get_list(IscsiServerFunctions.getConfig, "auth", [])
        )
      end

      nil
    end

    # save discovery authentication or authentication for given target
    def storeGlobal(option_id, option_map)
      option_map = deep_copy(option_map)
      if Ops.greater_than(Builtins.size(@curr_target), 0)
        IscsiServerFunctions.setTargetAuth(
          @curr_target,
          getIncomingValues,
          getOutgoingValues
        )
        IscsiServerFunctions.saveNewTarget(@curr_target)
      else
        IscsiServerFunctions.setAuth(getIncomingValues, getOutgoingValues)
      end

      nil
    end

    # validate functions checks the secret for incoming and outgoing cannot be same
    def validateGlobal(key, event)
      event = deep_copy(event)
      ret = false
      if !Builtins.contains(getIncomingValues, getOutgoingValues)
        ret = true
      else
        Popup.Error(
          _(
            "Cannot use the same secret for incoming and outgoing authentication."
          )
        )
      end
      ret
    end
    #	************** Add Target Dialog	******************
    # initialize function for create new target
    def initAddTarget(key)
      # some proposed values
      target = "iqn"
      date = Ops.get_string(
        Convert.convert(
          SCR.Execute(path(".target.bash_output"), "date +%Y-%m"),
          :from => "any",
          :to   => "map <string, any>"
        ),
        "stdout",
        ""
      )
      domain = Ops.get_string(
        Convert.convert(
          SCR.Execute(path(".target.bash_output"), "dnsdomainname"),
          :from => "any",
          :to   => "map <string, any>"
        ),
        "stdout",
        ""
      )
      uuid = Ops.get_string(
        Convert.convert(
          SCR.Execute(path(".target.bash_output"), "uuidgen"),
          :from => "any",
          :to   => "map <string, any>"
        ),
        "stdout",
        ""
      )
      uuid = Builtins.deletechars(uuid, "\n")
      if Ops.greater_than(Builtins.size(domain), 0)
        domain = Ops.get(Builtins.splitstring(domain, "\n"), 0, "")
        tmp_list = Builtins.splitstring(domain, ".")
        domain = Builtins.sformat(
          "%1.%2",
          Ops.get(tmp_list, 1, ""),
          Ops.get(tmp_list, 0, "")
        )
      else
        domain = "com.example"
      end
      target = Builtins.deletechars(
        Builtins.sformat("%1.%2.%3", target, date, domain),
        "\n"
      )
      Builtins.y2milestone("init values for add_target %1", target)
      UI.ChangeWidget(Id(:target), :Value, target)
      UI.ChangeWidget(Id(:identifier), :Value, uuid) 
      # UI::ChangeWidget(`id(`lun), `Value, tostring(IscsiServerFunctions::getNextLun()) );

      nil
    end

    # symbol handleAddTarget (string table, map event){
    #  symbol ret = nil;
    #  if(event["EventReason"]:"" == "Activated"){
    #   switch((symbol)event["ID"]:nil){
    #    case(`add)        : y2internal("add");
    # 			return `lun_add;
    #    case(`edit)        : y2internal("edit");
    # 			break;
    #    case(`delete)        : y2internal("delete");
    # 			break;
    #    case(`expert)        : y2internal("expert");
    # 			return `expert;
    #
    #   }
    #  }
    # }

    # save values
    def storeAddTarget(option_id, option_map)
      option_map = deep_copy(option_map)
      old = []
      target = Builtins.tostring(
        Builtins.sformat(
          "%1:%2",
          UI.QueryWidget(Id(:target), :Value),
          UI.QueryWidget(Id(:identifier), :Value)
        )
      )
      # string lun = sformat("%1 Path=%2,Type=fileio",UI::QueryWidget(`id(`lun), `Value), UI::QueryWidget(`id(`path), `Value) );
      # add/modify that values
      items = []
      Builtins.foreach(
        Convert.convert(
          UI.QueryWidget(:lun_table, :Items),
          :from => "any",
          :to   => "list <term>"
        )
      ) do |row|
        items = Builtins.add(
          items,
          {
            "KEY"   => Ops.get_string(row, 1, ""),
            "VALUE" => Ops.get_string(row, 2, "")
          }
        )
      end
      Builtins.y2milestone("Add target %1", target)
      IscsiServerFunctions.addNewTarget(target, items)
      @curr_target = target

      nil
    end

    # validate function checks if target/lun are unique and not empty
    def validateAddTarget(key, event)
      event = deep_copy(event)
      target = Builtins.tostring(UI.QueryWidget(Id(:target), :Value))
      # string lun = tostring(    UI::QueryWidget(`id(`lun), `Value)       );
      type = "no"
      if Builtins.size(target) == 0 &&
          Popup.Error(_("The target cannot be empty.")) == nil ||
          IscsiServerFunctions.ifExists("Target", target) &&
            Popup.Error(_("The target already exists.")) == nil
        UI.SetFocus(Id(:target))
        return false
      end
      #  if ((size(lun)==0 && (Popup::Error(_("The logical unit definition cannot be empty."))==nil))||
      #         ( IscsiServerFunctions::ifExists("Lun", lun) && (Popup::Error(_("The logical unit already exists."))==nil))){
      #   UI::SetFocus(`id(`lun));
      #   return false;
      #  }
      true
    end

    #	**************** Target Auth	*******************
    # handle authentication dialog
    def handleAuth(key, event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventReason", "") == "ValueChanged"
        status = false
        # enable/disable none/incoming/outgoing authentication
        case Ops.get_symbol(event, "ID")
          when :auth_none
            status = Convert.to_boolean(UI.QueryWidget(Id(:auth_none), :Value))
            setAuthIn(!status)
            setAuthOut(!status)
          when :auth_in
            status = Convert.to_boolean(UI.QueryWidget(Id(:auth_in), :Value))
            setAuthIn(status)
          when :auth_out
            status = Convert.to_boolean(UI.QueryWidget(Id(:auth_out), :Value))
            setAuthOut(status)
        end
      end
      # add/edit/delete incoming authentication
      if Ops.get_string(event, "EventReason", "") == "Activated"
        case Ops.get_symbol(event, "ID")
          when :add
            @values = getDialogValues("", "")
            Builtins.y2milestone("Add authentication values")
            if Builtins.size(@values) == 2
              user = Ops.get(@values, 0, "")
              pass = Ops.get(@values, 1, "")
              count = Builtins.size(
                Convert.to_list(UI.QueryWidget(Id(:incoming_table), :Items))
              )

              Ops.set(
                @inc_auth,
                Builtins.size(@inc_auth),
                { "USER" => user, "PASS" => pass }
              )
              UI.ChangeWidget(Id(:incoming_table), :Items, getAuthItems)
            end
          when :edit
            @curr = Builtins.tointeger(
              UI.QueryWidget(Id(:incoming_table), :CurrentItem)
            )
            Builtins.y2milestone("Modify authentication values")
            if @curr != nil
              user = Ops.get_string(@inc_auth, [@curr, "USER"], "")
              pass = Ops.get_string(@inc_auth, [@curr, "PASS"], "")
              values = getDialogValues(user, pass)

              if Builtins.size(values) == 2
                user2 = Ops.get(values, 0, "")
                pass2 = Ops.get(values, 1, "")

                rows = Convert.convert(
                  UI.QueryWidget(Id(:incoming_table), :Items),
                  :from => "any",
                  :to   => "list <term>"
                )
                Ops.set(@inc_auth, @curr, { "USER" => user2, "PASS" => pass2 })
                UI.ChangeWidget(Id(:incoming_table), :Items, getAuthItems)
              end
            end
          when :delete
            @del = UI.QueryWidget(Id(:incoming_table), :CurrentItem)
            Builtins.y2milestone("Delete authentication value")
            if @del != nil
              if Popup.ContinueCancel(_("Really delete the selected item?"))
                count = 0
                temp_map = {}
                while Ops.less_than(count, Builtins.size(@inc_auth))
                  if Ops.less_than(count, @del)
                    Ops.set(temp_map, count, Ops.get(@inc_auth, count))
                  elsif count == @del

                  else
                    Ops.set(
                      temp_map,
                      Ops.subtract(count, 1),
                      Ops.get(@inc_auth, count)
                    )
                  end
                  count = Ops.add(count, 1)
                end
                @inc_auth = deep_copy(temp_map)
                UI.ChangeWidget(Id(:incoming_table), :Items, getAuthItems)
              else
                Builtins.y2milestone("Delete canceled")
              end
            end
        end
      end
      if Builtins.size(Convert.to_list(UI.QueryWidget(:incoming_table, :Items))) == 0
        UI.ChangeWidget(:edit, :Enabled, false)
        UI.ChangeWidget(:delete, :Enabled, false)
      else
        UI.ChangeWidget(:edit, :Enabled, true)
        UI.ChangeWidget(:delete, :Enabled, true)
      end

      nil
    end

    #	**************** Edit Dialog	*****************************

    # init values for modifying target (read it from stored map)
    def initModify(key)
      inc_items = []
      Builtins.foreach(
        Convert.convert(
          IscsiServerFunctions.editTarget(@curr_target),
          :from => "list",
          :to   => "list <map <string, any>>"
        )
      ) do |row|
        case Ops.get_string(row, "KEY", "")
          when "Target"
            UI.ChangeWidget(
              Id(:target),
              :Value,
              Ops.get(
                Builtins.splitstring(Ops.get_string(row, "VALUE", ""), ":"),
                0,
                ""
              )
            )
            UI.ChangeWidget(Id(:target), :Enabled, false)
            UI.ChangeWidget(
              Id(:identifier),
              :Value,
              Ops.get(
                Builtins.splitstring(Ops.get_string(row, "VALUE", ""), ":"),
                1,
                ""
              )
            )
            UI.ChangeWidget(Id(:identifier), :Enabled, false)
          when "Lun"
            inc_items = Builtins.add(
              inc_items,
              Item(
                Id(Builtins.size(inc_items)),
                Ops.get_string(row, "KEY", ""),
                Ops.get_string(row, "VALUE", "")
              )
            )
            # put it into table
            UI.ChangeWidget(Id(:lun_table), :Items, inc_items)
        end
      end

      nil
    end

    def handleModify(key, event)
      event = deep_copy(event)
      if Ops.get_string(event, "EventReason", "") == "Activated"
        case Ops.get_symbol(event, "WidgetID")
          when :delete
            @del = UI.QueryWidget(Id(:lun_table), :CurrentItem)
            if @del != nil
              if Popup.ContinueCancel(_("Really delete the selected item?"))
                Builtins.y2milestone("Delete LUN %1 from table", @del)
                items = []
                count = 0
                Builtins.foreach(
                  Convert.convert(
                    UI.QueryWidget(:lun_table, :Items),
                    :from => "any",
                    :to   => "list <term>"
                  )
                ) do |row|
                  if count != @del
                    items = Builtins.add(
                      items,
                      Item(
                        Id(Builtins.size(items)),
                        Ops.get_string(row, 1, ""),
                        Ops.get_string(row, 2, "")
                      )
                    )
                  end
                  count = Ops.add(count, 1)
                end
                UI.ChangeWidget(Id(:lun_table), :Items, items)
              else
                Builtins.y2milestone("Delete canceled")
              end
            end
          when :edit
            @items = Convert.convert(
              UI.QueryWidget(:lun_table, :Items),
              :from => "any",
              :to   => "list <term>"
            )
            @edit_pos = Builtins.tointeger(
              UI.QueryWidget(:lun_table, :CurrentItem)
            )
            @ret_map = LUNDetailDialog(
              {
                "KEY"   => "Lun",
                "VALUE" => Ops.get_string(@items, [@edit_pos, 2], "")
              }
            )
            if @ret_map != {}
              Ops.set(
                @items,
                @edit_pos,
                Item(
                  Id(@edit_pos),
                  Ops.get_string(@ret_map, "KEY", ""),
                  Ops.get_string(@ret_map, "VALUE", "")
                )
              )
              UI.ChangeWidget(:lun_table, :Items, @items)
            end
          when :add
            @add_map = LUNDetailDialog(
              {
                "KEY"   => "Lun",
                "VALUE" => Builtins.tostring(
                  Builtins.size(
                    Convert.convert(
                      UI.QueryWidget(:lun_table, :Items),
                      :from => "any",
                      :to   => "list <term>"
                    )
                  )
                )
              }
            )
            if @add_map != {}
              items = Convert.to_list(UI.QueryWidget(:lun_table, :Items))
              items = Builtins.add(
                items,
                Item(
                  Id(Builtins.size(items)),
                  Ops.get_string(@add_map, "KEY", ""),
                  Ops.get_string(@add_map, "VALUE", "")
                )
              )
              UI.ChangeWidget(:lun_table, :Items, items)
            end
        end
      end
      if Builtins.size(Convert.to_list(UI.QueryWidget(:lun_table, :Items))) == 0
        UI.ChangeWidget(:edit, :Enabled, false)
        UI.ChangeWidget(:delete, :Enabled, false)
      else
        UI.ChangeWidget(:edit, :Enabled, true)
        UI.ChangeWidget(:delete, :Enabled, true)
      end

      nil
    end

    def storeModify(option_id, option_map)
      option_map = deep_copy(option_map)
      items = []
      Builtins.foreach(
        Convert.convert(
          UI.QueryWidget(:lun_table, :Items),
          :from => "any",
          :to   => "list <term>"
        )
      ) do |row|
        items = Builtins.add(
          items,
          {
            "KEY"   => Ops.get_string(row, 1, ""),
            "VALUE" => Ops.get_string(row, 2, "")
          }
        )
      end
      IscsiServerFunctions.setLUN(@curr_target, items)

      nil
    end

    #	************** LUN Detail Dialog ****************************
    def handleLUN(key, event)
      event = deep_copy(event)
      enable = false
      if Convert.to_boolean(UI.QueryWidget(:fileio, :Value)) == true
        enable = true
      end

      UI.ChangeWidget(:file_path, :Enabled, enable)
      UI.ChangeWidget(:browse, :Enabled, enable)
      UI.ChangeWidget(:scsi_id, :Enabled, enable)
      UI.ChangeWidget(:sectors, :Enabled, !enable)

      if Ops.get_string(event, "EventReason", "") == "Activated" &&
          Ops.get(event, "WidgetID") == :browse
        file = UI.AskForExistingFile("/", "", _("Select file or device"))
        UI.ChangeWidget(:file_path, :Value, file) if file != nil
      end

      nil
    end

    def storeLUN(option_id, option_map)
      option_map = deep_copy(option_map)
      lun = Convert.to_string(UI.QueryWidget(:lun, :Value))

      nil
    end
  end
end
