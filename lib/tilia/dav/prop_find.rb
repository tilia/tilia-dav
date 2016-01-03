module Tilia
  module Dav
    # This class holds all the information about a PROPFIND request.
    #
    # It contains the type of PROPFIND request, which properties were requested
    # and also the returned items.
    class PropFind
      # A normal propfind
      NORMAL = 0

      # An allprops request.
      #
      # While this was originally intended for instructing the server to really
      # fetch every property, because it was used so often and it's so heavy
      # this turned into a small list of default properties after a while.
      #
      # So 'all properties' now means a hardcoded list.
      ALLPROPS = 1

      # A propname request. This just returns a list of properties that are
      # defined on a node, without their values.
      PROPNAME = 2

      # Creates the PROPFIND object
      #
      # @param string path
      # @param array properties
      # @param int depth
      # @param int request_type
      def initialize(path, properties, depth = 0, request_type = NORMAL)
        @path = path
        @properties = properties
        @depth = depth
        @request_type = request_type
        @result = {}

        if request_type == ALLPROPS
          @properties = [
            '{DAV:}getlastmodified',
            '{DAV:}getcontentlength',
            '{DAV:}resourcetype',
            '{DAV:}quota-used-bytes',
            '{DAV:}quota-available-bytes',
            '{DAV:}getetag',
            '{DAV:}getcontenttype'
          ]
        end

        @properties.each do |property_name|
          # Seeding properties with 404's.
          @result[property_name] = [404, nil]
        end
        @items_left = result.size
      end

      # Handles a specific property.
      #
      # This method checks wether the specified property was requested in this
      # PROPFIND request, and if so, it will call the callback and use the
      # return value for it's value.
      #
      # Example:
      #
      # $propFind->handle('{DAV:}displayname', function() {
      #      return 'hello';
      # });
      #
      # Note that handle will only work the first time. If null is returned, the
      # value is ignored.
      #
      # It's also possible to not pass a callback, but immediately pass a value
      #
      # @param string property_name
      # @param mixed value_or_callback
      # @return void
      def handle(property_name, value_or_callback)
        if @items_left > 0 && @result.key?(property_name) && @result[property_name][0] == 404
          if value_or_callback.is_a?(Proc) || value_or_callback.is_a?(Method)
            value = value_or_callback.call
          else
            value = value_or_callback
          end

          unless value.nil?
            @items_left -= 1
            @result[property_name] = [200, value]
          end
        end
      end

      # Sets the value of the property
      #
      # If status is not supplied, the status will default to 200 for non-null
      # properties, and 404 for null properties.
      #
      # @param string property_name
      # @param mixed value
      # @param int status
      # @return void
      def set(property_name, value, status = nil)
        status = value.nil? ? 404 : 200 if status.nil?

        # If this is an ALLPROPS request and the property is
        # unknown, add it to the result; else ignore it:
        unless @result.key?(property_name)
          @result[property_name] = [status, value] if @request_type == ALLPROPS
          return
        end

        if status != 404 && @result[property_name][0] == 404
          @items_left -= 1
        elsif status == 404 && @result[property_name][0] != 404
          @items_left += 1
        end

        @result[property_name] = [status, value]
      end

      # Returns the current value for a property.
      #
      # @param string property_name
      # @return mixed
      def get(property_name)
        @result.key?(property_name) ? @result[property_name][1] : nil
      end

      # Returns the current status code for a property name.
      #
      # If the property does not appear in the list of requested properties,
      # null will be returned.
      #
      # @param string property_name
      # @return int|null
      def status(property_name)
        @result.key?(property_name) ? @result[property_name][0] : nil
      end

      # Updates the path for this PROPFIND.
      #
      # @param string path
      # @return void
      attr_writer :path

      # Returns the path this PROPFIND request is for.
      #
      # @return string
      attr_reader :path

      # Returns the depth of this propfind request.
      #
      # @return int
      attr_reader :depth

      # Updates the depth of this propfind request.
      #
      # @param int depth
      # @return void
      attr_writer :depth

      # Returns all propertynames that have a 404 status, and thus don't have a
      # value yet.
      #
      # @return array
      def load_404_properties
        return [] if @items_left == 0
        result = []
        @result.each do |property_name, stuff|
          result << property_name if stuff[0] == 404
        end
        result
      end

      # Returns the full list of requested properties.
      #
      # This returns just their names, not a status or value.
      #
      # @return array
      def requested_properties
        @properties
      end

      # Returns true if this was an '{DAV:}allprops' request.
      #
      # @return bool
      def all_props?
        @request_type == ALLPROPS
      end

      # Returns a result array that's often used in multistatus responses.
      #
      # The array uses status codes as keys, and property names and value pairs
      # as the value of the top array.. such as :
      #
      # [
      #  200 => [ '{DAV:}displayname' => 'foo' ],
      # ]
      #
      # @return array
      def result_for_multi_status
        results = {
          200 => {},
          404 => {}
        }
        @result.each do |property_name, info|
          results[info[0]] = {} unless results.key?(info[0])
          results[info[0]][property_name] = info[1]
        end

        results.delete(404) if @request_type == ALLPROPS
        results
      end

      # The path that we're fetching properties for.
      #
      # @var string
      attr_accessor :path

      # The Depth of the request.
      #
      # 0 means only the current item. 1 means the current item + its children.
      # It can also be DEPTH_INFINITY if this is enabled in the server.
      #
      # @var int
      attr_accessor :depth

      # The type of request. See the TYPE constants
      attr_accessor :request_type

      # A list of requested properties
      #
      # @var array
      attr_accessor :properties

      # The result of the operation.
      #
      # The keys in this array are property names.
      # The values are an array with two elements: the http status code and then
      # optionally a value.
      #
      # Example:
      #
      # [
      #    "{DAV:}owner" : [404],
      #    "{DAV:}displayname" : [200, "Admin"]
      # ]
      #
      # @var array
      attr_accessor :result

      # This is used as an internal counter for the number of properties that do
      # not yet have a value.
      #
      # @var int
      attr_accessor :items_left

      def initialize_copy(_original)
        @properties = @properties.deep_dup
        @result = @result.deep_dup
      end
    end
  end
end
