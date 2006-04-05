#!/usr/bin/ruby
require 'erb'
require 'yaml'
require 'digest/md5'
require "dbi"
require 'drb'

class DBBlobCache
  def initialize
    #Script must be run at the rails root oath
    @rails_root=__FILE__.sub!(/vendor\/plugins\/dbblobcache\/.*/,'')
    #@base=__FILE__.sub!(/lib\/.*/,'')
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
      @@dbh = DBI.connect(connect_string, config[env]['username'], config[env]['password'])
    rescue DBI::DatabaseError => e
      puts "Error  #{e.err} #{e.errstr}"
    ensure
        # disconnect from server
      @dbh.disconnect if @dbh
    end
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
    filename=@store_root+@store_directory+build_hash_path(id.to_s+"."+extension)+id.to_s+tag+"."+extension
    puts filename
    begin
      #The cache logic
      retrieve=(not File.exists?(filename)) or (File.stat(fullaname).mtime<date)
    rescue
    end
    if retrieve
    	#puts "cache miss "+id.to_s
        query="select "	+@store_blob+" from "+
	    @store_table+" where id='"+id.to_s+"'"
	begin
	  sth=@@dbh.prepare(query)
	  sth.execute
	  row=sth.fetch
	  blob=row.by_field(@store_blob)
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
    else
      #puts "cache hit "+id.to_s
    end
    filename.sub!(/^public/,'')
    return filename
  end
  
  def delete_file(id,tag,extension)
    filename=@store_root+@store_directory+build_hash_path(id.to_s+tag+"."+extension)+id.to_s+tag+"."+extension
    File.delete(filename)
  end
  
  private
  def full_mkdir(dir)
    Dir.chdir(@rails_root+@store_root)
    dir.split('/').each {
      |mkdir|
      begin
        Dir.chdir(mkdir)
        Dir.mkdir(mkdir) if not File.exist?(mkdir)
      rescue
      end
      puts Dir.pwd
    }
    Dir.chdir(@rails_root)
  end

  def build_hash_path(name)
    hash=Digest::MD5.hexdigest(name)
    dir=hash[0,1]+"/"+hash[0,2]
    full_mkdir(@store_directory+dir)
    puts "build hash "+@store_directory+dir
    return dir+"/"
  end
end
