@use "../utils.jl" take

struct NameTableHeader
  format::UInt16
  count::UInt16
  stringOffset::UInt16
end

struct NameRecord
  platformID::UInt16
  encodingID::UInt16
  languageID::UInt16
  nameID::UInt16
  length::UInt16
  offset::UInt16
  string::String
end

struct NameTable
  header::NameTableHeader
  records::Vector{NameRecord}
end

parse_name(file::IO, table_offset::UInt32) = begin
  seek(file, table_offset)
  format = take(file, UInt16)
  @assert format == 0
  count = take(file, UInt16)
  header_length = take(file, UInt16)
  header = NameTableHeader(format, count, header_length)
  records = Vector{NameRecord}(undef, count)
  for i in 1:count
    platformID = take(file, UInt16)
    encodingID = take(file, UInt16)
    languageID = take(file, UInt16)
    nameID = take(file, UInt16)
    length = take(file, UInt16)
    offset = take(file, UInt16)

    # The actuall strings are stored at the end of the metadata
    # Save current position to return after reading the string
    current_pos = position(file)
    seek(file, table_offset + header_length + offset)
    buf = read(file, length)
    # encodingID 1 is unicode
    string = if encodingID == 1
      transcode(String, [UInt16(buf[i])<<8|UInt16(buf[i+1]) for i in 1:2:length])
    else
      String(buf)
    end
    seek(file, current_pos)

    records[i] = NameRecord(platformID, encodingID, languageID, nameID, length, offset, string)
  end

  NameTable(header, records)
end
