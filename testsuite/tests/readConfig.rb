# encoding: utf-8

module Yast
  class ReadConfigClient < Client
    def main
      # testedfiles: IscsiServer.ycp

      Yast.include self, "testsuite.rb"

      @READ = {
        "etc" => {
          "ietd" => {
            "all" => {
              "comment" => "",
              "file"    => -1,
              "kind"    => "section",
              "name"    => "",
              "type"    => -1,
              "value"   => [
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "IncomingUser",
                  "type"    => 1,
                  "value"   => "inname1 inpass1"
                },
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "IncomingUser",
                  "type"    => 1,
                  "value"   => "inname2 inpass2"
                },
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "OutgoingUser",
                  "type"    => 1,
                  "value"   => "outname outpass"
                },
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "Target",
                  "type"    => 1,
                  "value"   => "iqn.2006-04.suse.cz:308443b2-f0e6-465d-8889-ba290efedd58"
                },
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "Lun",
                  "type"    => 1,
                  "value"   => "1 Path=/tmp/file,Type=fileio"
                },
                {
                  "comment" => "",
                  "kind"    => "value",
                  "name"    => "IncomingUser",
                  "type"    => 1,
                  "value"   => "inname1 inpass1"
                },
                {
                  "comment" => "# Example iscsi target configuration\n" +
                    "#\n" +
                    "# Everything until the first target definition belongs\n" +
                    "# to the global configuration.\n" +
                    "# Right now this is only the user configuration used\n" +
                    "# during discovery sessions. \"IncomingUser\" specifies credentials the\n" +
                    "# initiator has to provide - several of these are supported. If mutual\n" +
                    "# CHAP shall be employed, \"OutgoingUser\" specifies the user/pass\n" +
                    "# combination the target will provide - only one is supported.\n" +
                    "# Leave them alone (keep them commented out) if you don't want to use\n" +
                    "# authentication for discovery sessions.\n" +
                    "\n" +
                    "#IncomingUser joe secret\n" +
                    "#OutgoingUser jack 12charsecret\n" +
                    "\n" +
                    "# Targets definitions start with \"Target\" and the target name.\n" +
                    "# The target name must be a globally unique name, the iSCSI\n" +
                    "# standard defines the \"iSCSI Qualified Name\" as follows:\n" +
                    "#\n" +
                    "# iqn.yyyy-mm.<reversed domain name>[:identifier]\n" +
                    "#\n" +
                    "# \"yyyy-mm\" is the date at which the domain is valid and the identifier\n" +
                    "# is freely selectable. For further details please check the iSCSI spec.\n" +
                    "\n",
                  "kind"    => "value",
                  "name"    => "Target",
                  "type"    => 1,
                  "value"   => "iqn.2001-04.com.example:storage.disk2.sys1.xyz"
                },
                {
                  "comment" => "\t# Users, who can access this target. The same rules as for discovery\n" +
                    "\t# users apply here.\n" +
                    "\t# Leave them alone if you don't want to use authentication.\n" +
                    "\t#IncomingUser joe secret\n" +
                    "\t#OutgoingUser jim 12charpasswd\n" +
                    "\t# Logical Unit definition\n" +
                    "\t# You must define one logical unit at least.\n" +
                    "\t# Block devices, regular files, LVM, and RAID can be offered\n" +
                    "\t# to the initiators as a block device.\n",
                  "kind"    => "value",
                  "name"    => "Lun",
                  "type"    => 1,
                  "value"   => "0 Path=/dev/sdc,Type=fileio"
                }
              ]
            }
          }
        }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "IscsiServer"
      Yast.import "IscsiServerFunctions"

      TEST(lambda { IscsiServer.readConfig }, [@READ, {}, {}], nil)
      DUMP(IscsiServerFunctions.getConfig)
      TEST(lambda do
        IscsiServerFunctions.removeTarget(
          "iqn.2006-04.suse.cz:308443b2-f0e6-465d-8889-ba290efedd58"
        )
      end, [
        @READ,
        {},
        {}
      ], nil)
      DUMP(IscsiServerFunctions.getConfig)
      IscsiServerFunctions.addNewTarget(
        "iqn.2006-04.suse.cz:123456789",
        [{ "KEY" => "Lun", "VALUE" => "2 Path=/tmp/file,Type=fileio" }]
      )
      IscsiServerFunctions.setTargetAuth(
        "iqn.2006-04.suse.cz:123456789",
        ["one two", "three four"],
        "five six"
      )
      TEST(lambda do
        IscsiServerFunctions.saveNewTarget("iqn.2006-04.suse.cz:123456789")
      end, [
        @READ,
        {},
        {}
      ], nil)
      DUMP(IscsiServerFunctions.getConfig)

      nil
    end
  end
end

Yast::ReadConfigClient.new.main
