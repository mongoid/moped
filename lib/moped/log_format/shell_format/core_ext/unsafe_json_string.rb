class UnsafeJSONString < String
  def to_json(*args)
    to_s
  end
end