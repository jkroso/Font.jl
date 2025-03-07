@use "github.com/jkroso/Prospects.jl" @struct Field
@use "./TTF" parse_ttf TTFont take getname

@struct TTCollection(fonts::Vector{TTFont}=[])
TTCollection(path::String) = parse_ttc(path)

function read_offsets(io::IO)
  tag = String(read(io, 4))
  @assert tag == "ttcf" "Invalid TTC file: expected 'ttcf' tag, got '$tag'"
  majorVersion = take(io, UInt16)
  minorVersion = take(io, UInt16)
  numFonts = take(io, UInt32)
  [take(io, UInt32) for _ in 1:numFonts]
end

parse_ttc(file_path::String) = open(parse_ttc, file_path, "r")
parse_ttc(io::IO) = begin
  fonts = map(read_offsets(io)) do offset
    seek(io, offset)
    parse_ttf(io)
  end
  TTCollection(fonts)
end

Base.propertynames(ttc::TTCollection) = begin
  vcat([:default, :subfamilies], map(f->Symbol(lowercase(replace(f.subfamily, ' ' => '_'))), ttc.fonts))
end

Base.getproperty(ttc::TTCollection, ::Field{:subfamilies}) = map(f->f.subfamily, getfield(ttc, :fonts))
Base.getproperty(ttc::TTCollection, ::Field{:default}) = begin
  f = getfield(ttc, :fonts)[1]
  name = getname(f, 17)
  isempty(name) && return f
  for f in ttc.fonts
    f.subfamily == name && return f
  end
end

Base.getproperty(ttc::TTCollection, ::Field{k}) where k = begin
  hasfield(TTCollection, k) && return getfield(ttc, k)
  subfamily = replace(lowercase(String(k)), '_' => ' ')
  for font in getfield(ttc, :fonts)
    lowercase(font.subfamily) == subfamily && return font
  end
  error("No subfamily named: $k")
end
