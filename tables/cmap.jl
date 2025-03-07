@use "../utils.jl" take

struct CmapSubtableHeader
  platformID::UInt16
  encodingID::UInt16
  offset::UInt32
end

struct CmapFormat0
  language::UInt16
  glyphIdArray::Vector{UInt8}  # length 256
end

struct CmapFormat4
  length::UInt16
  language::UInt16
  segCount::UInt16
  searchRange::UInt16
  entrySelector::UInt16
  rangeShift::UInt16
  endCode::Vector{UInt16}
  startCode::Vector{UInt16}
  idDelta::Vector{Int16}
  idRangeOffset::Vector{UInt16}
  glyphIdArray::Vector{UInt16}
end

struct CmapFormat6
  length::UInt16
  language::UInt16
  firstCode::UInt16
  entryCount::UInt16
  glyphIdArray::Vector{UInt16}
end

struct CmapFormat12Group
  startCharCode::UInt32
  endCharCode::UInt32
  startGlyphID::UInt32
end

struct CmapFormat12
  language::UInt32
  groups::Vector{CmapFormat12Group}
end

struct DefaultUVSRange
  startUnicodeValue::UInt32  # 24-bit value stored as UInt32
  additionalCount::UInt8
end

struct NonDefaultUVSMapping
  unicodeValue::UInt32  # 24-bit value stored as UInt32
  glyphID::UInt16
end

mutable struct VariationSelectorRecord
  varSelector::UInt32  # 24-bit value stored as UInt32
  defaultUVSOffset::UInt32
  nonDefaultUVSOffset::UInt32
  defaultUVS::Vector{DefaultUVSRange}
  nonDefaultUVS::Vector{NonDefaultUVSMapping}
end

struct CmapFormat14
  length::UInt32
  numVarSelectorRecords::UInt32
  varSelectorRecords::Vector{VariationSelectorRecord}
end

struct CmapSubtable
  platformID::UInt16
  encodingID::UInt16
  format::UInt16
  data::Union{CmapFormat0,CmapFormat4,CmapFormat6,CmapFormat12,CmapFormat14,Nothing}
end

struct CmapTable
  version::UInt16
  numTables::UInt16
  subtables::Vector{CmapSubtable}
end

parse_subtable(format::Val{0}, io::IO) = begin
  length = take(io, UInt16)
  @assert length == 262 "Invalid length for format 0 subtable"
  language = take(io, UInt16)
  CmapFormat0(language, read(io, 256))
end

parse_subtable(format::Val{4}, io::IO) = begin
  length = take(io, UInt16)
  language = take(io, UInt16)
  segCountX2 = take(io, UInt16)
  searchRange = take(io, UInt16)
  entrySelector = take(io, UInt16)
  rangeShift = take(io, UInt16)
  segCount = div(segCountX2, 2)
  endCode = [take(io, UInt16) for _ in 1:segCount]
  skip(io, 2)
  startCode = [take(io, UInt16) for _ in 1:segCount]
  idDelta = [take(io, Int16) for _ in 1:segCount]
  idRangeOffset = [take(io, UInt16) for _ in 1:segCount]
  # Calculate bytes for glyphIdArray
  bytes_for_glyphIdArray = length - 14 - 8 * segCount
  num_glyph_ids = div(bytes_for_glyphIdArray, 2)
  glyphIdArray = [take(io, UInt16) for _ in 1:num_glyph_ids]
  CmapFormat4(length, language, segCount, searchRange, entrySelector, rangeShift,
              endCode, startCode, idDelta, idRangeOffset, glyphIdArray)
end

parse_subtable(format::Val{6}, io::IO) = begin
  length = take(io, UInt16)
  language = take(io, UInt16)
  firstCode = take(io, UInt16)
  entryCount = take(io, UInt16)
  glyphIdArray = [take(io, UInt16) for _ in 1:entryCount]
  CmapFormat6(length, language, firstCode, entryCount, glyphIdArray)
end

parse_subtable(format::Val{12}, io::IO) = begin
  reserved = take(io, UInt16)
  @assert reserved == 0 "Reserved field is not 0"
  length = take(io, UInt32)
  language = take(io, UInt32)
  nGroups = take(io, UInt32)
  groups = Vector{CmapFormat12Group}(undef, nGroups)
  for i in 1:nGroups
    startCharCode = take(io, UInt32)
    endCharCode = take(io, UInt32)
    startGlyphID = take(io, UInt32)
    groups[i] = CmapFormat12Group(startCharCode, endCharCode, startGlyphID)
  end
  CmapFormat12(language, groups)
end

read_uint24_be(io::IO) = begin
  b1 = read(io, UInt8)
  b2 = read(io, UInt8)
  b3 = read(io, UInt8)
  (UInt32(b1) << 16) | (UInt32(b2) << 8) | UInt32(b3)
end

parse_default_uvs(io::IO) = begin
  numUnicodeValueRanges = take(io, UInt32)
  ranges = Vector{DefaultUVSRange}(undef, numUnicodeValueRanges)
  for i in 1:numUnicodeValueRanges
    startUnicodeValue = read_uint24_be(io)
    additionalCount = read(io, UInt8)
    ranges[i] = DefaultUVSRange(startUnicodeValue, additionalCount)
  end
  ranges
