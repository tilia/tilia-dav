module Tilia
  module CalDav
    module Xml
      module Property
        # Invite property
        #
        # This property encodes the 'invite' property, as defined by
        # the 'caldav-sharing-02' spec, in the http://calendarserver.org/ns/
        # namespace.
        class Invite
          include Tilia::Xml::Element

          # @!attribute [r] users
          #   @!visibility private
          #   The list of users a calendar has been shared to.
          #
          #   @var array

          # @!attribute [r] organizer
          #   @!visibility private
          #   The organizer contains information about the person who shared the
          #   object.
          #
          #   @var array

          # Creates the property.
          #
          # Users is an array. Each element of the array has the following
          # properties:
          #
          #   * href - Often a mailto: address
          #   * commonName - Optional, for example a first and lastname for a user.
          #   * status - One of the SharingPlugin::STATUS_* constants.
          #   * readOnly - true or false
          #   * summary - Optional, description of the share
          #
          # The organizer key is optional to specify. It's only useful when a
          # 'sharee' requests the sharing information.
          #
          # The organizer may have the following properties:
          #   * href - Often a mailto: address.
          #   * commonName - Optional human-readable name.
          #   * firstName - Optional first name.
          #   * lastName - Optional last name.
          #
          # If you wonder why these two structures are so different, I guess a
          # valid answer is that the current spec is still a draft.
          #
          # @param array users
          def initialize(users, organizer = nil)
            @users = users
            @organizer = organizer
          end

          # Returns the list of users, as it was passed to the constructor.
          #
          # @return array
          def value
            @users
          end

          # The xmlSerialize metod is called during xml writing.
          #
          # Use the writer argument to write its own xml serialization.
          #
          # An important note: do _not_ create a parent element. Any element
          # implementing XmlSerializble should only ever write what's considered
          # its 'inner xml'.
          #
          # The parent of the current element is responsible for writing a
          # containing element.
          #
          # This allows serializers to be re-used for different element names.
          #
          # If you are opening new elements, you must also close them again.
          #
          # @param Writer writer
          # @return void
          def xml_serialize(writer)
            cs = "{#{Plugin::NS_CALENDARSERVER}}"

            if @organizer
              writer.start_element(cs + 'organizer')
              writer.write_element('{DAV:}href', @organizer['href'])

              unless @organizer['commonName'].blank?
                writer.write_element(cs + 'common-name', @organizer['commonName'])
              end
              unless @organizer['firstName'].blank?
                writer.write_element(cs + 'first-name', @organizer['firstName'])
              end
              unless @organizer['lastName'].blank?
                writer.write_element(cs + 'last-name', @organizer['lastName'])
              end

              writer.end_element #  organizer
            end

            @users.each do |user|
              writer.start_element(cs + 'user')
              writer.write_element('{DAV:}href', user['href'])

              unless user['commonName'].blank?
                writer.write_element(cs + 'common-name', user['commonName'])
              end

              case user['status']
              when SharingPlugin::STATUS_ACCEPTED
                writer.write_element(cs + 'invite-accepted')
              when SharingPlugin::STATUS_DECLINED
                writer.write_element(cs + 'invite-declined')
              when SharingPlugin::STATUS_NORESPONSE
                writer.write_element(cs + 'invite-noresponse')
              when SharingPlugin::STATUS_INVALID
                writer.write_element(cs + 'invite-invalid')
              end

              writer.start_element(cs + 'access')
              if user['readOnly']
                writer.write_element(cs + 'read')
              else
                writer.write_element(cs + 'read-write')
              end
              writer.end_element # access

              unless user['summary'].blank?
                writer.write_element(cs + 'summary', user['summary'])
              end

              writer.end_element # user
            end
          end

          # The deserialize method is called during xml parsing.
          #
          # This method is called statictly, this is because in theory this method
          # may be used as a type of constructor, or factory method.
          #
          # Often you want to return an instance of the current class, but you are
          # free to return other data as well.
          #
          # You are responsible for advancing the reader to the next element. Not
          # doing anything will result in a never-ending loop.
          #
          # If you just want to skip parsing for this element altogether, you can
          # just call reader.next
          #
          # reader.parse_inner_tree will parse the entire sub-tree, and advance to
          # the next element.
          #
          # @param Reader reader
          # @return mixed
          def self.xml_deserialize(reader)
            cs = "{#{Plugin::NS_CALENDARSERVER}}"

            users = []

            reader.parse_inner_tree.each do |elem|
              next unless elem['name'] == cs + 'user'

              user = {
                'href'       => nil,
                'commonName' => nil,
                'readOnly'   => false,
                'summary'    => nil,
                'status'     => nil
              }

              elem['value'].each do |user_elem|
                case user_elem['name']
                when cs + 'invite-accepted'
                  user['status'] = SharingPlugin::STATUS_ACCEPTED
                when cs + 'invite-declined'
                  user['status'] = SharingPlugin::STATUS_DECLINED
                when cs + 'invite-noresponse'
                  user['status'] = SharingPlugin::STATUS_NORESPONSE
                when cs + 'invite-invalid'
                  user['status'] = SharingPlugin::STATUS_INVALID
                when '{DAV:}href'
                  user['href'] = user_elem['value']
                when cs + 'common-name'
                  user['commonName'] = user_elem['value']
                when cs + 'access'
                  user_elem['value'].each do |access_href|
                    if access_href['name'] == cs + 'read'
                      user['readOnly'] = true
                    end
                  end
                when cs + 'summary'
                  user['summary'] = user_elem['value']
                end
              end

              unless user['status']
                fail ArgumentError, 'Every user must have one of cs:invite-accepted, cs:invite-declined, cs:invite-noresponse or cs:invite-invalid'
              end

              users << user
            end

            new(users)
          end
        end
      end
    end
  end
end
