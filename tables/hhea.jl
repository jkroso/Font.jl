@use "../utils.jl" take

struct HheaTable
  version::Float32          # Version number (e.g., 1.0)
  ascender::Int16           # Typographic ascent
  descender::Int16          # Typographic descent
  lineGap::Int16            # Typographic line gap
  advanceWidthMax::UInt16   # Maximum advance width
  minLeftSideBearing::Int16 # Minimum left side bearing
  minRightSideBearing::Int16# Minimum right side bearing
  xMaxExtent::Int16         # Maximum horizontal extent
  caretSlopeRise::Int16     # Caret slope rise (for vertical text)
  caretSlopeRun::Int16      # Caret slope run (for vertical text)
  caretOffset::Int16        # Caret offset
  metricDataFormat::Int16   # Format of metric data (should be 0)
  numberOfHMetrics::UInt16  # Number of horizontal metrics in hmtx table
end

parse_hhea(file::IO, offset::UInt32) = begin
  seek(file, offset)

  # Read version (32-bit fixed-point, converted to Float32)
  version = take(file, UInt32) / 65536.0

  # Read typographic metrics (signed 16-bit integers)
  ascender = take(file, Int16)
  descender = take(file, Int16)
  lineGap = take(file, Int16)

  # Read maximum advance width (unsigned 16-bit integer)
  advanceWidthMax = take(file, UInt16)

  # Read bearing and extent metrics (signed 16-bit integers)
  minLeftSideBearing = take(file, Int16)
  minRightSideBearing = take(file, Int16)
  xMaxExtent = take(file, Int16)

  # Read caret-related fields (signed 16-bit integers)
  caretSlopeRise = take(file, Int16)
  caretSlopeRun = take(file, Int16)
  caretOffset = take(file, Int16)

  # Skip four reserved fields
  skip(file, 8)

  # Read metric data format (signed 16-bit integer)
  metricDataFormat = take(file, Int16)

  # Read number of horizontal metrics (unsigned 16-bit integer)
  numberOfHMetrics = take(file, UInt16)

  HheaTable(version, ascender, descender, lineGap,
            advanceWidthMax, minLeftSideBearing, minRightSideBearing,
            xMaxExtent, caretSlopeRise, caretSlopeRun, caretOffset,
            metricDataFormat, numberOfHMetrics)
end
