# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
use Raindrops::Middleware
use Rack::UTF8Sanitizer
run Whitehall::Application
