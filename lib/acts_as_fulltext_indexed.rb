module ActiveRecord
	module Acts #:nodoc:
		module FulltextIndexed #:nodoc:
			def self.included(base)
				base.extend(ClassMethods)  
			end
	      
			module ClassMethods
				def acts_as_fulltext_indexed(fields = [])
					class_inheritable_accessor :aafti_index_fields
					
					aafti_index_fields = fields
					before_destroy :remove_indexes
					after_save :insert_indexes
					has_one :fulltext_index, :as => :indexable
					
					include ActiveRecord::Acts::FulltextIndexed::InstanceMethods
					extend ActiveRecord::Acts::FulltextIndexed::SingletonMethods
				end
				
				def indexed_fields
					if aafti_index_fields.is_a? Array
						return aafti_index_fields
					elsif aafti_index_fields.is_a? Symbol
						return [aafti_index_fields]
					else
						logger.debug "Invalid parameter passed to acts_as_fulltext_indexed. Takes a Symbol or an array of Symbols."
						return []
					end
				end
			end
		
			module SingletonMethods
				def search(tokens, options = {}, transform = true)
					options.assert_valid_keys :conditions, :order, :limit, :include, :origin, :within
					token_list = tokens.strip
					if transform then
						token_list = "+" + tokens.downcase.split(" ").collect {|c| c.strip }.uniq.sort.join("* +") + "*"
					end
					
					conditions = "fulltext_indices.indexable_type = \"#{sanitize_sql self.to_s}\" and MATCH(fulltext_indices.tokens) AGAINST (\"#{sanitize_sql token_list}\" IN BOOLEAN MODE)"
					conditions << " AND #{sanitize_sql(options.delete(:conditions))}" if options[:conditions]
					options[:include] ||= []
					
					valid_keys = [:include, :order, :limit, :offset, :origin, :within]
					options.reject! {|k, v| !valid_keys.include? k }
					options[:include] = [:fulltext_index] + options[:include]
					options[:conditions] = conditions					
					self.find(:all, options)
				end
				
				def insert_indexes
					transaction do
						find(:all).each {|o| o.insert_indexes }
					end
				end
			end
			
			module InstanceMethods
				# Override to build your own index strings
				def build_index_string
					vals = []
					return "" if self.class.indexed_fields.blank?
					self.class.indexed_fields.each do |k|
						vals.push read_attribute(k)
					end
					vals.join(" ")
				end
				
				def insert_indexes
					tokens = build_index_string
					i = FulltextIndex.find_by_indexable_type_and_indexable_id(self.class.to_s, self.id)
					unless i
						i = FulltextIndex.new :indexable_type => self.class.to_s, :indexable_id => self.id, :tokens => tokens
					else
						i.tokens = tokens
					end
					i.save
				end
				
				def remove_indexes
					i = FulltextIndex.find_by_indexable_type_and_indexable_id(self.class.to_s, self.id)
					i.destroy if i
				end				
			end
		end
	end
end

class FulltextIndex < ActiveRecord::Base
	belongs_to :indexable, :polymorphic => true
	
	def FulltextIndex.find_all_matching(tokens, options, transform = true)
		token_list = tokens.strip
		if transform then
			token_list = "+" + tokens.downcase.split(" ").collect {|c| c.strip }.sort.uniq.join("* +") + "*"
		end
		hits = FulltextIndex.find :all, :conditions => ["MATCH(tokens) AGAINST (? IN BOOLEAN MODE)", self.to_s, token_list], :include => [:indexable]
		hits.map &:indexable
	end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::FulltextIndexed)