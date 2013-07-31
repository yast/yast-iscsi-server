# encoding: utf-8

module Yast
  class IscsiServerClient < Client
    def main
      # testedfiles: IscsiServer.ycp

      Yast.include self, "testsuite.rb"
      TESTSUITE_INIT([], nil)

      Yast.import "IscsiServer"

      DUMP("IscsiServer::Modified")
      TEST(lambda { IscsiServer.Modified }, [], nil)

      nil
    end
  end
end

Yast::IscsiServerClient.new.main
