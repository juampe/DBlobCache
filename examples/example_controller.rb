#Exampel controller
class AdminController < ApplicationController

#The controller must to start client binding to drb server (now localhost)
  def initialize
    DRb.start_service
    @dbblobcache = DRbObject.new(nil, "druby://:8880")
    #@dbblobcache = DRbObject.new(nil, "druby://lythty:8880")
  end
  
  #Normal ActiveRecord create/update/destroy use
  def create
    @item = Item.new
    @item.create=(params[:articulo])
    @item.save
    render :action => 'new'
  end

  def update
    @item = Item.find(params[:id])
    render :action => 'edit'
  end

  def destroy
    Item.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

end
