@use "../utils.jl" take

struct LongHorMetric
  advanceWidth::UInt16
  lsb::Int16
end

"Horizontal Metrics"
struct HmtxTable
  hMetrics::Vector{LongHorMetric}
  leftSideBearings::Vector{Int16}
end

parse_hmtx(file::IO, offset::UInt32, numGlyphs::UInt16, numberOfHMetrics::UInt16) = begin
  seek(file, offset)

  hMetrics = Vector{LongHorMetric}(undef, numberOfHMetrics)
  for i in 1:numberOfHMetrics
    advanceWidth = take(file, UInt16)
    lsb = take(file, Int16)
    hMetrics[i] = LongHorMetric(advanceWidth, lsb)
  end

  # Read additional left side bearings for any remaining glyphs
  if numGlyphs > numberOfHMetrics
    numAdditionalLSBs = numGlyphs - numberOfHMetrics
    leftSideBearings = Vector{Int16}(undef, numAdditionalLSBs)
    for i in 1:numAdditionalLSBs
      leftSideBearings[i] = take(file, Int16)
    end
  else
    leftSideBearings = Int16[]
  end

  HmtxTable(hMetrics, leftSideBearings)
end

advance_x_map((;hMetrics)::HmtxTable, charmap) = begin
  l = length(hMetrics)
  Dict{Char,Int16}((char => hMetrics[min(l,id+1)].advanceWidth for (id, char) in charmap))
end
