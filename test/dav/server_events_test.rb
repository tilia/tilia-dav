require 'test_helper'

module Tilia
  module Dav
    class ServerEventsTest < AbstractServer
      def test_after_bind
        @server.on('afterBind', method(:after_bind_handler))
        new_path = 'afterBind'

        @handler_string = ''
        @server.create_file(new_path, 'body')
        assert_equal(new_path, @handler_string)
      end

      def after_bind_handler(path)
        @handler_string = path
      end

      def test_after_response
        mock = StdClass.new

        @server.on('afterResponse', mock.method(:after_response_callback))

        @server.http_request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD'    => 'GET',
          'PATH_INFO'         => '/test.txt'
        )

        @server.exec
      end

      def test_before_bind_cancel
        @server.on('beforeBind', method(:before_bind_cancel_handler))
        refute(@server.create_file('bla', 'body'))

        # Also testing put
        req = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'      => '/barbar'
        )

        @server.http_request = req
        @server.exec

        assert_equal(nil, @server.http_response.status)
      end

      def before_bind_cancel_handler(_path)
        false
      end

      def test_exception
        @server.on('exception', method(:exception_handler))

        req = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'GET',
          'PATH_INFO'      => '/not/exisitng'
        )
        @server.http_request = req
        @server.exec

        assert_kind_of(Exception::NotFound, @exception)
      end

      def exception_handler(exception)
        @exception = exception
      end

      def test_method
        k = 1

        @server.on(
          'method',
          lambda do |_request, _response|
            k += 1
            return false
          end
        )

        @server.on(
          'method',
          lambda do |_request, _response|
            k += 2
            return false
          end
        )

        @server.invoke_method(
          Http::Request.new('BLABLA', '/'),
          Http::Response.new,
          false
        )

        assert_equal(2, k)
      end
    end
  end
end

class StdClass
  def after_response_callback(_request, _response)
    fail 'already run' if @run
    @run = true
  end
end
