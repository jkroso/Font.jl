@use "../utils.jl" take

abstract type KerxSubtable end

struct KerxSubtableFormat0 <: KerxSubtable
  length::UInt32          # Total length of the subtable in bytes
  coverage::UInt32        # Flags and format (format in lower 8 bits)
  tupleCount::UInt32      # Number of tuples (0 for non-variation fonts)
  nPairs::UInt32          # Number of kerning pairs
  searchRange::UInt32     # For binary search optimization
  entrySelector::UInt32   # For binary search optimization
  rangeShift::UInt32      # For binary search optimization
  pairs::Vector{Tuple{UInt16, UInt16, Int16}}  # (left glyph, right glyph, kerning value)
end

struct KerxSubtableFormat1 <: KerxSubtable
  length::UInt32          # Total length of the subtable in bytes
  coverage::UInt32        # Flags and format (format in lower 8 bits)
  tupleCount::UInt32      # Number of tuples (0 for non-variation fonts)
  stateSize::UInt32       # Size of the state table
  classTableOffset::UInt32 # Offset to class table from subtable start
  stateArrayOffset::UInt32 # Offset to state array from subtable start
  entryTableOffset::UInt32 # Offset to entry table from subtable start
  classTable::Vector{UInt8} # Class table data (glyph to class mapping)
  stateArray::Vector{UInt16} # State array data (state transitions)
  entryTable::Vector{UInt16} # Entry table data (actions like kerning values)
end

struct KerxTable
  version::UInt32         # Version in fixed-point format (e.g., 0x00010000 for 1.0)
  nTables::UInt32         # Number of subtables
  subtables::Vector{KerxSubtable}  # Array of subtables
end

parse_kerx(io::IO, offset) = begin
  seek(io, offset)
  # Read the table header
  version = take(io, UInt32)
  nTables = take(io, UInt32)
  subtables = Vector{KerxSubtable}(undef, nTables)
  # Parse each subtable
  for i in 1:nTables
    length = take(io, UInt32)
    coverage = take(io, UInt32)
    tupleCount = take(io, UInt32)
    format = coverage & 0xFF  # Extract format from lower 8 bits
    if format == 0
      # Parse format 0 subtable
      nPairs = take(io, UInt32)
      searchRange = take(io, UInt32)
      entrySelector = take(io, UInt32)
      rangeShift = take(io, UInt32)
      pairs = Vector{Tuple{UInt16, UInt16, Int16}}(undef, nPairs)
      for j in 1:nPairs
        left = take(io, UInt16)
        right = take(io, UInt16)
        value = take(io, Int16)
        pairs[j] = (left, right, value)
      end
      subtables[i] = KerxSubtableFormat0(length, coverage, tupleCount, nPairs, searchRange, entrySelector, rangeShift, pairs)
    elseif format == 1
      # Parse format 1 subtable
      stateSize = take(io, UInt32)
      classTableOffset = take(io, UInt32)
      stateArrayOffset = take(io, UInt32)
      entryTableOffset = take(io, UInt32)

      # Read class table
      seek(io, start_pos + classTableOffset)
      classTableSize = stateArrayOffset - classTableOffset
      classTable = Vector{UInt8}(undef, classTableSize)
      read!(io, classTable)

      # Read state array
      seek(io, start_pos + stateArrayOffset)
      stateArraySize = (entryTableOffset - stateArrayOffset) ÷ 2  # 16-bit entries
      stateArray = Vector{UInt16}(undef, stateArraySize)
      for j in 1:stateArraySize
        stateArray[j] = take(io, UInt16)
      end

      # Read entry table
      seek(io, start_pos + entryTableOffset)
      entryTableSize = (length - (entryTableOffset - 12)) ÷ 2  # Remaining bytes as 16-bit entries
      entryTable = Vector{UInt16}(undef, entryTableSize)
      for j in 1:entryTableSize
        entryTable[j] = take(io, UInt16)
      end

      # Construct the format 1 subtable
      subtables[i] = KerxSubtableFormat1(length, coverage, tupleCount, stateSize,
                                         classTableOffset, stateArrayOffset, entryTableOffset,
                                         classTable, stateArray, entryTable)

      # Move to the end of the subtable
      seek(io, start_pos + length)
    else
      @warn "kerx table format $format not parsed because it's not yet supported"
      skip(io, length - 12)  # 12 bytes already read (length, coverage, tupleCount)
    end
  end
  KerxTable(version, nTables, subtables)
end

kern_map(kern::KerxTable, chars::Dict{UInt16, Char}) = begin
  map = Dict{Char,Dict{Char,Int16}}()
  for subtable in kern.subtables
    kern_map(subtable, chars, map)
  end
  map
end

kern_map(kern::KerxSubtableFormat0, chars::Dict{UInt16, Char}, map::Dict{Char,Dict{Char,Int16}}) = begin
  for (a_index, b_index, value) in kern.pairs
    haskey(chars, a_index) || continue
    haskey(chars, b_index) || continue
    a = chars[a_index]
    b = chars[b_index]
    submap = get!(Dict{Char,Int16}, map, a)
    submap[b] = value
  end
end
