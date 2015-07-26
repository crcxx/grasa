#!/usr/bin/env ruby
require 'rubygems'

# stdlib
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'set'

REQUIRED_OPTIONS = [:access_list, :file]
OPTIONAL_OPTIONS = [:dir, :network, :network_group, :service, :service_group]

# local classes
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'grasar'

options = {}
begin
  optparse = OptionParser.new do |opts|
    opts.banner = <<-TXT
Author:
  Craig Chaney

Purpose:
  Convert ASA (9.1) config into easily greppable format

Examples:

  See README.md

Usage: grasa.rb [options]
    TXT
    opts.on(:REQUIRED, "--file", "Location of ASA config") do |o|
      # set path here as libs may not in same location
      options[:file] = File.expand_path(o)
    end

    opts.on(:OPTIONAL, "--access-list", "(Optional - requires --dir) Access list name to parse") do |o|
      options[:access_list] = o
    end

    opts.on(:OPTIONAL, "--dir", "(Optional - requires --access-list) Directory for greppable output") do |o|
      # set path here as libs are not in same location
      options[:dir] = File.expand_path(o)
    end

    opts.on(:OPTIONAL, "--network", "(Optional) Print corresponding network object to STDOUT") do |o|
      options[:network] = o
    end

    opts.on(:OPTIONAL, "--network-group", "(Optional) Print corresponding network group to STDOUT") do |o|
      options[:network_group] = o
    end

    opts.on(:OPTIONAL, "--service", "(Optional) Print corresponding service object to STDOUT") do |o|
      options[:service] = o
    end

    opts.on(:OPTIONAL, "--service-group", "(Optional) Print corresponding service group to STDOUT") do |o|
      options[:service_group] = o
    end
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end
  optparse.parse!

  if options[:file].nil?
    puts "Config file required!"
    exit
  else
    if options[:access_list] or options[:dir]
      if options[:access_list] and options[:dir]
        parser = Grasar.new(options[:file])
        parser.convert(options[:access_list], options[:dir])
      else
        puts "Both --access_list and --dir are required!"
        exit
      end
    elsif options[:network]
      parser = Grasar.new(options[:file])
      output = parser.get_network_object(options[:network])
      output.each {|o| puts o}
    elsif options[:network_group]
      parser = Grasar.new(options[:file])
      output = parser.get_network_object_group(options[:network_group])
      output.each {|o| puts o}
    elsif options[:service]
      parser = Grasar.new(options[:file])
      output = parser.get_service_object(options[:service])
      output.each {|o| puts o}
    elsif options[:service_group]
      parser = Grasar.new(options[:file])
      output = parser.get_service_object_group(options[:service_group])
      output.each {|o| puts o}
    else
      parser = Grasar.new(options[:file])
      output = parser.list_ace_names
      if output.length > 0
        puts 'Access Lists Available'
        output.each {|o| puts " #{o}"}
      end
    end
  end

rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

