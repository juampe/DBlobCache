# plugin init file for rails
# this file will be picked up by rails automatically and
# add the dbblobcache extensions to rails

require 'dbblobcache'
#require 'file_column'

ActiveController::Base.send(:include, DBBlobCache)

