module Tilia
  module CalDav
    module Backend
      # Every CalDAV backend must at least implement this interface.
      module SubscriptionSupport
        include BackendInterface

        # Returns a list of subscriptions for a principal.
        #
        # Every subscription is an array with the following keys:
        #  * id, a unique id that will be used by other functions to modify the
        #    subscription. This can be the same as the uri or a database key.
        #  * uri. This is just the 'base uri' or 'filename' of the subscription.
        #  * principaluri. The owner of the subscription. Almost always the same as
        #    principalUri passed to this method.
        #
        # Furthermore, all the subscription info must be returned too:
        #
        # 1. {DAV:}displayname
        # 2. {http://apple.com/ns/ical/}refreshrate
        # 3. {http://calendarserver.org/ns/}subscribed-strip-todos (omit if todos
        #    should not be stripped).
        # 4. {http://calendarserver.org/ns/}subscribed-strip-alarms (omit if alarms
        #    should not be stripped).
        # 5. {http://calendarserver.org/ns/}subscribed-strip-attachments (omit if
        #    attachments should not be stripped).
        # 6. {http://calendarserver.org/ns/}source (Must be a
        #     Sabre\DAV\Property\Href).
        # 7. {http://apple.com/ns/ical/}calendar-color
        # 8. {http://apple.com/ns/ical/}calendar-order
        # 9. {urn:ietf:params:xml:ns:caldav}supported-calendar-component-set
        #    (should just be an instance of
        #    Sabre\CalDAV\Property\SupportedCalendarComponentSet, with a bunch of
        #    default components).
        #
        # @param string principal_uri
        # @return array
        def subscriptions_for_user(principal_uri)
        end

        # Creates a new subscription for a principal.
        #
        # If the creation was a success, an id must be returned that can be used to reference
        # this subscription in other methods, such as updateSubscription.
        #
        # @param string principal_uri
        # @param string uri
        # @param array properties
        # @return mixed
        def create_subscription(principal_uri, uri, properties)
        end

        # Updates a subscription
        #
        # The list of mutations is stored in a Sabre\DAV\PropPatch object.
        # To do the actual updates, you must tell this object which properties
        # you're going to process with the handle method.
        #
        # Calling the handle method is like telling the PropPatch object "I
        # promise I can handle updating this property".
        #
        # Read the PropPatch documenation for more info and examples.
        #
        # @param mixed subscription_id
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_subscription(subscription_id, prop_patch)
        end

        # Deletes a subscription.
        #
        # @param mixed subscription_id
        # @return void
        def delete_subscription(subscription_id)
        end
      end
    end
  end
end