end

parse_non_default_uvs(io::IO) = begin
  numUVSMappings = take(io, UInt32)
  mappings = Vector{NonDefaultUVSMapping}(undef, numUVSMappings)
  for i in 1:numUVSMappings
    unicodeValue = read_uint24_be(io)
    glyphID = take(io, UInt16)
    mappings[i] = NonDefaultUVSMapping(unicodeValue, glyphID)
  end
  mappings
end

parse_subtable(format::Val{14}, io::IO) = begin
  start = position(io) - 2
  length = take(io, UInt32)
  numVarSelectorRecords = take(io, UInt32)
  varSelectorRecords = Vector{VariationSelectorRecord}(undef, numVarSelectorRecords)

  # Parse variation selector records
  for i in 1:numVarSelectorRecords
    varSelector = read_uint24_be(io)
    defaultUVSOffset = take(io, UInt32)
    nonDefaultUVSOffset = take(io, UInt32)
    starting_position = position(io)

    defaultUVS = if defaultUVSOffset != 0
      seek(io, start + defaultUVSOffset)
      parse_default_uvs(io)
    else
      DefaultUVSRange[]
    end

    nonDefaultUVS = if nonDefaultUVSOffset != 0
      seek(io, start + nonDefaultUVSOffset)
      parse_non_default_uvs(io)
    else
      NonDefaultUVSMapping[]
    end

    seek(io, starting_position)
    varSelectorRecords[i] = VariationSelectorRecord(varSelector,
                                                    defaultUVSOffset,
                                                    nonDefaultUVSOffset,
                                                    defaultUVS,
                                                    nonDefaultUVS)
  end

  CmapFormat14(length, numVarSelectorRecords, varSelectorRecords)
end

parse_subtable(::Val{format}, io::IO) where format = error("unsupported cmap format $format")

parse_cmap(file::IO, offset::UInt32) = begin
  seek(file, offset)
  version = take(file, UInt16)
  numTables = take(file, UInt16)
  subtables = [CmapSubtableHeader(take(file, UInt16), take(file, UInt16), take(file, UInt32)) for _ in 1:numTables]
  parsed_subtables = Vector{CmapSubtable}()
  for header in subtables
    seek(file, offset + header.offset)
    format = take(file, UInt16)
    data = parse_subtable(Val(Int(format)), file)
    push!(parsed_subtables, CmapSubtable(header.platformID, header.encodingID, format, data))
  end
  CmapTable(version, numTables, parsed_subtables)
end

glyph_to_char_map(cmap::CmapTable) = reduce(glyph_to_char_map, cmap.subtables, init=Dict{UInt16,Char}())
glyph_to_char_map(map::Dict, s::CmapSubtable) = glyph_to_char_map(map, s.data)

glyph_to_char_map(map, format0::CmapFormat0) = begin
  for (i,glyphindex) in enumerate(format0.glyphIdArray)
    map[glyphindex] = Char(i-1)
  end
  map
end

glyph_to_char_map(map, format4::CmapFormat4) = begin
  segCount = format4.segCount
  for i in 1:segCount
    start = format4.startCode[i]
    end_ = format4.endCode[i]
    for c in start:end_
      c = widen(c) # Convert c to UInt32 for consistency
      if format4.idRangeOffset[i] == 0
        # If idRangeOffset is 0, use idDelta directly
        glyphIndex = (c + format4.idDelta[i]) % 65536
      else
        # Otherwise, compute the index into glyphIdArray
        offset = div(format4.idRangeOffset[i], 2)
        index = offset + (c - start) + i - segCount
        if 1 <= index <= length(format4.glyphIdArray)
          glyphIndex = format4.glyphIdArray[index]
          if glyphIndex != 0
            # Adjust glyphIndex with idDelta if non-zero
            glyphIndex = (glyphIndex + format4.idDelta[i]) % 65536
          end
        else
          # If index is out of bounds, glyphIndex is 0
          glyphIndex = 0
        end
      end

      if glyphIndex != 0
        map[UInt16(glyphIndex)] = Char(c)
      end
    end
  end
  map
end

glyph_to_char_map(map, format6::CmapFormat6) = begin
  for i in 1:format6.entryCount
    c = format6.firstCode + (i-1)
    glyphIndex = format6.glyphIdArray[i]
    if glyphIndex != 0
      map[UInt16(glyphIndex)] = Char(c)
    end
  end
  map
end

glyph_to_char_map(map, format12::CmapFormat12) = begin
  for (;startCharCode, endCharCode, startGlyphID) in format12.groups
    for (i,charcode) in enumerate(startCharCode:endCharCode)
      map[UInt16(startGlyphID+(i-1))] = Char(charcode)
    end
  end
  map
end

glyph_to_char_map(map, format14::CmapFormat14) = begin
  for record in format14.varSelectorRecords
    for mapping in record.nonDefaultUVS
      map[mapping.glyphID] = Char(mapping.unicodeValue)
    end
  end
  map
end
