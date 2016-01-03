module Tilia
  module CalDav
    # CalendarQuery Validator
    #
    # This class is responsible for checking if an iCalendar object matches a set
    # of filters. The main function to do this is 'validate'.
    #
    # This is used to determine which icalendar objects should be returned for a
    # calendar-query REPORT request.
    class CalendarQueryValidator
      # Verify if a list of filters applies to the calendar data object
      #
      # The list of filters must be formatted as parsed by \Sabre\CalDAV\CalendarQueryParser
      #
      # @param VObject\Component v_object
      # @param array filters
      # @return bool
      def validate(v_object, filters)
        fail ArgumentError, 'Object must be VCalendar' unless v_object.is_a?(VObject::Component::VCalendar)

        # The top level object is always a component filter.
        # We'll parse it manually, as it's pretty simple.
        return false unless v_object.name == filters['name']

        validate_comp_filters(v_object, filters['comp-filters']) &&
          validate_prop_filters(v_object, filters['prop-filters'])
      end

      protected

      # This method checks the validity of comp-filters.
      #
      # A list of comp-filters needs to be specified. Also the parent of the
      # component we're checking should be specified, not the component to check
      # itself.
      #
      # @param VObject\Component parent
      # @param array filters
      # @return bool
      def validate_comp_filters(parent, filters)
        filters.each do |filter|
          is_defined = parent.key?(filter['name'])

          if filter['is-not-defined']
            if is_defined
              return false
            else
              next
            end
          end

          return false unless is_defined

          skip = false
          if filter['time-range'] && filter['time-range'].any?
            parent[filter['name']].each do |sub_component|
              if validate_time_range(sub_component, filter['time-range']['start'], filter['time-range']['end'])
                skip = true
                break
              end
            end
            next if skip

            return false
          end

          next if !filter['comp-filters'] && !filter['prop-filters']

          # If there are sub-filters, we need to find at least one component
          # for which the subfilters hold true.
          parent[filter['name']].each do |sub_component|
            next unless validate_comp_filters(sub_component, filter['comp-filters']) &&
                        validate_prop_filters(sub_component, filter['prop-filters'])
            skip = true
            break
          end
          next if skip

          # If we got here it means there were sub-comp-filters or
          # sub-prop-filters and there was no match. This means this filter
          # needs to return false.
          return false
        end

        # If we got here it means we got through all comp-filters alive so the
        # filters were all true.
        true
      end

      # This method checks the validity of prop-filters.
      #
      # A list of prop-filters needs to be specified. Also the parent of the
      # property we're checking should be specified, not the property to check
      # itself.
      #
      # @param VObject\Component parent
      # @param array filters
      # @return bool
      def validate_prop_filters(parent, filters)
        filters.each do |filter|
          is_defined = parent.key?(filter['name'])

          if filter['is-not-defined']
            if is_defined
              return false
            else
              next
            end
          end

          return false unless is_defined

          skip = false
          if filter['time-range']
            parent[filter['name']].each do |sub_component|
              if validate_time_range(sub_component, filter['time-range']['start'], filter['time-range']['end'])
                skip = true
                break
              end
            end
            next if skip

            return false
          end

          next if !filter['param-filters'] && !filter['text-match']

          # If there are sub-filters, we need to find at least one property
          # for which the subfilters hold true.
          parent[filter['name']].each do |sub_component|
            next unless validate_param_filters(sub_component, filter['param-filters']) &&
                        (!filter['text-match'] || validate_text_match(sub_component, filter['text-match']))
            skip = true
            break
          end
          next if skip

          # If we got here it means there were sub-param-filters or
          # text-match filters and there was no match. This means the
          # filter needs to return false.
          return false
        end

        # If we got here it means we got through all prop-filters alive so the
        # filters were all true.
        true
      end

      # This method checks the validity of param-filters.
      #
      # A list of param-filters needs to be specified. Also the parent of the
      # parameter we're checking should be specified, not the parameter to check
      # itself.
      #
      # @param VObject\Property parent
      # @param array filters
      # @return bool
      def validate_param_filters(parent, filters)
        filters.each do |filter|
          is_defined = parent.key?(filter['name'])

          if filter['is-not-defined']
            if is_defined
              return false
            else
              next
            end
          end

          return false unless is_defined
          next unless filter['text-match']

          # If there are sub-filters, we need to find at least one parameter
          # for which the subfilters hold true.
          skip = false
          parent[filter['name']].parts.each do |param_part|
            next unless validate_text_match(param_part, filter['text-match'])
            skip = true
            break
          end

          next if skip

          # If we got here it means there was a text-match filter and there
          # were no matches. This means the filter needs to return false.
          return false
        end

        # If we got here it means we got through all param-filters alive so the
        # filters were all true.
        true
      end

      # This method checks the validity of a text-match.
      #
      # A single text-match should be specified as well as the specific property
      # or parameter we need to validate.
      #
      # @param VObject\Node|string check Value to check against.
      # @param array text_match
      # @return bool
      def validate_text_match(check, text_match)
        check = check.value if check.is_a?(VObject::Node)

        is_matching = Dav::StringUtil.text_match(check, text_match['value'], text_match['collation'])

        text_match['negate-condition'] ^ is_matching
      end

      # Validates if a component matches the given time range.
      #
      # This is all based on the rules specified in rfc4791, which are quite
      # complex.
      #
      # @param VObject\Node component
      # @param DateTime start
      # @param DateTime end
      # @return bool
      def validate_time_range(component, start, ending)
        start = Time.zone.parse('1900-01-01') unless start
        ending = Time.zone.parse('3000-01-01') unless ending

        case component.name
        when 'VEVENT', 'VTODO', 'VJOURNAL'
          return component.in_time_range?(start, ending)
        when 'VALARM'
          # If the valarm is wrapped in a recurring event, we need to
          # expand the recursions, and validate each.
          #
          # Our datamodel doesn't easily allow us to do this straight
          # in the VALARM component code, so this is a hack, and an
          # expensive one too.
          if component.parent.name == 'VEVENT' && component.parent['RRULE']
            # Fire up the iterator!
            it = VObject::Recur::EventIterator.new(component.parent.parent, component.parent['UID'].to_s)
            while it.valid
              expanded_event = it.event_object

              # We need to check from these expanded alarms, which
              # one is the first to trigger. Based on this, we can
              # determine if we can 'give up' expanding events.
              first_alarm = nil
              if expanded_event['VALARM']
                expanded_event['VALARM'].each do |expanded_alarm|
                  effective_trigger = expanded_alarm.effective_trigger_time
                  return true if expanded_alarm.in_time_range?(start, ending)

                  if expanded_alarm['TRIGGER']['VALUE'].to_s == 'DATE-TIME'
                    # This is an alarm with a non-relative trigger
                    # time, likely created by a buggy client. The
                    # implication is that every alarm in this
                    # recurring event trigger at the exact same
                    # time. It doesn't make sense to traverse
                    # further.
                  else
                    # We store the first alarm as a means to
                    # figure out when we can stop traversing.
                    if !first_alarm || effective_trigger < first_alarm
                      first_alarm = effective_trigger
                    end
                  end
                end
              end

              unless first_alarm
                # No alarm was found.
                #
                # Or technically: No alarm that will change for
                # every instance of the recurrence was found,
                # which means we can assume there was no match.
                return false
              end

              return false if first_alarm > ending

              it.next
            end

            return false
          else
            return component.in_time_range?(start, ending)
          end

        when 'VFREEBUSY'
          fail Dav::Exception::NotImplemented, "time-range filters are currently not supported on #{component.name} components"
        when 'COMPLETED', 'CREATED', 'DTEND', 'DTSTAMP', 'DTSTART', 'DUE', 'LAST-MODIFIED'
          return start <= component.date_time && ending >= component.date_time
        else
          fail Dav::Exception::BadRequest, "You cannot create a time-range filter on a #{component.name} component"
        end
      end
    end
  end
end
