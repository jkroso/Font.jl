@use "github.com/jkroso/Prospects.jl" @struct @property
@use "./tables/kerx.jl" parse_kerx kern_map KerxTable
@use "./tables/kern.jl" parse_kern take KernTable
@use "./tables/head.jl" parse_head HeadTable
@use "./tables/maxp.jl" parse_maxp MaxpTable
@use "./tables/name.jl" parse_name NameTable
@use "./tables/cmap.jl" parse_cmap CmapTable glyph_to_char_map
@use "./tables/hhea.jl" parse_hhea HheaTable
@use "./tables/hmtx.jl" parse_hmtx HmtxTable advance_x_map
@use "./units.jl" FontUnit

function read_table_directory(file)
  sfnt_version = take(file, UInt32)

  if sfnt_version != 0x00010000 && sfnt_version != 0x74727565
    error("Unsupported sfnt version: 0x$(string(sfnt_version, base=16))")
  end

  num_tables = take(file, Int16)    # Number of tables
  take(file, UInt16)                # searchRange (ignored for now)
  take(file, UInt16)                # entrySelector (ignored)
  take(file, UInt16)                # rangeShift (ignored)

  tables = Dict{String,UInt32}()
  for _ in 1:num_tables
    tag = String(read(file, 4))     # 4-byte table tag (e.g., "head")
    check_sum = take(file, UInt32)  # Checksum (not used here)
    offset = take(file, UInt32)     # Offset from file start
    length = take(file, UInt32)     # Length of the table in bytes
    tables[tag] = offset
  end
  tables
end

@struct struct TTFont{upm}
  index::Dict{String, UInt32}
  head::HeadTable
  maxp::MaxpTable
  name::Union{NameTable,Nothing}
  kern::Union{KernTable,KerxTable,Nothing}
  cmap::Union{CmapTable,Nothing}
  hhea::Union{HheaTable,Nothing}
  hmtx::Union{HmtxTable,Nothing}
  kerning::Union{Dict{Char,Dict{Char,Int16}},Nothing}
  advance_x::Union{Dict{Char,Int16},Nothing}
end

TTFont(file_path::String) = open(parse_ttf, file_path, "r")

function parse_ttf(io::IO)
  tables = read_table_directory(io)
  if !haskey(tables, "head") || !haskey(tables, "maxp")
    error("Missing required table: 'head' and 'maxp'")
  end
  head = parse_head(io, tables["head"])
  maxp = parse_maxp(io, tables["maxp"])
  kern = if haskey(tables, "kern")
    parse_kern(io, tables["kern"])
  elseif haskey(tables, "kerx")
    parse_kerx(io, tables["kerx"])
  end
  cmap = haskey(tables, "cmap") ? parse_cmap(io, tables["cmap"]) : nothing
  hhea = haskey(tables, "hhea") ? parse_hhea(io, tables["hhea"]) : nothing
  hmtx = haskey(tables, "hmtx") ? parse_hmtx(io, tables["hmtx"], maxp.num_glyphs, hhea.numberOfHMetrics) : nothing
  glyphmap = !isnothing(cmap) ? glyph_to_char_map(cmap) : nothing
  TTFont{head.units_per_em}(
    index=tables,
    head=head,
    maxp=maxp,
    kern=kern,
    cmap=cmap,
    hhea=hhea,
    hmtx=hmtx,
    name=haskey(tables, "name") ? parse_name(io, tables["name"]) : nothing,
    kerning=isnothing(kern) ? nothing : kern_map(kern, glyphmap),
    advance_x=isnothing(hmtx) ? nothing : advance_x_map(hmtx, glyphmap))
end

@property TTFont.family = getname(self, 1)
@property TTFont.subfamily = getname(self, 2)
@property TTFont.familyID = getname(self, 3)
@property TTFont.fullname = getname(self, 4)

getname((;name)::TTFont, id::Integer) = begin
  i = findfirst(r->r.nameID == id, name.records)
  i == nothing ? "" : name.records[i].string
end

Base.textwidth(c::Char, font::TTFont{upm}) where upm = FontUnit{upm}(font.advance_x[c])

"Measure the kerning aware width of `b` when following `a`"
function Base.textwidth(a::Char, b::Char, (;advance_x, kerning)::TTFont{upm}) where upm
  w = FontUnit{upm}(advance_x[b])
  dict = get(kerning, a, nothing)
  isnothing(dict) ? w : w + get(dict, b, 0)
end

function Base.textwidth(str::AbstractString, (;advance_x, kerning)::TTFont{upm}) where upm
  @assert advance_x != nothing "Font has no hmtx table"
  isnothing(kerning) && return FontUnit{upm}(sum(c->advance_x[c], str, init=0))
  w = 0
  kerning_dict = nothing
  for c in str
    w += advance_x[c]
    if kerning_dict !== nothing
      w += get(kerning_dict, c, 0)
    end
    kerning_dict = get(kerning, c, nothing)
  end
  FontUnit{upm}(w)
end

function widths!(chars::String,
                (;advance_x, kerning)::TTFont{upm},
                out::Vector{FontUnit{upm}}=Vector{FontUnit{upm}}(undef, ncodeunits(chars))) where upm
  isnothing(kerning) && return map!(c->FontUnit{upm}(advance_x[c]), out, Char[chars...])
  kerning_dict = nothing
  for (i,c) in enumerate(chars)
    w = FontUnit{upm}(advance_x[c])
    kerning_dict !== nothing && (w += get(kerning_dict, c, FontUnit{upm}(0)))
    kerning_dict = get(kerning, c, nothing)
    out[i] = w
  end
  out
end

function widths!(words::Vector{SubString{String}},
        (;advance_x, kerning)::TTFont{upm},
        out::Vector{FontUnit{upm}}=Vector{FontUnit{upm}}(undef, length(words))) where upm
  for (i, word) in enumerate(words)
    w = FontUnit{upm}(0)
    kerning_dict = nothing
    for c in word
      w += advance_x[c]
      kerning_dict !== nothing && (w += get(kerning_dict, c, FontUnit{upm}(0)))
      kerning_dict = get(kerning, c, nothing)
    end
    out[i] = w
  end
  out
end
