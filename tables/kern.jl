@use "./kerx.jl" take kern_map

struct KernSubtable
  length::UInt16
  format::UInt8
  coverage::UInt8 # coverage flags
  kern_pairs::Dict{Pair{UInt16,UInt16},Int16}
end

struct KernTable
  version::UInt32
  num_tables::UInt32
  subtables::Vector{KernSubtable}
end

parse_kern(file::IO, offset::UInt32) = begin
  seek(file, offset)
  version = take(file, UInt16)
  if version == 0 # opentype format
    num_tables = UInt32(take(file, UInt16))
    subtables = Vector{KernSubtable}(undef, num_tables)
    for i in 1:num_tables
      skip(file, 2)
      subtable_length = take(file, UInt16)
      format = take(file, UInt8)
      @assert format == 0 || format == 2
      coverage = take(file, UInt8) # Coverage flags
      data = parse_subtable(Val(Int(format)), file)
      subtables[i] = KernSubtable(subtable_length, format, coverage, data)
    end
  else # Apple format (AAT)
    skip(file, 2) # apple uses a UInt32
    num_tables = take(file, UInt32)
    coverage = take(file, UInt8)
    format = take(file, UInt8)
    skip(file, 2) # variation tuple index
    @assert format < 4
    subtables = Vector{KernSubtable}(undef, num_tables)
    for i in 1:num_tables
      skip(file, 2)
      subtable_length = take(file, UInt16)
      format = take(file, UInt8)
      @assert format == 0 || format == 2
      coverage = take(file, UInt8) # Coverage flags
      data = parse_subtable(Val(Int(format)), file)
      subtables[i] = KernSubtable(subtable_length, format, coverage, data)
    end
  end
  KernTable(version, num_tables, subtables)
end

parse_subtable(format::Val{0}, file::IO) = begin
  n_pairs = take(file, UInt16)
  skip(file, 6) # ignore search range, entry selector, and range shift
  kern_pairs = Dict{Pair{UInt16,UInt16},Int16}()
  sizehint!(kern_pairs, n_pairs)
  for _ in 1:n_pairs
    left = take(file, UInt16)
    right = take(file, UInt16)
    value = take(file, Int16)
    kern_pairs[left=>right] = value
  end
  kern_pairs
end

# format 1 is very old and not really used any more
parse_subtable(format::Val{1}, file::IO) = begin
  error("TODO: implement state machine parser")
end

# format 2 is very old and not really used any more
parse_subtable(format::Val{2}, file::IO) = begin
  error("TODO: implement format 2 subtables")
end

kern_map(kern::KernTable, chars::Dict{UInt16, Char}) = begin
  map = Dict{Char,Dict{Char,Int16}}()
  for subtable in kern.subtables
    for ((a_index,b_index), value) in subtable.kern_pairs
      haskey(chars, a_index) || continue
      haskey(chars, b_index) || continue
      a = chars[a_index]
      b = chars[b_index]
      submap = get!(Dict{Char,Int16}, map, a)
      submap[b] = value
    end
  end
  map
end
