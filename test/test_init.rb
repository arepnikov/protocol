ENV["TEST_BENCH_DETAIL"] ||= ENV["D"]

puts RUBY_DESCRIPTION

require_relative '../init.rb'
require 'protocol/controls'
Controls = Protocol::Controls

require 'pp'

require 'test_bench'; TestBench.activate
