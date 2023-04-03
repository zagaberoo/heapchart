require 'bundler/setup'

require 'bcrypt'
require 'date'
require 'erb'
require 'pg'
require 'sequel'
require 'sinatra'
require 'sqlite3'
require 'thin'
require 'toml'

Dir.chdir(File.dirname(__FILE__))

require_relative 'lib/init'
require_relative 'lib/render/admin'
require_relative 'lib/render/floor'
require_relative 'lib/render/library'
