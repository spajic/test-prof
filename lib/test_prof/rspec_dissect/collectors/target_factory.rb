# frozen_string_literal: true

require "test_prof/rspec_dissect/collectors/base"
require 'pry'

module TestProf
  module RSpecDissect
    module Collectors # :nodoc: all
      class TargetFactory < Base
        def initialize(**params)
          @target_factory = params.fetch(:target_factory)
          super(name: :target_factory, **params)
        end

        def populate!(data)
          super
          data[:let_calls] = RSpecDissect.meta_for(name)
        end

        def print_results
          # return unless RSpecDissect.memoization_available?
          super
        end

        def print_group_result(group)
          # return super unless RSpecDissect.config.let_stats_enabled?
          msgs = [super]
            .group_by(&:itself)
            .map { |id, calls| [id, -calls.size] }
            .sort_by(&:last)
            .take(RSpecDissect.config.let_top_count)
            .each do |(id, size)|
            msgs << " ↳ #{id} – #{-size}\n"
          end
          msgs.join
        end
      end
    end
  end
end
