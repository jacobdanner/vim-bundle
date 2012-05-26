# ! /usr/bin/ruby

require 'net/http'
require 'net/https'
require 'uri'
require 'open-uri'
require 'openssl'
# simple workaround for SSL error 
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
require 'zlib'
require 'fileutils'

bundle_path = File.expand_path "~/.vim/bundle"

# try a simple check, unfortunately this does not always work
# for example RailsInstaller platform is mingw32
if RUBY_PLATFORM.downcase.include?("mswin")
  # This is the default on a gvim install on windows
  bundle_path = File.expand_path "~/vimfiles/bundle"
  #require 'win32/registry'
  #Win32::Registry::HKEY_CURRENT_USER.open(
  #  "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\") do |reg|
  #    proxy_uri = reg.read("ProxyServer")
  #end
end

def usage
  puts "Usage: vim-bundle <command>"
  puts ""
  puts "  list - list all bundles currently installed"
  puts "  install <github user>/<repository name> "
  puts "      installs plugin from github. If no user is specified vim-scripts is used"
  puts "  update <github user>/<repository name> "
  puts "      updates plugin. If no user is specified vim-scripts is used"
end

# TODO: convert this to use OptionParser
if ARGV.first == "list"
  Dir.entries("#{bundle_path}").sort.each  {|dir| puts "#{dir}"}
elsif ARGV.first == "--help" || ARGV.first == "-h" || ARGV.first == "help"
  usage
elsif ARGV.size > 1
  command = ARGV.first
  unless command == "install" || command == "update"
    puts "Invalid command -> #{command}"
    usage
    exit
  end

  split = ARGV[1].split("/")

  if ARGV[2]
    branch = ARGV[2]
  else
    branch = "master"
  end

  if split.size > 1
    plugin_name = split[1]
    download_url = "https://github.com/#{ARGV[1]}/tarball/#{branch}"
  else
    plugin_name = ARGV[1]
    download_url = "https://github.com/vim-scripts/#{ARGV[1]}/tarball/#{branch}"
  end

  plugin_path = bundle_path + "/" + plugin_name
  if command == "update"
    old_plugin_path = plugin_path
    plugin_path += "-new"
  end
  plugin_tar = plugin_path + ".tar"

  if File.exists? File.expand_path(plugin_path)
    puts "Plugin exists #{plugin_path}"
    exit
  end

  # create dir to download to if it does not exist  
  FileUtils.mkdir_p(File.dirname(File.expand_path(plugin_tar)))
  # use open-uri to download tar, this API
  # knows how to work with https, redirection 
  # and proxy information 
  puts ">> Downloading from #{download_url}"
  open(download_url) do |f|
   File.open(plugin_tar,"wb") do |file|
     file.puts f.read
   end
  end

  unless File.exists?(File.expand_path(plugin_tar))
    puts plugin_tar
    puts " Failed to download tar"
    exit
  end

  puts ">> Decompressing plugin to #{plugin_path}"
  if( Dir.mkdir(plugin_path) != 0 )
    puts "could not create #{plugin_path}"
  end

  puts ">> Deleting plugin tarball #{plugin_tar}"
  File.delete(plugin_tar)

  if command == "update"
    puts ">> Removing old plugin"
    FileUtils.rmdir old_plugin_path, :verbose=> true 
    puts ">> Moving new plugin"
    #File.rename plugin_path old_plugin_path
    FileUtils.mv plugin_path old_plugin_path
    puts " #{plugin_name} is now updated!"
  else
    puts " #{plugin_name} is now installed!"
  end
else
  usage
end
