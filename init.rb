require 'acts_as_fulltext_indexed'
ActiveRecord::Base.send(:include, ActiveRecord::Acts::FulltextIndexed)

#require File.dirname(__FILE__) + '/lib/tagging'
#require File.dirname(__FILE__) + '/lib/tag'
