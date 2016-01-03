module Tilia
  module CalDav
    module Notifications
      # This node represents a list of notifications.
      #
      # It provides no additional functionality, but you must implement this
      # interface to allow the Notifications plugin to mark the collection
      # as a notifications collection.
      #
      # This collection should only return Sabre\CalDAV\Notifications\INode nodes as
      # its children.
      module ICollection
        include Dav::ICollection
      end
    end
  end
end
