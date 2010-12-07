class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :topic_tag_map
  belongs_to :vocabulary

  # Parse a text string into an array of tokens for use as tags
  def self.parse(list)
    tag_names = []
    
    return tag_names if list.blank?
    
    # first, pull out the quoted tags
    list.gsub!(/\"(.*?)\"\s*/) { tag_names << $1; "" }
    
    # then, replace all commas with a space
    list.gsub!(/,/, " ")
    
    # then, get whatever is left
    tag_names.concat(list.split(/\s/))
    
    # delete any blank tag names
    tag_names = tag_names.delete_if { |t| t.empty? }
    
    # downcase all tags
    tag_names = tag_names.map! { |t| t.downcase }
    
    # remove duplicates
    tag_names = tag_names.uniq
    
    return tag_names
  end
  
  # Tag a taggable with this tag, optionally add user to add owner to tagging
  def tag(taggable, user_id = nil)
    taggings.create :taggable => taggable, :user_id => user_id
    taggings.reset
    @tagged = nil
  end
  
  # A list of all the objects tagged with this tag
  def tagged
    @tagged ||= taggings.collect(&:taggable)
  end
  
  def tagged_auth(user)
    tagged.select do |taggable|
      Authorization.is_authorized?('view', nil, taggable, user)
    end
  end

  def public?
    tagged_auth(nil).length > 0
  end

  # Compare tags by name
  def ==(comparison_object)
    super || name == comparison_object.to_s
  end
  
  # Return the tag's name
  def to_s
    name
  end

  # returns a list of taggings sorted by popularity of the tag
  def self.find_by_tag_count(limit = 25, type = nil)

    sql  = 'SELECT popular_tags.* FROM (SELECT tags.id, tags.name, COUNT(*) AS taggings_count FROM taggings INNER JOIN tags ON taggings.tag_id = tags.id'
    args = []

    if type
      sql  += ' WHERE (taggings.taggable_type = ?)'
      args += [type]
    end

    sql += ' GROUP BY name ORDER BY taggings_count DESC'

    unless limit.nil?
      sql  += ' LIMIT ?'
      args += [limit]
    end

    sql += ') AS popular_tags ORDER BY name ASC'

    Tag.find_by_sql([sql] + args)
  end

  validates_presence_of :name
end
