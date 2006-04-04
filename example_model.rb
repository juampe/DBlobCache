#example
#Weh need to store the blob and the date
class Item < ActiveRecord::Base 
  def create=(item)
    self.name = item['nombre']
    self.description = item['descripcion']
    self.extension = item['image'].original_filename.match(/(\w+)$/)[0]
    self.mime = item['image'].content_type.chomp
    self.image = item['imagen'].read
    self.date = Time.now
  end

  def update=(item)
    self.name = item['nombre']
    self.description = item['descripcion']
    if item.include?('image') and articulo['imagen'] != ""
      self.extension = item['image'].original_filename.match(/(\w+)$/)[0]
      self.mime = item['image'].content_type.chomp
      self.image = item['imagen'].read
      self.date = Time.now
    end
  end
end


