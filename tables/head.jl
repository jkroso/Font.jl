@use "../utils.jl" take

@kwdef struct HeadTable
  version::Float64            # 16.16 fixed-point version number (e.g., 1.0)
  font_revision::Float64      # 16.16 fixed-point font revision number
  check_sum_adjustment::UInt32 # Checksum adjustment for the font
  magic_number::UInt32        # Magic number (set to 0x5F0F3CF5)
  flags::UInt16               # Font flags
  units_per_em::UInt16        # Units per em (typically 16 to 16384)
  created::Int64              # Creation timestamp (seconds since 1904-01-01)
  modified::Int64             # Modification timestamp
  x_min::Int16                # Minimum x for all glyph bounding boxes
  y_min::Int16                # Minimum y for all glyph bounding boxes
  x_max::Int16                # Maximum x for all glyph bounding boxes
  y_max::Int16                # Maximum y for all glyph bounding boxes
  mac_style::UInt16           # Mac style flags (e.g., bold, italic)
  lowest_rec_ppem::UInt16     # Smallest readable size in pixels per em
  font_direction_hint::Int16  # Font direction hint (deprecated)
  index_to_loc_format::Int16  # Format of 'loca' table offsets (0=short, 1=long)
  glyph_data_format::Int16    # Glyph data format (should be 0)
end

parse_head(file, offset) = begin
  seek(file, offset)  # Move to the table’s starting position
  # Read fields according to the TrueType 'head' table structure
  # Fixed types (16.16) are read as Int32 and converted to Float64
  HeadTable(version = take(file, Int32) / 65536.0,
            font_revision = take(file, Int32) / 65536.0,
            check_sum_adjustment = take(file, UInt32),
            magic_number = take(file, UInt32),
            flags = take(file, UInt16),
            units_per_em = take(file, UInt16),
            created = take(file, Int64),      # LONGDATETIME
            modified = take(file, Int64),
            x_min = take(file, Int16),       # FWORD
            y_min = take(file, Int16),
            x_max = take(file, Int16),
            y_max = take(file, Int16),
            mac_style = take(file, UInt16),
            lowest_rec_ppem = take(file, UInt16),
            font_direction_hint = take(file, Int16),
            index_to_loc_format = take(file, Int16),
            glyph_data_format = take(file, Int16))
end
