class Numeric
  
  # Converts a number to currency. Optionally, it allows localization of currency.
  #
  #   1.5.to_currency #=> "$1.50"
  # 
  # You can also localize the symbol that appears before the number, the 
  # thousands delimiter, the decimal delimiter, and the symbol that appears
  # after the number:
  #   1.5.to_currency nil, ",", ".", "$USD" #=> "1.50$USD"
  #   67_000.5.to_currency nil, ".", ",", "DM" #=> "67.000,50DM"
  def to_currency(pre_symbol='$', thousands=',', decimal='.', post_symbol=nil)
    "#{pre_symbol}#{("%.2f" % self ).gsub(".", decimal).gsub(/(\d)(?=(?:\d{3})+(?:$|[\\#{decimal}]))/,"\\1#{thousands}")}#{post_symbol}"
  end

  # Divides the number by 1,000,000
  # 
  #   2.microseconds #=> 2.0e-06
  def microseconds() Float(self  * (10 ** -6)) end
  # Divides the number by 1,000
  #
  #   2.milliseconds #=> 0.002
  def milliseconds() Float(self  * (10 ** -3)) end
  # Returns the same number as is passed in
  #
  #   2.seconds #=> 2
  def seconds() self end
  # Multiplies the number by 60
  #
  #   2.minutes #=> 120
  def minutes() 60 * seconds end
  # Multiplies the number by 60 minutes
  #
  #   2.hours #=> 7200
  def hours() 60 * minutes end
  # Multiples the number by 24 hours
  #
  #   2.days #=> 172800
  def days() 24 * hours end
  # Multiples the number by 7 days
  #
  #   2.weeks #=> 1209600    
  def weeks() 7 * days end
  # Multiples the number by 30 days
  #
  #   2.months #=> 5184000
  def months() 30 * days end
  # Multiplies the number by 365 days
  #
  #   2.years #=> 63072000
  def years() 365 * days end
  # Multiplies the number by 10 years
  #
  #   2.decades #=> 630720000
  def decades() 10 * years end

  # Each of the time extensions also works in the singular:
  #
  #   1.day #=> 86400
  #   1.hour #=> 3600
  alias_method :microsecond, :microseconds
  alias_method :millisecond, :milliseconds
  alias_method :second, :seconds
  alias_method :minute, :minutes
  alias_method :hour, :hours
  alias_method :day, :days
  alias_method :week, :weeks
  alias_method :month, :months
  alias_method :year, :years
  alias_method :decade, :decades
              
end
