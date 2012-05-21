# ! /usr/bin/ruby

require 'net/http'
require 'net/https'
require 'uri'
require 'open-uri'
require 'zlib'


http_proxy_env = "http_proxy"

proxy_uri=nil
proxy_user=nil
proxy_pass=nil
proxy_host=nil
proxy_port=nil

if RUBY_PLATFORM.downcase.include?("mswin")
  # This is the default on a gvim install on windows
  bundle_path = File.expand_path "~/vimfiles/bundle"
  
  require 'win32/registry'
  Win32::Registry::HKEY_CURRENT_USER.open(
    "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\") do |reg|
      proxy_uri = reg.read("ProxyServer")
    end
else
  bundle_path = File.expand_path "~/.vim/bundle"
end

# if the env var for proxy has been set use that, 
# otherwise use windows registry
if(ENV.has_key? http_proxy_env)
  proxy_uri = ENV[http_proxy_env]
#  proxy_user, proxy_pass = uri.userinfo.split(/:/) if proxy_uri.userinfo
#  proxy_host = proxy_uri.host if proxy_uri.host
#  proxy_port = proxy_uri.port if proxy_uri.port
end

def usage
  puts "Usage: vim-bundle <command>"
  puts ""
  puts "  \033[36mlist \033[0m- list all bundles currently installed"
  puts "  \033[36minstall <github user>/<repository name> "
  puts "      \033[0m installs plugin from github. If no user is specified vim-scripts is used"
  puts "  \033[36mupdate <github user>/<repository name> "
  puts "      \033[0m updates plugin. If no user is specified vim-scripts is used"
end

# from the ruby-doc std-lib example
def fetch(uri_str, proxy_uri = nil, limit = 10)
  # You should choose a better exception.
  raise ArgumentError, 'too many HTTP redirects' if limit == 0

  puts "proxy_uri -> #{proxy_uri}"
  # use proxy if it exists
  if(proxy_uri)

    p_uri = URI.parse(proxy_uri)    
    puts "P_URI -> #{p_uri}"
    p_user = nil
    p_pass = nil
    p_user, p_pass = p_uri.userinfo.split(/:/) if p_uri.userinfo
    response = Net::HTTP::Proxy(p_uri.host, p_uri.port, p_user, p_pass).get_response(URI(uri_str))
  else
    response= Net::HTTP.get_response(URI(uri_str))
  end
  #http_access.use_ssl true
  #response = http_access.get_response(URI(uri_str))

  case response
  when Net::HTTPSuccess then
    response
  when Net::HTTPRedirection then
    location = response['location']
    warn "redirected to #{location}"
    fetch(location, proxy_uri, limit - 1)
  else
    response
  end
end


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

  puts "#{download_url}"
  res = fetch(download_url, proxy_uri)
  puts "#{res}"
  if res.code != 200
    puts "Download failed with status #{res.code} for URL:"
    puts download_url
    exit()
  end

  puts ">> Downloading from #{download_url}"
  open(download_url) do |f|
   File.open(plugin_tar,"wb") do |file|
     file.puts f.read
   end
  end

#  `wget -q -O #{plugin_tar} #{download_url}`

  unless File.exists?(File.expand_path(plugin_tar))
    puts plugin_tar
    puts "\033[31mFailed to download tar"
    exit
  end

  puts ">> Decompressing plugin to #{plugin_path}"
  if( Dir.mkdir(plugin_path) != 0 )
    puts "could not create #{plugin_path}"
  end

  
  File.delete(plugin_tar)
#  `mkdir #{plugin_path} && 
#  ##tar -C #{plugin_path} -xzvf #{plugin_tar}
#  #--strip-components=1 &&
#  #rm #{plugin_tar}`

  if command == "update"
    puts ">> Removing old plugin"
    File.new(old_plugin_path).delete("*")
    Dir.delete old_plugin_path
    puts ">> Moving new plugin"
    File.rename plugin_path old_plugin_path
    puts "\033[32m#{plugin_name} is now updated!"
  else
    puts "\033[32m#{plugin_name} is now installed!"
  end
else
  usage
end
