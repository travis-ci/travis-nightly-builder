lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'travis'

use Rack::Static, urls: ['/js', '/css', '/favicon.ico', '/img'], root: 'public'

run Travis::NightlyBuilder::App
