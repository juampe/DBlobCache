#!/usr/bin/ruby
require "active_record"
module LocalDBBlobCache 
  def self.append_features(base)
    super
    base.extend(ClassMethods)
  end
  module ClassMethods
    def dbblobcache
      class_eval do
        extend LocalDBBlobCache::SingletonMethods
      end
    end
  end
  module SingletonMethods
    def dbblobcache()
    end
  end
end

ActiveRecord::Base.class_eval do
      include LocalDBBlobCache
end
