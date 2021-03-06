module Helpers
  module GraphQuery
    extend ActiveSupport::Concern

    def request_graph_query(query, variables: {}, is_admin: false)
      response = GraphSchema.execute(query, {
        variables: variables.deep_stringify_keys,
        context: { is_admin: is_admin },
        only: GraphWhitelist
      })

      response.with_indifferent_access
    end
  end
end

RSpec.configuration.include(Helpers::GraphQuery, :graph_request)
