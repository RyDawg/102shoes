class Shoes < Application
  before :basic_authentication, :exclude => [:index, :show, :about]
  provides :xml, :js, :yaml
  
  def index
    @shoes = Shoe.all
    render @shoes
  end
  
  def show(id)
    @shoe = Shoe[id]
    raise NotFound unless @shoe
    render @shoe, :layout => :none
  end
  
  def about
    render
  end
  
  def new
    only_provides :html
    @shoe = Shoe.new
    render @shoe
  end
  
  def create(shoe)
    @shoe = Shoe.new(shoe)
    if @shoe.save
      FileUtils.mv(@shoe.image[:tempfile].path, Merb.root+"/public/images/shoes/#{@shoe.id}.jpg") unless @shoe.image.blank?
      redirect url(:shoes, @shoe)
    else
      render :action => :new
    end
  end
  
  def edit(id)
    only_provides :html
    @shoe = Shoe[id]
    raise NotFound unless @shoe
    render
  end
  
  def update(id, shoe)
    @shoe = Shoe.find(id)
    raise NotFound unless @shoe
    if @shoe.update_attributes(shoe)
      FileUtils.mv(@shoe.image[:tempfile].path, Merb.root+"/public/images/shoes/#{id}.jpg") unless @shoe.image.blank?
      redirect url(:shoe, @shoe)
    else
      raise BadRequest
    end
  end
  
  def destroy(id)
    @shoe = Shoe[id]
    raise NotFound unless @shoe
    if @shoe.destroy!
      redirect url(:shoes)
    else
      raise BadRequest
    end
  end
end