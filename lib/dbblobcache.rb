#!/usr/bin/ruby
require 'erb'
require 'yaml'
require 'digest/md5'
require "dbi"
require 'drb'

class DBBlobCache
  def initialize
    puts "initialize"
    #Script must be run at the rails root path
    @rails_root=__FILE__.sub!(/vendor\/plugins\/dbblobcache\/.*/,'')
    Dir.chdir(@rails_root)
    #The yalm enviroment in database.yml
    env="dbblobcache"
    config=YAML::load(ERB.new(File.open(@rails_root+"config/database.yml").read).result)
    @store_root=config[env]['root']
    @store_directory=config[env]['directory']
    @store_table=config[env]['table']
    @store_blob=config[env]['blob']
    begin
      #connect to the MySQL server
      connect_string="dbi:"+config[env]['adapter']+":"+config[env]['database']+":"+config[env]['host']+":"+config[env]['port'].to_s
      @dbh = DBI.connect(connect_string, config[env]['username'], config[env]['password'])
    rescue DBI::DatabaseError => e
      puts "Error  #{e.err} #{e.errstr}"
    end
    #Set default tags
    @tags={
      :thumb => "image_scale:64x64",
      :medium => "image_scale:150x150",
      :medium => "image_scale:500x500",
      :zip => "compress_zip:3",
      :utf8 => "text_encode:utf8"
    }
  end
  
  def set_tags(tags)
    @tags=tags 
  end
	  
  def destructor
    puts "destructor"
    @dbh.disconnect if @dbh
  end
  
  #id to database table 
  #tag is for future image resizing tag
  #extension ins the extension of the image due to mime
  #date is the date of last change in database
  def get_image(id,tag,extension,date)
    return get_file(id,tag,extension,date)
  end
  
  def get_file(id,tag,extension,date)
    cached_file=self.cache_file(id,tag,extension,date)
    if tag.nil? or tag==''
      return cached_file[:filename].sub(/^public/,'')
    end
    for process in @tags[tag.to_sym].split('+')
      method=process.split(':')
      begin
        puts "create"
        create=(not File.exists?(cached_file[:tagged_filename])) or (File.stat(cached_file[:tagged_filename]).mtime<date)
      rescue
      end
      if create
        if method[0]=="image_scale"
          puts "scaling to "+method[1]
	  begin
	    file=File.open(cached_file[:tagged_filename],"w")
	    file.write(File.open(cached_file[:filename]).read)
	    file.close
	  rescue
	  end
        elsif method[0]=="image_crop"
          puts "cropping to "+method[1]
        elsif method[0]=="zip"
          puts "compress level to "+method[1]
        end
      end
    end
    puts cached_file[:tagged_filename].sub(/^public/,'')
    return cached_file[:tagged_filename].sub(/^public/,'')
  end

  
  #id to databse table definede en database.yml
  #tag is a label to
  def cache_file(id,tag,extension,date)
    hash=build_hash_path(id.to_s+"."+extension)
    filename=@store_root+@store_directory+hash+id.to_s+"."+extension
    tagged_filename=@store_root+@store_directory+hash+id.to_s+"-"+tag+"."+extension
    begin
      #The cache logic
      retrieve=(not File.exists?(filename)) or (File.stat(fillename).mtime<date)
    rescue
    end
    if retrieve
      puts "retrieve"
      query="select "+@store_blob+" from "+
         @store_table+" where id='"+id.to_s+"'"
      begin
        puts "blob   eeeeeeees"
        sth=@dbh.prepare(query)
	puts "blob       dssssssssss"
        sth.execute
        row=sth.fetch
        blob=row.by_field(@store_blob)
	puts "blob"
      rescue DBI::DatabaseError => e
        puts "Error #{e.err} #{e.errstr}"
      end
	#puts "caching "+blob.size.to_s
      begin
        file=File.new(filename,"w")
        file.write(blob)
        file.close
      rescue
      end
    end
    return {:filename => filename , :tagged_filename => tagged_filename}
  end
  
  def delete_file(id,extension)
    filepath=@store_root+@store_directory+build_hash_path(id.to_s+"."+extension)
    for file in Dir.entries(filepath)
#      if file.match(#{id.to_s+tag+"."+extension})
#        File.delete(filename)
#       end
    end
  end
  
  private
  def full_mkdir(dir)
    Dir.chdir(@rails_root+@store_root)
    for mkdir  in dir.split('/')
      begin
        Dir.mkdir(mkdir) if not File.exist?(mkdir)
	Dir.chdir(mkdir)
      rescue
      end
    end
    Dir.chdir(@rails_root)
  end

  def build_hash_path(name)
    hash=Digest::MD5.hexdigest(name)
    dir=hash[0,1]+"/"+hash[0,2]
    full_mkdir(@store_directory+dir)
    return dir+"/"
  end
end
