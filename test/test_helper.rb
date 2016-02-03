require 'simplecov'
require 'minitest/autorun'
require 'yaml'
require 'sequel'

# Extend the assertions
require 'minitest/assertions'
module Minitest
  module Assertions
    def assert_xml_equal(expected, actual, message = nil)
      assert(
        Hash.from_xml(actual) == Hash.from_xml(expected),
        message || ">>> expected:\n#{expected}\n<<<\n>>> got:\n#{actual}\n<<<"
      )
    end

    def assert_instance_equal(expected, actual, message = nil)
      assert(
        compare_instances(expected, actual),
        message || ">>> expected:\n#{expected.inspect}\n<<<\n>>> got:\n#{actual.inspect}\n<<<"
      )
    end

    def assert_has_key(key, hash, message = nil)
      assert(
        hash.key?(key),
        message || "expected #{hash.inspect} to have key #{key.inspect}"
      )
    end

    def assert_v_object_equals(expected, actual, message = nil)
      get_obj = lambda do |input|
        input = input.read if input.respond_to?(:read)

        input = Tilia::VObject::Reader.read(input) if input.is_a?(String)

        unless input.is_a?(Tilia::VObject::Component)
          fail ArgumentError, 'Input must be a string, stream or VObject component'
        end

        input.delete('PRODID')
        if input.is_a?(Tilia::VObject::Component::VCalendar) && input['CALSCALE'].to_s == 'GREGORIAN'
          input.delete('CALSCALE')
        end
        input
      end

      assert_equal(
        get_obj.call(expected).serialize,
        get_obj.call(actual).serialize,
        message
      )
    end

    private

    def compare_instances(a, b)
      return true if b.__id__ == a.__id__

      # check class
      return false unless a.class == b.class

      # Instance variables should be the same
      return false unless a.instance_variables.sort == b.instance_variables.sort

      # compare all instance variables
      a.instance_variables.each do |var|
        if a.instance_variable_get(var) == a
          # Referencing self
          return false unless b.instance_variable_get(var) == b
        else
          return false unless a.instance_variable_get(var) == b.instance_variable_get(var)
        end
      end
      true
    end
  end
end

module Tilia
  module TestUtil
    def self.sqlite
      db = Sequel.sqlite
      db.pragma_set('case_sensitive_like', false) # true seems to be default
      db
    end

    def self.mysql
      config = database_config

      database = config.delete(:database)
      begin
        sequel = Sequel.mysql2(database, config)
      rescue
        skip('could not connect to mysql database')
      end

      sequel
    end

    def self.mysql_engine
      config = database_config

      config[:engine].blank? ? '' : "ENGINE=#{config[:engine]}"
    end

    def self.database_config
      database_file = File.join(File.dirname(__FILE__), '..', 'database.yml')
      skip('could not load database file for mysql database') unless File.exist?(database_file)

      begin
        YAML.load(File.read(database_file))
      rescue
        skip('database.yml is invalid')
      end
    end

    def self.mock_rack_env(plus = {})
      env = Rack::MockRequest.env_for
      env.delete('PATH_INFO') # seems like PHP path info is empty
      env.merge plus
    end
  end
end

require 'tilia/dav'

require 'base64'
require 'digest'
require 'fileutils'
require 'stringio'
require 'uri'

require 'http/response_mock'
require 'http/sapi_mock'

require 'dav/client_mock'
require 'dav/abstract_server'
require 'dav/auth/backend/abstract_sequel_test'
require 'dav/auth/backend/mock'
require 'dav/server_mock'
require 'dav_server_test'
require 'dav/locks/backend/abstract_test'
require 'dav/locks/backend/mock'
require 'dav/mock/file'
require 'dav/mock/collection'
require 'dav/mock/properties_collection'
require 'dav/mock/streaming_file'
require 'dav/partial_update/file_mock'
require 'dav/property_storage/backend/abstract_sequel_test'
require 'dav/property_storage/backend/mock'
require 'dav/sync/mock_sync_collection'
require 'dav/test_plugin'
require 'dav/xml/xml_tester'

require 'dav_acl/principal_backend/mock'
require 'dav_acl/mock_acl_node'
require 'dav_acl/mock_principal'
require 'dav_acl/principal_backend/abstract_sequel_test'

require 'cal_dav/backend/mock'
require 'cal_dav/backend/mock_scheduling'
require 'cal_dav/backend/mock_sharing'
require 'cal_dav/backend/mock_subscription_support'
require 'cal_dav/schedule/i_mip/mock_plugin'
require 'cal_dav/test_util'
require 'cal_dav/backend/abstract_sequel_test'
require 'cal_dav/backend/sequel_sqlite_test'

require 'card_dav/backend/abstract_sequel_test'
require 'card_dav/backend/mock'
require 'card_dav/test_util'
require 'card_dav/abstract_plugin_test'
require 'card_dav/backend/sequel_sqlite_test'

Time.zone = 'UTC'
