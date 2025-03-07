@use "../utils.jl" take

const macStandardNames = include("../MacStandardNames.jl")

struct PostTable
  version::Float32           # Table version (e.g., 1.0, 2.0)
  italicAngle::Float32       # Italic angle in degrees (16.16 fixed-point)
  underlinePosition::Int16   # Position of the underline
  underlineThickness::Int16  # Thickness of the underline
  isFixedPitch::UInt32       # Non-zero if the font is monospaced
  minMemType42::UInt32       # Memory usage hints (often unused)
  maxMemType42::UInt32       # Memory usage hints
  minMemType1::UInt32        # Memory usage hints
  maxMemType1::UInt32        # Memory usage hints
  glyphNames::Vector{String} # Glyph names (only for format 2.0)
end

parse_post(file::IO, offset::UInt32) = begin
  seek(file, offset)

  # Read version (32-bit fixed-point, convert to Float32)
  version = Float32(take(file, UInt32)) / 65536.0

  # Read italicAngle (32-bit fixed-point, convert to Float32)
  italicAngle = Float32(take(file, Int32)) / 65536.0

  # Read underline metrics (signed 16-bit integers)
  underlinePosition = take(file, Int16)
  underlineThickness = take(file, Int16)

  # Read isFixedPitch (unsigned 32-bit integer)
  isFixedPitch = take(file, UInt32)

  # Read memory usage hints (unsigned 32-bit integers)
  minMemType42 = take(file, UInt32)
  maxMemType42 = take(file, UInt32)
  minMemType1 = take(file, UInt32)
  maxMemType1 = take(file, UInt32)

  # Initialize glyphNames
  glyphNames = String[]

  # Handle format-specific data
  if version == 1.0
    # Format 1.0: No glyph names in the table
    glyphNames = String[]
  elseif version == 2.0
    # Format 2.0: Read glyph name data
    numberOfGlyphs = take(file, UInt16)
    glyphNameIndex = [take(file, UInt16) for _ in 1:numberOfGlyphs]

    # Read the number of Pascal strings (custom glyph names)
    numCustomNames = maximum(glyphNameIndex) - 257  # 258-511 are custom
    if numCustomNames > 0
      customNames = [read_pascal_string(file) for _ in 1:numCustomNames]
    else
      customNames = String[]
    end

    # Construct glyphNames
    for idx in glyphNameIndex
      if idx <= 257
        push!(glyphNames, macStandardNames[idx + 1][1])  # 0-based index
      else
        customIdx = idx - 258 + 1  # Custom names start after 257
        if customIdx <= length(customNames)
          push!(glyphNames, customNames[customIdx])
        else
          push!(glyphNames, "")
        end
      end
    end
  else
    error("Unsupported post table version: $version")
  end

  PostTable(version, italicAngle, underlinePosition, underlineThickness,
            isFixedPitch, minMemType42, maxMemType42, minMemType1, maxMemType1,
            glyphNames)
end

read_pascal_string(file::IO) = String(read(file, read(file, UInt8)))
