#!/usr/bin/ruby
require 'erb'
require 'yaml'
require 'digest/md5'
require 'dbi'
require 'drb'
require 'RMagick'

class DBBlobCache
  def initialize
    puts "initialize"
    #Script must be run at the rails root path
    @rails_root=__FILE__.sub!(/vendor\/plugins\/dbblobcache\/.*/,'')
    Dir.chdir(@rails_root)
    #The yalm environment in database.yml
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
      :thumb => "image_thumbnail:150",
      :medium => "image_scale:150x150",
      :hudge => "image_scale:500x500",
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
    cached_file=cache_file(id,tag,extension,date)
    if tag.nil? or tag==''
      file=cached_file[:filename]
    else
      for process in @tags[tag.to_sym].split('+')
        begin
          create=(not File.exists?(cached_file[:tagged_filename])) or (File.stat(cached_file[:tagged_filename]).mtime<date)
        rescue
        end
        if create 
          file=process_file(cached_file[:filename],cached_file[:tagged_filename],process)
	else
	  file=cached_file[:tagged_filename]
        end
      end
    end
    return file.sub(/^#{@store_root}/,'/')
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
      query="select `"+@store_blob+"` from `"+
         @store_table+"` where id='"+id.to_s+"'"
      begin
        sth=@dbh.prepare(query)
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
    end
    return {:filename => filename , :tagged_filename => tagged_filename}
  end
  
  def delete_file(id,extension)
    path=@store_root+@store_directory+build_hash_path(id.to_s+"."+extension)
    for file in Dir.entries(path)
      if file =~ /#{id}[\.-]/
        puts "deleted "+path+file
        File.delete(path+file)
      end
    end
  end
  
  private
  #Process file cached
  def process_file(input,output,process)
    method=process.split(':')
    if method[0]=="image_thumbnail" and method[1] =~ /\d/
      image_thumbnail(input,output,method[1].to_i)
      file=output
    elsif method[0]=="image_scale" and method[1] =~ /\d+x\d+/
      size=method[1].split("x")
      image_resize(input,output,size[0].to_i,size[1].to_i)
      file=output
   elsif method[0]=="image_scale" and method[1] =~ /\d/
      image_resize(input,output,method[1].to_i)
      file=output
   elsif method[0]=="image_crop" and method[1] =~ /\d+x\d+/
      puts "cropping to "+method[1]
    elsif method[0]=="zip" and method[1] =~ /\d/
      puts "compress level to "+method[1]
    else
      file=input
    end
    return file
  end
 
  def image_thumbnail(input,output,x)
    img=Magick::ImageList.new(input)
    Magick::ImageList.new(input).resize(x,(img.rows*x)/img.columns).write(output)
  end
  def image_resize(input,output,ratio)
    img=Magick::ImageList.new(input)
    img.resize(img.columns*ratio,img.rows*ratio).write(output)
  end

  def image_resize(input,output,x,y)
    Magick::ImageList.new(input).resize(x,y).write(output)
  end

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
