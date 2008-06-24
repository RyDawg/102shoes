class Shoe < DataMapper::Base
  attr_accessor :image
  property :title, :string
  property :description, :text
  property :price_rating, :integer
  property :comfort_rating, :integer
  property :style_rating, :integer
  property :link, :string
  property :price, :decimal
  property :created_at, :datetime
  
  def src
    "/images/shoes/#{id}.jpg"
  end
end

