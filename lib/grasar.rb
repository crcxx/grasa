#!/usr/bin/env ruby
require 'rubygems'

# stdlib
require 'fileutils'
require 'optparse'
require 'ostruct'
require 'set'


class Grasar
  DEBUG = false

  def initialize(config_file)
    if File.exist? config_file
      @config_file = config_file
    else
      raise "Config file does not exist: #{config_file}"
    end
    @count = 0
  end

  def list_ace_names
    names = Set.new
    open(@config_file) do |f|
      f.grep(/^access-list/).each do |g|
        fields = g.split(' ')
        fields.shift # remove 'access-list'
        names.add fields.shift
      end
    end
    names
  end

  def convert(ace_name, output_dir)
    open(@config_file) do |f|
      f.grep(/^access-list/).each do |g|
        if g.include? ace_name
          fields = g.split(' ')
          fields.shift # remove 'access_list'
          access_list_name = fields.shift
          param = fields.shift

          param.match(/extended/) do |m|
            access_list_condition = fields.shift
            proto_arg = get_proto_arg(fields)
            # puts proto_arg.inspect
            src_arg = get_srcdst_arg(fields)
            # puts src_arg.inspect
            dst_arg = get_srcdst_arg(fields)
            # puts dst_arg.inspect

            output(output_dir, access_list_name, g, access_list_condition, proto_arg, src_arg, dst_arg, fields)
          end
        end
      end
    end

  end

  def get_proto_arg(fields)
    # Protocol—The protocol_argument specifies the IP protocol:
    # – name or number —Specifies the protocol name or number. Specify ip to apply to all protocols.
    #
    # – object-group protocol_grp_id —Specifies a protocol object group created using the object-group protocol command.
    #
    # – object service_obj_id —Specifies a service object created using the object service command. A TCP, UDP, or ICMP service object can include a protocol and a source and/or destination port or ICMP type and code.
    #
    # – object-group service_grp_id— Specifies a service object group created using the object-group service command.

    proto_arg = Set.new
    keyword = fields.shift

    if keyword == 'object'
      # – object service_obj_id —Specifies a service object created using the object service command. A TCP, UDP, or ICMP service object can include a protocol and a source and/or destination port or ICMP type and code.
      name = fields.shift
      proto_arg.merge(get_service_object(name))
    elsif keyword == 'object-group'
      # – object-group protocol_grp_id —Specifies a protocol object group created using the object-group protocol command.
      # – object-group service_grp_id— Specifies a service object group created using the object-group service command.
      name = fields.shift
      proto_arg.merge(get_service_object_group(name))
    else
      # – name or number —Specifies the protocol name or number. Specify ip to apply to all protocols.
      puts "get_proto_arg - keyword: #{keyword} fields: #{fields.inspect}" if DEBUG
      proto_arg.add(keyword)
    end

    proto_arg
  end

  def get_service_object(name)
    # service { protocol | { icmp | icmp6 } [ icmp-type [ icmp_code ]] | { tcp | udp } [ source operator port ] [ destination operator port ]}

    obj_name = "object service #{name}"
    keywords = %w(service)
    obj = get_object(obj_name, keywords)
    service_object = Set.new

    obj.each do |o|
      parts = o.split(' ')
      # puts "get_service_object: #{o}"
      keyword=parts.shift
      if keyword == 'service'
        if parts[0].to_s == 'tcp' or parts[0].to_s == 'udp'
          # service  { tcp | udp } [ source operator port ] [ destination operator port ]
          puts "service-object (t/u): #{o}" if DEBUG
          service_object.add(parts.join(' '))
        elsif parts[0].to_s == 'icmp' or parts[0].to_s == 'icmp6'
          # service { icmp | icmp6 } [ icmp-type [ icmp_code ]]
          puts "service-object (icmp): #{o}" if DEBUG
          service_object.add(parts.join(' '))
        else
          # service protocol
          puts "service-object (proto): #{o}" if DEBUG
          service_object.add("#{parts.join(' ')} (protocol)")
        end
      end
    end
    service_object
  end

  def get_network_object(name)
    # { host ip_addr | subnet net_addr net_mask | range ip_addr_1 ip_addr_2 | fqdn fully_qualified_domain_name }

    obj_name = "object network #{name}"
    keywords = %w(host subnet range fqdn)
    obj = get_object(obj_name, keywords)
    network_object = Set.new

    obj.each do |o|
      parts = o.split(' ')
      puts "get_network_object: #{o}" if DEBUG
      keyword=parts.shift
      if keyword == 'host'
        # host ip_addr
        network_object.add(parts[0])
      elsif keyword == 'subnet'
        # subnet net_addr net_mask
        network_object.add("#{parts[0]}/#{parts[1]}")
      elsif keyword == 'range'
        # range ip_addr_1 ip_addr_2
        network_object.add("#{parts[0]}-#{parts[1]}")
      elsif keyword == 'fqdn'
        # fqdn fully_qualified_domain_name
        network_object.add("#{parts.join(' ')} (fqdn)")
      else
        puts "***UNKNOWN*** get_network_object - keyword: #{keyword} parts: #{parts.inspect} -- PLEASE REPORT"
      end
    end
    network_object
  end

  def get_service_object_group(name)
    obj_name = "object-group service #{name}"
    keywords = %w(service-object group-object)
    service_object_group=Set.new
    obj = get_object(obj_name, keywords)

    obj.each do |o|
      parts = o.split(' ')
      keyword=parts.shift

      if keyword == 'service-object'
        if parts[0].to_s == 'object'
          # service-object object name
          puts "service-object (object): #{o}" if DEBUG
          service_object_group.merge(get_service_object(parts[1]))
        elsif parts[0].to_s == 'tcp' or parts[0].to_s == 'udp' or parts[0].to_s == 'tcp-udp'
          # service-object { tcp | udp | tcp-udp } [ source operator number ] [ destination operator number ]
          puts "service-object (t/u/tu): #{o}" if DEBUG
          service_object_group.add(parts.join(' '))
        elsif parts[0].to_s == 'icmp' or parts[0].to_s == 'icmp6'
          # service-object { icmp | icmp6 } [ icmp_type [ icmp_code ]]
          puts "service-object (icmp): #{o}" if DEBUG
          service_object_group.add(parts.join(' '))
        else
          # service-object protocol
          puts "service-object (proto): #{o}" if DEBUG
          service_object_group.add(parts.join(' '))
        end
      elsif keyword == 'group-object'
        # group-object group_id
        service_object_group.merge(get_service_object_group(parts[0].to_s))
      else
        puts "***UNKNOWN*** get_service_object_group - keyword: #{keyword} parts: #{parts.inspect} -- PLEASE REPORT"
      end
    end
    service_object_group
  end

  def get_network_object_group(name)
    obj_name = "object-group network #{name}"
    keywords = %w(network-object group-object)
    network_object_group=Set.new
    obj = get_object(obj_name, keywords)

    obj.each do |o|
      parts = o.split(' ')
      keyword=parts.shift

      if keyword == 'network-object'
        param = parts.shift
        if param == 'object'
          # network-object object name
          puts "network-object (object): #{o}" if DEBUG
          name = parts.shift
          network_object_group.merge(get_network_object(name))
        elsif param == 'host'
          # network-object { host ipv4_address | ipv4_address mask | ipv6-address / prefix-length }
          puts "network-object (host): #{o}" if DEBUG
          network_object_group.add(parts.join(' '))
        end
      elsif keyword == 'group-object'
        # group-object group_id
        name = parts.shift
        network_object_group.merge(get_network_object_group(name))
      else
        puts "***UNKNOWN*** get_network_object_group - keyword: #{keyword} parts: #{parts.inspect} -- PLEASE REPORT"
      end
    end
    network_object_group
  end

  def get_srcdst_arg(fields)
    # Source Address, Destination Address—The source_address_argument specifies the IP address or FQDN from which the packet is being sent, and the dest_address_argument specifies the IP address or FQDN to which the packet is being sent:
    # – host ip_address —Specifies an IPv4 host address.
    #
    # – dest_ip_address mask —Specifies an IPv4 network address and subnet mask.
    #
    # – ipv6-address / prefix-length —Specifies an IPv6 host or network address and prefix.
    #
    # – any , any4 , and any6 — any specifies both IPv4 and IPv6 traffic; any4 specifies only IPv4 traffic; and any6 specifies any6 traffic.
    #
    # – object nw_obj_id —Specifies a network object created using the object network command.
    #
    # – object-group nw_grp_id —Specifies a network object group created using the object-group network command.

    srcdst_arg = Set.new
    keyword = fields.shift
    if keyword == 'host'
      # – host ip_address —Specifies an IPv4 host address.
      name = fields.shift
      srcdst_arg.add(name)
    elsif keyword == 'any' or keyword == 'any4' or keyword == 'any6'
      # – any , any4 , and any6 — any specifies both IPv4 and IPv6 traffic; any4 specifies only IPv4 traffic; and any6 specifies any6 traffic.
      srcdst_arg.add(keyword)
    elsif keyword == 'object'
      # – object nw_obj_id —Specifies a network object created using the object network command.
      name = fields.shift
      srcdst_arg.merge(get_network_object(name))
    elsif keyword == 'object-group'
      # – object-group nw_grp_id —Specifies a network object group created using the object-group network command.
      name = fields.shift
      srcdst_arg.merge(get_network_object_group(name))
    else
      # – dest_ip_address mask —Specifies an IPv4 network address and subnet mask.
      # – ipv6-address / prefix-length —Specifies an IPv6 host or network address and prefix.

      puts "***UNKNOWN*** get_srcdst_arg - keyword: #{keyword} parts: #{parts.inspect} -- PLEASE REPORT"
      # srcdst_arg.add(fields.join)
    end
    srcdst_arg.to_a
  end

  def get_object(obj_name, keywords)
    # name: object-group network GRP-12345
    # keywords: %w(network-object group-object)
    obj = Set.new
    File.open(@config_file) do |f|
      found_object = false
      f.each_line do |line|
        if line.chomp == obj_name
          found_object = true
        elsif line.start_with?(' ')
          # only add interested keywords
          obj.add(line) if keywords.detect { |d| line.start_with? " #{d}" } if found_object
        else
          found_object = false
        end
      end
    end
    obj
  end

  def output(output_dir, access_list_name, line, access_list_condition, proto_arg, src_arg, dst_arg, fields)
    proto_arg.flatten!
    src_arg.flatten!
    dst_arg.flatten!
    line.chomp!

    FileUtils::mkdir_p output_dir
    @count += 1
    File.open("#{output_dir}/#{access_list_name}_#{access_list_condition}_#{@count.to_s.rjust(5, '0')}", "w") do |file|
      file.puts "#{line} -- START"
      proto_arg.each { |p| file.puts " protocol: #{p}" }

      src_arg.each do |s|
        file.puts "source: #{s}\tdestination: #{dst_arg.join(',')}\t#{fields.join(' ')}"
      end
      file.puts "#{line} -- END"
    end
  end
end