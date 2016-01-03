module Tilia
  module CalDav
    module Backend
      class MockScheduling < Mock
        include SchedulingSupport

        def initialize(*args)
          super
          @scheduling_objects = {}
        end

        # Returns a single scheduling object.
        #
        # The returned array should contain the following elements:
        #   * uri - A unique basename for the object. This will be used to
        #           construct a full uri.
        #   * calendardata - The iCalendar object
        #   * lastmodified - The last modification date. Can be an int for a unix
        #                    timestamp, or a PHP DateTime object.
        #   * etag - A unique token that must change if the object changed.
        #   * size - The size of the object, in bytes.
        #
        # @param string principal_uri
        # @param string object_uri
        # @return array
        def scheduling_object(principal_uri, object_uri)
          if @scheduling_objects.key?(principal_uri) &&
             @scheduling_objects[principal_uri].key?(object_uri)
            return @scheduling_objects[principal_uri][object_uri]
          else
            return nil
          end
        end

        # Returns all scheduling objects for the inbox collection.
        #
        # These objects should be returned as an array. Every item in the array
        # should follow the same structure as returned from getSchedulingObject.
        #
        # The main difference is that 'calendardata' is optional.
        #
        # @param string principal_uri
        # @return array
        def scheduling_objects(principal_uri)
          if @scheduling_objects.key?(principal_uri)
            return @scheduling_objects[principal_uri].values
          end

          []
        end

        # Deletes a scheduling object
        #
        # @param string principal_uri
        # @param string object_uri
        # @return void
        def delete_scheduling_object(principal_uri, object_uri)
          if @scheduling_objects.key?(principal_uri) &&
             @scheduling_objects[principal_uri].key?(object_uri)
            @scheduling_objects[principal_uri].delete(object_uri)
          end
        end

        # Creates a new scheduling object. This should land in a users' inbox.
        #
        # @param string principal_uri
        # @param string object_uri
        # @param string object_data
        # @return void
        def create_scheduling_object(principal_uri, object_uri, object_data)
          @scheduling_objects[principal_uri] ||= {}

          @scheduling_objects[principal_uri][object_uri] = {
            'uri' => object_uri,
            'calendardata' => object_data,
            'lastmodified' => nil,
            'etag' => "\"#{Digest::MD5.hexdigest(object_data)}\"",
            'size' => object_data.bytesize
          }
        end
      end
    end
  end
end
