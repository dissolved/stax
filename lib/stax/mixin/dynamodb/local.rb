require 'json'

module Stax
  module DynamoDB

    ## monkey-patch this method to apply any app-specific changes to payload
    ## args: logical_id, payload hash
    ## returns: new payload
    def dynamo_local_payload_hacks(id, payload)
      payload
    end

  end

  module Cmd
    class DynamoDB < SubCommand

      no_commands do

        ## client for dynamodb-local endpoint on given port
        def client(port)
          @_client ||= ::Aws::DynamoDB::Client.new(endpoint: "http://localhost:#{port}")
        end

        ## get CFN template and return hash of table configs
        def dynamo_local_tables
          JSON.parse(my.cfn_template).fetch('Resources', {}).select do |_, v|
            v['Type'] == 'AWS::DynamoDB::Table'
          end
        end

        ## convert some CFN properties to their SDK equivalents
        def dynamo_payload_from_template(id, template)
          template['Properties'].tap do |p|
            p['TableName'] ||= id # use logical id if no name in template
            p['StreamSpecification']&.merge!( 'StreamEnabled' => true )
            p['SSESpecification'] &&= { 'Enabled' => p.dig('SSESpecification', 'SSEEnabled') }
            p.delete('TimeToLiveSpecification')
            p.delete('Tags')
          end
        end

        ## convert property names to ruby SDK form
        def dynamo_ruby_payload(payload)
          payload&.deep_transform_keys do |key|
            key.to_s.underscore.to_sym
          end
        end

        ## create table
        def dynamo_local_create(payload, port)
          client(port).create_table(dynamo_ruby_payload(payload))
        rescue ::Aws::DynamoDB::Errors::ResourceInUseException => e
          warn(e.message)       # table exists
        rescue Seahorse::Client::NetworkingError => e
          warn(e.message)       # dynamodb-local probably not running
        end
      end

      desc 'local-create', 'create local tables from template'
      method_option :tables,  aliases: '-t', type: :array,   default: nil,   desc: 'filter table ids'
      method_option :payload, aliases: '-p', type: :boolean, default: false, desc: 'just output payload'
      method_option :port, aliases: '-P', type: :numeric, default: 8000, desc: 'local dynamo port'
      def local_create
        tables = dynamo_local_tables
        tables.slice!(*options[:tables]) if options[:tables]

        tables.each do |id, value|
          payload = dynamo_payload_from_template(id, value)
          payload = my.dynamo_local_payload_hacks(id, payload) # apply user-supplied hacks
          if options[:payload]
            puts JSON.pretty_generate(payload)
          else
            puts "create table #{id}"
            dynamo_local_create(payload, options[:port])
          end
        end
      end

      desc 'local-delete', 'delete local tables from template'
      method_option :tables,  aliases: '-t', type: :array, default: nil, desc: 'filter table ids'
      method_option :port, aliases: '-P', type: :numeric, default: 8000, desc: 'local dynamo port'
      def local_delete
        tables = dynamo_local_tables
        tables.slice!(*options[:tables]) if options[:tables]

        tables.each do |id,_value|
          puts "deleting table #{id}"
          client(options[:port]).delete_table(table_name: id)
        end
      end
    end
  end
end
