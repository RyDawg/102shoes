class Symbol  
  # ["foo", "bar"].map &:reverse #=> ['oof', 'rab']
  def to_proc
     Proc.new{|*args| args.shift.__send__(self, *args)}
   end
end