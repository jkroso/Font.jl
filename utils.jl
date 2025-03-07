"big endian version of read"
take(io, T::Type{<:Integer}) = begin
  out = zero(T)
  for i in sizeof(T):-1:2
    out |= T(read(io, UInt8)) << 8(i-1)
  end
  out|read(io, UInt8)
end
