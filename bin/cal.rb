#!/usr/bin/env ruby
#-*-encoding: utf-8-*-
require_relative "../lib/calour"

puts Calour.new.cal *ARGV.map(&:to_i)
