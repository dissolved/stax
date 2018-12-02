module Stax
  class Stack < Base

    no_commands do
      def class_name
        @_class_name ||= self.class.to_s.split('::').last.downcase
      end

      def stack_name
        @_stack_name ||= stack_prefix + class_name
      end

      ## list of other stacks we need to reference
      def stack_imports
        self.class.instance_variable_get(:@imports)
      end

      def stack_type
        self.class.instance_variable_get(:@type)
      end

      def exists?
        Aws::Cfn.exists?(stack_name)
      end

      def stack_status
        Aws::Cfn.describe(stack_name).stack_status
      end

      def stack_notification_arns
        Aws::Cfn.describe(stack_name).notification_arns
      end

      def resource(id)
        Aws::Cfn.id(stack_name, id)
      end
    end

    desc 'exists', 'test if stack exists'
    def exists
      puts exists?
    end

  end
end