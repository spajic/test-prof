# frozen_string_literal: true

require "test_prof/ext/float_duration"
require 'pry'

module TestProf::FactoryProf
  module Printers
    module Spajic # :nodoc: all
      class << self
        using TestProf::FloatDuration
        include TestProf::Logging

        def dump(result, start_time:)
          return log(:info, "No factories detected") if result.raw_stats == {}

          stats = result.stats
          just_stacks = result.stacks.map {|el| el[:stack]}
          print_simple_report(stats, start_time: start_time)

          speedscope = build_report_from_stacks(just_stacks)
          path = 'tmp/test_prof/stackprof.json'
          log :info, "Writing the report to #{path}..."
          File.write(path, speedscope.to_json)

          print_my_super_report(result.stacks, stats)

          log :info, "Launching Speedscope.app"
          `speedscope #{path}`
        end

        # for top-10 factories show top-10 locations
        def print_my_super_report(stacks_with_locations, stats)
          top_10_factories =
            stats
              .sort_by {|stat| -stat[:total_time]}
              .take(10)
              .map{|stat| stat[:name]}

          top_10_factories.each_with_index do |factory, factory_index|
            target_factory = factory
            report = {}
            stacks_with_locations.each do |el|
              stack = el[:stack]
              location = el[:location]
              target_count = stack.count {|el| el == target_factory}
              next if target_count == 0

              report[location] ||= 0
              report[location] += target_count
            end

            sorted = report.to_a.sort_by {|loc, count| -count}
            sum = sorted.sum {|loc, count| count}
            top_sum = sorted.first(10).sum {|loc, count| count}

            puts "\n🇹🇷🇹🇷🇹🇷  Top-#{factory_index+1}: #{target_factory} 🇹🇷🇹🇷🇹🇷"
            puts "#{(100.0 * top_sum / sum).round}% potential in top-10 specs (#{top_sum} / #{sum})"
            puts "#{target_factory} creation by location:"
            sorted
              .first(10)
              .each_with_index {|el, index| puts "#{el[1]} => #{el[0]}"}
          end
        end

        def print_simple_report(stats, start_time:)
          msgs = []

          total_run_time = TestProf.now - start_time
          total_count = stats.sum { |stat| stat[:total_count] }
          total_top_level_count = stats.sum { |stat| stat[:top_level_count] }
          total_time = stats.sum { |stat| stat[:top_level_time] }
          total_uniq_factories = stats.map { |stat| stat[:name] }.uniq.count

          msgs <<
            <<~MSG
              Factories usage

               Total: #{total_count}
               Total top-level: #{total_top_level_count}
               Total time: #{total_time.duration} (out of #{total_run_time.duration})
               Total uniq factories: #{total_uniq_factories}

                 total time    time per 1000    total   top-level       top-level time               name
            MSG

          stats.sort_by! {|stat| -stat[:total_time]}
          stats.first(10).each do |stat|
            msgs <<
              format(
                "%17.4fs %13.4fs %8d %11d %18.4fs %18s",
                stat[:total_time],
                1000 * stat[:top_level_time] / stat[:top_level_count],
                stat[:total_count],
                stat[:top_level_count],
                stat[:top_level_time],
                stat[:name]
              )
          end

          log :info, msgs.join("\n")
        end

        def build_report_from_stacks(stacks)
          stacks_with_number_of_reps = stacks.tally
          total_stacks = stacks_with_number_of_reps.values.sum
          unique_factories = stacks_with_number_of_reps.keys.flatten.uniq

          frames = {}
          unique_factories.each_with_index do |factory_name, index|
            frames[index.to_s] = {'name' => factory_name}
          end
          factories_ids = frames.invert.transform_keys { |name_factory| name_factory['name'] }

          raw = []
          stacks_with_number_of_reps.each do |stack, reps|
            raw << stack.size
            stack.each { |factory| raw << factories_ids[factory] }
            raw << reps
          end

          {
            version: 1.2,
            mode: 'wall',
            frames: frames,
            raw: raw,
            raw_sample_timestamps: [1] * total_stacks,
            raw_timestamp_deltas: [1000] * total_stacks
          }
        end
      end
    end
  end
end
