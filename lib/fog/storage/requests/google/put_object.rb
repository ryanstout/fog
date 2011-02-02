module Fog
  module Google
    class Storage
      class Real

        # Create an object in an Google Storage bucket
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket to create object in
        # * object_name<~String> - Name of object to create
        # * data<~File> - File or String to create object from
        # * options<~Hash>:
        #   * 'Cache-Control'<~String> - Caching behaviour
        #   * 'Content-Disposition'<~String> - Presentational information for the object
        #   * 'Content-Encoding'<~String> - Encoding of object data
        #   * 'Content-Length'<~String> - Size of object in bytes (defaults to object.read.length)
        #   * 'Content-MD5'<~String> - Base64 encoded 128-bit MD5 digest of message (defaults to Base64 encoded MD5 of object.read)
        #   * 'Content-Type'<~String> - Standard MIME type describing contents (defaults to MIME::Types.of.first)
        #   * 'x-goog-acl'<~String> - Permissions, must be in ['private', 'public-read', 'public-read-write', 'authenticated-read']
        #   * "x-goog-meta-#{name}" - Headers to be returned with object, note total size of request without body must be less than 8 KB.
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * headers<~Hash>:
        #     * 'ETag'<~String> - etag of new object
        def put_object(bucket_name, object_name, data, options = {})
          data = parse_data(data)
          headers = data[:headers].merge!(options)
          request({
            :body       => data[:body],
            :expects    => 200,
            :headers    => headers,
            :host       => "#{bucket_name}.#{@host}",
            :idempotent => true,
            :method     => 'PUT',
            :path       => CGI.escape(object_name)
          })
        end

      end

      class Mock

        def put_object(bucket_name, object_name, data, options = {})
          acl = options['x-goog-acl'] || 'private'
          if !['private', 'public-read', 'public-read-write', 'authenticated-read'].include?(acl)
            raise Excon::Errors::BadRequest.new('invalid x-goog-acl')
          else
            @data[:acls][:object][bucket_name] ||= {}
            @data[:acls][:object][bucket_name][object_name] = self.class.acls(acl)
          end

          data = parse_data(data)
          unless data[:body].is_a?(String)
            data[:body] = data[:body].read
          end
          response = Excon::Response.new
          if (bucket = @data[:buckets][bucket_name])
            response.status = 200
            object = {
              :body           => data[:body],
              'Content-Type'  => options['Content-Type'] || data[:headers]['Content-Type'],
              'ETag'          => Fog::Google::Mock.etag,
              'Key'           => object_name,
              'LastModified'  => Fog::Time.now.to_date_header,
              'Size'          => options['Content-Length'] || data[:headers]['Content-Length'],
              'StorageClass'  => 'STANDARD'
            }

            for key, value in options
              case key
              when 'Cache-Control', 'Content-Disposition', 'Content-Encoding', 'Content-MD5', 'Expires', /^x-goog-meta-/
                object[key] = value
              end
            end

            bucket[:objects][object_name] = object
            response.headers = {
              'Content-Length'  => object['Size'],
              'Content-Type'    => object['Content-Type'],
              'ETag'            => object['ETag'],
              'Last-Modified'   => object['LastModified']
            }
          else
            response.status = 404
            raise(Excon::Errors.status_error({:expects => 200}, response))
          end
          response
        end

      end
    end
  end
end