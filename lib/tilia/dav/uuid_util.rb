module Tilia
  module Dav
    # UUID Utility
    #
    # This class has static methods to generate and validate UUID's.
    # UUIDs are used a decent amount within various *DAV standards, so it made
    # sense to include it.
    class UuidUtil
      # Returns a pseudo-random v4 UUID
      #
      # This function is based on a comment by Andrew Moore on php.net
      #
      # @see http://www.php.net/manual/en/function.uniqid.php#94959
      # @return string
      def self.uuid
        format('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
               # 32 bits for "time_low"
               rand(0..0xffff), rand(0..0xffff),

               # 16 bits for "time_mid"
               rand(0..0xffff),

               # 16 bits for "time_hi_and_version",
               # four most significant bits holds version number 4
               rand(0..0x0fff) | 0x4000,

               # 16 bits, 8 bits for "clk_seq_hi_res",
               # 8 bits for "clk_seq_low",
               # two most significant bits holds zero and one for variant DCE1.1
               rand(0..0x3fff) | 0x8000,

               # 48 bits for "node"
               rand(0..0xffff), rand(0..0xffff), rand(0..0xffff))
      end

      # Checks if a string is a valid UUID.
      #
      # @param string $uuid
      # @return bool
      def self.validate_uuid(uuid)
        uuid =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
      end
    end
  end
end
