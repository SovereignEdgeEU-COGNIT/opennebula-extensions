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
require 'resolv'

require 'geocoder'
require 'opennebula'
include OpenNebula

one_auth = File.read("#{Dir.home}/.one/one_auth").chomp
client = Client.new(one_auth, 'http://localhost:2633/RPC2')

xml = REXML::Document.new(Base64.decode64(ARGV[0]))

host = Host.new_with_id(xml.elements['HOST/ID'].text, client)

rc = host.info
raise rc.message if OpenNebula.is_error?(rc)

coordinates = Geocoder.coordinates(Resolv.getaddress(host.name))
geolocation = "GEOLOCATION=\"#{coordinates.first},#{coordinates.last}\""

rc = host.update(geolocation, true)
raise rc.message if OpenNebula.is_error?(rc)
