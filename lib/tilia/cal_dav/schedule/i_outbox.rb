module Tilia
  module CalDav
    module Schedule
      # Implement this interface to have a node be recognized as a CalDAV scheduling
      # outbox.
      module IOutbox
        include Dav::ICollection
        include DavAcl::IAcl
      end
    end
  end
end
