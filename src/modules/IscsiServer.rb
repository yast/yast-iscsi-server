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
# File:	modules/IscsiServer.ycp
# Package:	Configuration of iscsi-server
# Summary:	IscsiServer settings, input and output functions
# Authors:	Michal Zugec <mzugec@suse.cz>
#
# $Id$
#
# Representation of the configuration of iscsi-server.
# Input and output routines.
require "yast"

module Yast
  class IscsiServerClass < Module
    def main
      textdomain "iscsi-server"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "Message"
      Yast.import "Service"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "SuSEFirewall"
      Yast.import "Confirm"
      Yast.import "IscsiServerFunctions"
      Yast.import "Mode"
      Yast.import "NetworkService"
      Yast.import "PackageSystem"
      Yast.import "Label"

      @serviceStatus = false
      @statusOnStart = false

      # Data was modified?
      @modified = false
      @configured = false


      @proposal_valid = false

      # Write only, used during autoinstallation.
      # Don't run services and SuSEconfig, it's all done at one place.
      @write_only = false

      # Abort function
      # return boolean return true if abort
      @AbortFunction = fun_ref(method(:Modified), "boolean ()")
    end

    # Abort function
    # @return [Boolean] return true if abort
    def Abort
      return @AbortFunction.call == true if @AbortFunction != nil
      false
    end

    # Data was modified?
    # @return true if modified
    def Modified
      Builtins.y2debug("modified=%1", @modified)
      @modified
    end



    # Settings: Define all variables needed for configuration of iscsi-server
    # TODO FIXME: Define all the variables necessary to hold
    # TODO FIXME: the configuration here (with the appropriate
    # TODO FIXME: description)
    # TODO FIXME: For example:
    #   /**
    #    * List of the configured cards.
    #   list cards = [];
    #
    #   /**
    #    * Some additional parameter needed for the configuration.
    #   boolean additional_parameter = true;

    # read configuration file ietd.conf
    def readConfig
      read_values = Convert.convert(
        SCR.Read(path(".etc.ietd.all")),
        :from => "any",
        :to   => "map <string, any>"
      )
      IscsiServerFunctions.parseConfig(read_values)
      true
    end


    # write configuration file ietd.conf
    def writeConfig
      # prepare map, because perl->ycp lost information about data types (integers in this case)
      config_file = IscsiServerFunctions.writeConfig
      Ops.set(
        config_file,
        "type",
        Builtins.tointeger(Ops.get_string(config_file, "type", "1"))
      )
      Ops.set(
        config_file,
        "file",
        Builtins.tointeger(Ops.get_string(config_file, "file", "1"))
      )
      value = []
      Builtins.foreach(Ops.get_list(config_file, "value", [])) do |row|
        Ops.set(
          row,
          "type",
          Builtins.tointeger(Ops.get_string(row, "type", "1"))
        )
        Ops.set(
          row,
          "file",
          Builtins.tointeger(Ops.get_string(row, "file", "1"))
        )
        value = Builtins.add(value, row)
      end

      Ops.set(config_file, "value", value)
      Builtins.y2milestone("config_file to write %1", config_file)
      # write it
      SCR.Write(path(".etc.ietd.all"), config_file)
      SCR.Write(path(".etc.ietd"), nil)
      true
    end

    # test if required package ("iscsitarget") is installed
    def installed_packages
      if !PackageSystem.PackageInstalled("iscsitarget")
        Builtins.y2milestone("Not installed, will install")
        confirm = Popup.AnyQuestionRichText(
          "",
          _("Cannot continue without installing iscsitarget package."),
          40,
          10,
          Label.InstallButton,
          Label.CancelButton,
          :focus_yes
        )

        if confirm
          service = "tgtd"
          Service.Stop(service) if Service.Status(service) == 0
          Service.Disable(service)
          PackageSystem.DoInstall(["iscsitarget"])
          if PackageSystem.PackageInstalled("iscsitarget")
            return true
          else
            return false
          end
        end
        return false
      else
        return true
      end
    end

    # check status of iscsitarget service
    # if not enabled, start it manually
    def getServiceStatus
      ret = true
      if Service.Status("iscsitarget") == 0
        @statusOnStart = true
        @serviceStatus = true
      end
      Builtins.y2milestone("Service status = %1", @statusOnStart)
      Service.Start("iscsitarget") if !@statusOnStart
      ret
    end

    # set service status
    def setServiceStatus
      start = true
      start = @statusOnStart if !@serviceStatus

      if !start
        Builtins.y2milestone("Stop iscsitarget service")
        Service.Stop("iscsitarget")
      else
        Builtins.y2milestone("Start iscsitarget service")
        @serviceStatus = true
        Service.Start("iscsitarget")
      end
      true
    end

    # #157643 - reload server
    def reloadServer
      # ask user whether reload or restart server
      # #180205 - gettext problem - string wasn't marked to translate
      if Popup.YesNo(
          _(
            "If changes have been made, the iSCSI target is not able\n" +
              "to reload the current configuration. It can only restart.\n" +
              "When restarting, all sessions are aborted.\n" +
              "Restart the iscsitarget service?\n"
          )
        )
        Service.Restart("iscsitarget")
      else
        # get changes from perl module
        changes = IscsiServerFunctions.getChanges
        connected = IscsiServerFunctions.getConnected
        # plus add there all targets except with active sessions (it means delete and create as new each target)
        #          foreach(string key,any value, IscsiServerFunctions::getTargets(), {
        # 	 if ((!contains(connected, key))&&(!contains(changes["add"]:[], key))&&(!contains(changes["del"]:[], key))){
        # 	   changes["del"] = add (changes["del"]:[], key);
        # 	   changes["add"] = add (changes["add"]:[], key);
        #            y2milestone("modified key %1", key);
        # 	  }
        #          });
        # delete targets
        Builtins.foreach(Ops.get_list(changes, "del", [])) do |row|
          if !Builtins.contains(connected, row)
            Builtins.y2milestone("row to delete %1", row)
            target = Ops.get_string(
              Convert.convert(
                SCR.Execute(
                  path(".target.bash_output"),
                  # get TID number for target
                  "cat /proc/net/iet/volume|grep $TARGET",
                  { "TARGET" => row }
                ),
                :from => "any",
                :to   => "map <string, any>"
              ),
              "stdout",
              ""
            )
            to_delete = Ops.get(
              Builtins.splitstring(
                Ops.get(Builtins.splitstring(target, " "), 0, ""),
                ":"
              ),
              1,
              ""
            )
            Builtins.y2milestone("to delete %1", to_delete)
            # delete record with that TID
            SCR.Execute(
              path(".target.bash_output"),
              "ietadm --op delete --tid=$TID",
              { "TID" => to_delete }
            )
          else
            Builtins.y2error("Cannot remove target %1 - already connected", row)
          end
        end

        # add a new target
        Builtins.foreach(Ops.get_list(changes, "add", [])) do |row|
          Builtins.y2milestone("row to add %1", row)
          # create new target
          SCR.Execute(
            path(".target.bash_output"),
            "ietadm --op new --tid=0 --params Name=$NAME",
            { "NAME" => row }
          )
          target = Ops.get_string(
            Convert.convert(
              SCR.Execute(
                path(".target.bash_output"),
                "cat /proc/net/iet/volume|grep $TARGET",
                { "TARGET" => row }
              ),
              :from => "any",
              :to   => "map <string, any>"
            ),
            "stdout",
            ""
          )
          # get TID of that target
          to_add = Ops.get(
            Builtins.splitstring(
              Ops.get(Builtins.splitstring(target, " "), 0, ""),
              ":"
            ),
            1,
            ""
          )
          Builtins.y2milestone("to add %1", to_add)
          lun = []
          secret = []
          # add authentication to target
          Builtins.foreach(
            Ops.get_list(IscsiServerFunctions.getConfig, row, [])
          ) do |conf_row|
            case Ops.get_string(conf_row, "KEY", "")
              when "Lun"
                lun = Builtins.splitstring(
                  Ops.get_string(conf_row, "VALUE", ""),
                  " "
                )
              when "IncomingUser"
                secret = Builtins.splitstring(
                  Ops.get_string(conf_row, "VALUE", ""),
                  " "
                )
                Builtins.y2milestone(
                  "params %1 %2 %3",
                  to_add,
                  Ops.get(secret, 0, ""),
                  Ops.get(secret, 1, "")
                )
                SCR.Execute(
                  path(".target.bash_output"),
                  "ietadm --op new --tid=$TID --user --params=IncomingUser=$US,Password=$PASS",
                  {
                    "TID"  => to_add,
                    "US"   => Ops.get(secret, 0, ""),
                    "PASS" => Ops.get(secret, 1, "")
                  }
                )
              when "OutgoingUser"
                secret = Builtins.splitstring(
                  Ops.get_string(conf_row, "VALUE", ""),
                  " "
                )
                SCR.Execute(
                  path(".target.bash_output"),
                  "ietadm --op new --tid=$TID --user --params=OutgoingUser=$US,Password=$PASS",
                  {
                    "TID"  => to_add,
                    "US"   => Ops.get(secret, 0, ""),
                    "PASS" => Ops.get(secret, 1, "")
                  }
                )
            end
          end
          lun_num = Ops.get(lun, 0, "")
          lun_path = Ops.get(
            Builtins.splitstring(Ops.get(lun, 1, ""), ","),
            0,
            ""
          )
          # add LUN for target
          command = Builtins.sformat(
            "ietadm --op new --tid=%1 --lun=%2 --params %3",
            to_add,
            lun_num,
            lun_path
          )
          SCR.Execute(path(".target.bash_output"), command, {})
          Builtins.y2milestone("lun %1,%2", lun_num, lun_path)
        end
      end
      true
    end


    # Read all iscsi-server settings
    # @return true on success
    def Read
      # IscsiServer read dialog caption
      caption = _("Initializing iSCSI Target Configuration")

      # TODO FIXME Set the right number of stages
      steps = 4

      sl = 500
      Builtins.sleep(sl)

      # TODO FIXME Names of real stages
      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/3
          _("Read the database"),
          # Progress stage 2/3
          _("Read the previous settings"),
          # Progress stage 3/3
          _("Detect the devices")
        ],
        [
          # Progress step 1/3
          _("Reading the database..."),
          # Progress step 2/3
          _("Reading the previous settings..."),
          # Progress step 3/3
          _("Detecting the devices..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # check if user is root
      return false if !Confirm.MustBeRoot
      return false if !NetworkService.RunningNetworkPopup
      Progress.NextStage
      # check if required packages ("iscsitarget") are installed
      return false if !installed_packages
      Builtins.sleep(sl)

      return false if Abort()
      Progress.NextStep
      # get status of iscsitarget init script
      return false if !getServiceStatus
      Builtins.sleep(sl)

      return false if Abort()
      Progress.NextStage
      # read configuration (ietd.conf)
      if !readConfig
        Report.Error(Message.CannotReadCurrentSettings)
        return false
      end
      Builtins.sleep(sl)

      # detect devices
      Progress.set(false)
      SuSEFirewall.Read
      Progress.set(true)

      Progress.NextStage
      # Error message
      return false if false
      Builtins.sleep(sl)

      return false if Abort()
      # Progress finished
      Progress.NextStage
      Builtins.sleep(sl)

      return false if Abort()
      @modified = false
      @configured = true
      true
    end

    # Write all iscsi-server settings
    # @return true on success
    def Write
      # IscsiServer write dialog caption
      caption = _("Saving iSCSI Target Configuration")

      # TODO FIXME And set the right number of stages
      steps = 2

      sl = 500
      Builtins.sleep(sl)

      # TODO FIXME Names of real stages
      # We do not set help text here, because it was set outside
      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Write the settings"),
          # Progress stage 2/2
          _("Run SuSEconfig")
        ],
        [
          # Progress step 1/2
          _("Writing the settings..."),
          # Progress step 2/2
          _("Running SuSEconfig..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )


      Progress.set(false)
      SuSEFirewall.Write
      Progress.set(true)

      Progress.NextStage
      # write configuration (ietd.conf)
      Report.Error(_("Cannot write settings.")) if !writeConfig
      Builtins.sleep(sl)


      return false if Abort()
      Progress.NextStage
      #  ask user whether reload or restart server and do it
      return false if !reloadServer if @serviceStatus || @statusOnStart
      Builtins.sleep(sl)

      return false if Abort()
      Progress.NextStage
      Builtins.sleep(sl)

      # set iscsitarget initscript status
      return false if !setServiceStatus
      true
    end

    # Get all iscsi-server settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      Builtins.foreach(
        Convert.convert(settings, :from => "map", :to => "map <string, any>")
      ) do |key, value|
        case key
          when "service"
            @serviceStatus = Convert.to_boolean(value)
          when "auth"
            @incom = []
            @outgoin = ""
            Builtins.foreach(
              Convert.convert(
                value,
                :from => "any",
                :to   => "list <map <string, any>>"
              )
            ) do |row|
              if Ops.get_string(row, "KEY", "") == "IncomingUser"
                @incom = Builtins.add(@incom, Ops.get_string(row, "VALUE", ""))
              else
                @outgoin = Ops.get_string(row, "VALUE", "")
              end
            end
            IscsiServerFunctions.setAuth(@incom, @outgoin)
          when "targets"
            @name = ""
            @lun = []
            @inc = []
            @out = ""
            Builtins.foreach(
              Convert.convert(
                value,
                :from => "any",
                :to   => "list <list <map <string, any>>>"
              )
            ) do |val|
              @name = ""
              @lun = []
              @inc = []
              @out = ""
              Builtins.foreach(val) do |row|
                case Ops.get_string(row, "KEY", "")
                  when "Target"
                    @name = Ops.get_string(row, "VALUE", "")
                  when "Lun"
                    @lun = Builtins.add(@lun, row)
                  when "IncomingUser"
                    @inc = Builtins.add(@inc, Ops.get_string(row, "VALUE", ""))
                  when "OutgoingUser"
                    @out = Ops.get_string(row, "VALUE", "")
                end
              end
              IscsiServerFunctions.addNewTarget(@name, @lun)
              IscsiServerFunctions.setTargetAuth(@name, @inc, @out)
            end
        end
      end

      @configured = true
      true
    end

    # Dump the iscsi-server settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      targets = []
      Builtins.foreach(IscsiServerFunctions.getTargets) do |k, v|
        targets = Builtins.add(targets, v)
      end

      result = {
        "version" => "1.0",
        "service" => @serviceStatus,
        "auth"    => Ops.get_list(IscsiServerFunctions.getConfig, "auth", []),
        "targets" => targets
      }
      @configured = true
      deep_copy(result)
    end

    def noAuth(config)
      config = deep_copy(config)
      ret = true
      Builtins.foreach(config) do |row|
        if Ops.get_string(row, "KEY", "") == "IncomingUser" ||
            Ops.get_string(row, "KEY", "") == "OutgoingUser"
          ret = false
        end
      end
      ret
    end

    def authIn(config)
      config = deep_copy(config)
      ret = false
      Builtins.foreach(config) do |row|
        ret = true if Ops.get_string(row, "KEY", "") == "IncomingUser"
      end
      ret
    end

    def authOut(config)
      config = deep_copy(config)
      ret = false
      Builtins.foreach(config) do |row|
        ret = true if Ops.get_string(row, "KEY", "") == "OutgoingUser"
      end
      ret
    end

    def getLun(config)
      config = deep_copy(config)
      ret = ""
      Builtins.foreach(config) do |row|
        if Ops.get_string(row, "KEY", "") == "Lun"
          ret = Ops.get_string(row, "VALUE", "")
        end
      end
      ret
    end

    # Create a textual summary and a list of unconfigured cards
    # @return summary of the current configuration
    def Summary
      summary = _("Configuration summary...")
      if @configured
        summary = Summary.AddHeader("", _("Global"))
        if @serviceStatus
          summary = Summary.AddLine(summary, _("When Booting"))
        else
          summary = Summary.AddLine(summary, _("Manually"))
        end
        if noAuth(Ops.get_list(IscsiServerFunctions.getConfig, "auth", []))
          summary = Summary.AddLine(summary, _("No Authentication"))
        else
          if authIn(Ops.get_list(IscsiServerFunctions.getConfig, "auth", []))
            summary = Summary.AddLine(summary, _("Incoming Authentication"))
          end
          if authOut(Ops.get_list(IscsiServerFunctions.getConfig, "auth", []))
            summary = Summary.AddLine(summary, _("Outgoing Authentication"))
          end
        end
        summary = Summary.AddHeader(summary, _("Targets"))
        summary = Summary.OpenList(summary)
        Builtins.foreach(IscsiServerFunctions.getTargets) do |key, value|
          summary = Summary.AddListItem(summary, key)
          summary = Summary.AddLine(
            summary,
            getLun(
              Convert.convert(
                value,
                :from => "any",
                :to   => "list <map <string, any>>"
              )
            )
          )
          if noAuth(
              Convert.convert(
                value,
                :from => "any",
                :to   => "list <map <string, any>>"
              )
            )
            summary = Summary.AddLine(summary, _("No Authentication"))
          else
            if authIn(
                Convert.convert(
                  value,
                  :from => "any",
                  :to   => "list <map <string, any>>"
                )
              )
              summary = Summary.AddLine(summary, _("Incoming Authentication"))
            end
            if authOut(
                Convert.convert(
                  value,
                  :from => "any",
                  :to   => "list <map <string, any>>"
                )
              )
              summary = Summary.AddLine(summary, _("Outgoing Authentication"))
            end
          end
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.NotConfigured
      end
      # TODO FIXME: your code here...
      # Configuration summary text for autoyast
      [summary, []]
    end

    # Create an overview table with all configured cards
    # @return table items
    def Overview
      # TODO FIXME: your code here...
      []
    end

    # Return packages needed to be installed and removed during
    # Autoinstallation to insure module has all needed software
    # installed.
    # @return [Hash] with 2 lists.
    def AutoPackages
      # TODO FIXME: your code here...
      { "install" => [], "remove" => [] }
    end


    # get/set service accessors for CWMService component
    def GetStartService
      status = Service.Enabled("iscsitarget")
      Builtins.y2milestone("iscsitarget service status %1", status)
      status
    end

    def SetStartService(status)
      Builtins.y2milestone("Set service status %1", status)
      @serviceStatus = status
      if status == true
        Service.Enable("iscsitarget")
      else
        Service.Disable("iscsitarget")
      end

      nil
    end

    publish :function => :Modified, :type => "boolean ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :configured, :type => "boolean"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :AbortFunction, :type => "boolean ()"
    publish :function => :Abort, :type => "boolean ()"
    publish :function => :readConfig, :type => "boolean ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list ()"
    publish :function => :Overview, :type => "list ()"
    publish :function => :AutoPackages, :type => "map ()"
    publish :function => :GetStartService, :type => "boolean ()"
    publish :function => :SetStartService, :type => "void (boolean)"
  end

  IscsiServer = IscsiServerClass.new
  IscsiServer.main
end
