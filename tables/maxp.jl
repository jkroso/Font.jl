@use "../utils.jl" take

struct MaxpTable
  version::Float64            # 16.16 fixed-point version (0.5 or 1.0)
  num_glyphs::UInt16          # Number of glyphs in the font
end

# Note: Version 0.5 has only version and num_glyphs; version 1.0 has more fields
# Here, we parse only the common fields for simplicity
parse_maxp(file, offset) = begin
  seek(file, offset)
  MaxpTable(take(file, Int32) / 65536.0,  # Fixed 16.16, num_glyphs
            take(file, UInt16))
end
