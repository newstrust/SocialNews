module ObjectHelpers
  def self.marshal(h)
    Marshal.dump(h).unpack("H*")[0] 
  end

  def self.unmarshal(v)
    Marshal.load([v].pack("H*"))
  end

  # Since there is no standard way to really implement deep cloning, the easiest way is to marshal and unmarshal the object
  def self.deep_clone(o)
    case o
      when Hash
        klone = o.clone
        o.each {|k,v| klone[k] = deep_clone(v) }
      when Array
        klone = o.clone
        klone.clear
        o.each {|v| klone << deep_clone(v)}
      when Fixnum,Bignum,Float,NilClass,FalseClass,TrueClass,Continuation
        klone = o
      else
        klone = unmarshal(marshal(o))
    end
    klone
  end
end
