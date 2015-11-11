require 'ostruct'

module JsonApiClientMock
  class MockConnection
    class_attribute :mocks, :auto_generator
    self.mocks = {}

    # ignored
    def initialize(*attrs); end
    def use(*attrs); end
    def delete(*attrs); end

    def execute(query)

      results = find_test_results(query)
      if results
        OpenStruct.new(:body => {
          query.klass.table_name => results[:results],
          "meta" => results[:meta]
        })
      else
        raise MissingMock, missing_message(query)
      end
    end

    def set_test_results(klass, results, conditions = nil, response_meta = {})
      self.class.mocks[klass.name] ||= []
      self.class.mocks[klass.name].unshift({results: results, conditions: conditions, meta: response_meta })
    end

    def clear_test_results
      self.class.mocks = {}
    end

    protected

    def class_mocks(query)
      self.class.mocks.fetch(query.klass.name, [])
    end

    def find_test_results(query)
      class_mocks(query).detect { |mock| mock[:conditions] == query.params } ||
        class_mocks(query).detect { |mock| mock[:conditions] && (mock[:conditions][:path] == query.path) } ||
          class_mocks(query).detect { |mock| mock[:conditions].nil? } ||
            auto_generate(query)
    end

    def auto_generate(query)
      return nil unless auto_generator && auto_generator.respond_to?(:generate)
      generated_results = auto_generator.generate(query)
      if generated_results.present?
        generated_results = HashWithIndifferentAccess.new(generated_results)
        final_result = { :results => generated_results }
        final_result.merge!({:meta => generated_results[:meta]}) if generated_results[:meta].present?
        return final_result
      end
    end

    def missing_message(query)
      ["no test results set for #{query.klass.name} with conditions: #{query.params.pretty_inspect} or for request path #{query.path}",
        "mocks conditions available: #{class_mocks(query).map { |m| m[:conditions] }.pretty_inspect}"].join("\n\n")
    end
  end
end
