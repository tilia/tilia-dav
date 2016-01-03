class Object
  def scalar?
    is_a?(Numeric) ||
      is_a?(FalseClass) ||
      is_a?(TrueClass) ||
      is_a?(String)
  end
end

module Tilia
  # Load active support core extensions
  require 'active_support'
  require 'active_support/core_ext'

  # Filesystem helpers (for quota)
  require 'sys/filesystem'

  # XML lib
  require 'libxml'

  # Time helper parse('tomorrow')
  require 'chronic'

  # mail helper
  require 'mail'

  # Tilia libraries
  require 'tilia/vobject'
  require 'tilia/event'
  require 'tilia/xml'
  require 'tilia/http'
  require 'tilia/uri'

  module Dav
    # Interfaces
    require 'tilia/dav/i_node'
    require 'tilia/dav/i_collection'
    require 'tilia/dav/i_extended_collection'
    require 'tilia/dav/i_file'
    require 'tilia/dav/i_move_target'
    require 'tilia/dav/i_multi_get'
    require 'tilia/dav/i_properties'
    require 'tilia/dav/i_quota'

    # core components
    require 'tilia/dav/node'
    require 'tilia/dav/collection'
    require 'tilia/dav/exception'
    require 'tilia/dav/file'
    require 'tilia/dav/prop_patch'
    require 'tilia/dav/mk_col'
    require 'tilia/dav/prop_find'
    require 'tilia/dav/server_plugin'
    require 'tilia/dav/server'
    require 'tilia/dav/simple_collection'
    require 'tilia/dav/simple_file'
    require 'tilia/dav/string_util'
    require 'tilia/dav/tree'
    require 'tilia/dav/uuid_util'
    require 'tilia/dav/version'

    # Stuff
    require 'tilia/dav/client'

    # Plugins
    require 'tilia/dav/auth'
    require 'tilia/dav/browser'
    require 'tilia/dav/core_plugin'
    require 'tilia/dav/locks'
    require 'tilia/dav/mount'
    require 'tilia/dav/partial_update'
    require 'tilia/dav/property_storage'
    require 'tilia/dav/sync'
    require 'tilia/dav/temporary_file_filter_plugin'

    # Filesystem examples
    require 'tilia/dav/fs'
    require 'tilia/dav/fs_ext'

    require 'tilia/dav/xml'
  end

  require 'tilia/dav_acl'
  require 'tilia/cal_dav'
  require 'tilia/card_dav'

  class Box
    attr_accessor :value

    def initialize(v = nil)
      @value = v
    end
  end
end
