#!/usr/bin/env ruby

ONE_LOCATION = ENV['ONE_LOCATION']

if !ONE_LOCATION
    RUBY_LIB_LOCATION = '/usr/lib/one/ruby'
    GEMS_LOCATION     = '/usr/share/one/gems'
else
    RUBY_LIB_LOCATION = ONE_LOCATION + '/lib/ruby'
    GEMS_LOCATION     = ONE_LOCATION + '/share/gems'
end

if File.directory?(GEMS_LOCATION)
    real_gems_path = File.realpath(GEMS_LOCATION)
    if !defined?(Gem) || Gem.path != [real_gems_path]
        $LOAD_PATH.reject! {|l| l =~ /vendor_ruby/ }
        require 'rubygems'
        Gem.use_paths(real_gems_path)
    end
end

$LOAD_PATH << RUBY_LIB_LOCATION

require 'base64'
require 'rexml/document'
require 'ipaddr'
require 'open3'
require 'json'

require 'geocoder'
require 'opennebula'
include OpenNebula

def public_ip?(ip)
    ip_obj = IPAddr.new(ip)

    # Check if IPv4 address
    if ip_obj.ipv4?
        private_ranges = [
            IPAddr.new('10.0.0.0/8'),
            IPAddr.new('172.16.0.0/12'),
            IPAddr.new('192.168.0.0/16'),
            IPAddr.new('127.0.0.1/8')
        ]
    # Check if IPv6 address
    elsif ip_obj.ipv6?
        private_ranges = [
            IPAddr.new('fc00::/7'),       # Unique local address
            IPAddr.new('fe80::/10'),      # Link-local address
            IPAddr.new('::1'),            # Loopback address
            IPAddr.new('::ffff:0:0/96'),  # IPv4-mapped IPv6 addresses
            IPAddr.new('::/96')           # IPv4-compatible IPv6 addresses
        ]
    else
        return false # Not a valid IP address
    end

    # Check if the IP address is in private ranges
    private_ranges.none? {|range| range.include?(ip_obj) }
end

one_auth = File.read("#{Dir.home}/.one/one_auth").chomp
client = Client.new(one_auth, 'http://localhost:2633/RPC2')

xml = REXML::Document.new(Base64.decode64(ARGV[0]))

host = Host.new_with_id(xml.elements['HOST/ID'].text, client)

rc = host.info
raise rc.message if OpenNebula.is_error?(rc)

#################################################################

cmd = "ssh #{host.name} ip --json -brief address show"
ips, e, s = Open3.capture3(cmd)

raise e if s != 0

public_ips = []

JSON.parse(ips).each do |ip|
    next if ip['addr_info'].empty? || !ip['addr_info'][0].key?('local')

    address = ip['addr_info'][0]['local']

    public_ips << address if public_ip?(address)
end

if public_ips.empty?
    puts "No coordinates detected for host #{host.name}"
    exit 0
end

geolocations = []

public_ips.each do |ip|
    coordinates = Geocoder.coordinates(ip)
    coordinates = "#{coordinates.first},#{coordinates.last}"

    geolocations << coordinates unless geolocations.include?(coordinates)
end

geolocation = "GEOLOCATION=\"#{geolocations.join(' ')}\""

#################################################################

if !geolocation.empty?
    rc = host.update(geolocation, true)
    raise rc.message if OpenNebula.is_error?(rc)
else
    puts "No coordinates detected for host #{host.name}"
end
