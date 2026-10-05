@use "github.com/jkroso/Prospects.jl" @mutable @lazyprop @property ["Enum.jl" @Enum]
@use "github.com/jkroso/URI.jl/FSPath.jl" FSPath
@use "./units.jl" pt absolute Length FontUnit
@use "./tables/post.jl" parse_post
@use "./TTC.jl" TTCollection
@use "./TTF.jl" TTFont widths! units_per_em
@use Fontconfig

@Enum FontStyle regular italic bold light

"Map a font's style name onto FontStyle. Styles without their own entry, like Medium, count as regular."
parse_style(name::AbstractString) = begin
  s = Symbol(lowercase(name))
  s in (:regular, :italic, :bold, :light) ? getproperty(FontStyle, s) : FontStyle.regular
end

@kwdef mutable struct Font
  family::String
  size::pt
  width::Int
  style::FontStyle=FontStyle.regular
  weight::Int=80
  path::FSPath
  face::TTFont
  Font(s::String; size=nothing, style=nothing, weight=nothing) = begin
    p = Fontconfig.match(Fontconfig.Pattern(s))
    f = split(Fontconfig.format(p, "%{family}:%{size}:%{width}:%{style[0]}:%{weight}:%{file}"), ':')
    sz = isnothing(size) ? pt(parse(Int, f[2])) : size
    st = isnothing(style) ? parse_style(f[4]) : style
    wt = isnothing(weight) ? parse(Int, f[5]) : weight
    new(f[1], sz, parse(Int, f[3]), st, wt, FSPath(f[6]))
  end
end

Font(family::AbstractString, size::Length, style=FontStyle.regular) = begin
  style isa Symbol && (style = getproperty(FontStyle, style))
  Font(family, size=convert(pt, size), style=style)
end

@lazyprop Font.face = begin
  if self.path.extension == "ttf"
    TTFont(string(self.path))
  else
    getproperty(TTCollection(string(self.path)), Symbol(string(self.style)))
  end
end

@property Font.ismonospaced = begin
  if haskey(self.face.index, "post")
    open(self.path, "r") do io
      post = parse_post(io, self.face.index["post"])
      post.isFixedPitch > 0
    end
  else
    allequal(values(self.face.advance_x))
  end
end

# convert to an absolute size since we know the font size here
Base.textwidth(c::Union{Char,AbstractString}, f::Font) = absolute(textwidth(c, f.face), f.size)
Base.textwidth(a::Char, b::Char, f::Font) = absolute(textwidth(a, b, f.face), f.size)

# Vertical font metrics, scaled to the font's size
ascent(f::Font)  = absolute(FontUnit{units_per_em(f.face)}(Int(f.face.hhea.ascender)),  f.size)
descent(f::Font) = absolute(FontUnit{units_per_em(f.face)}(Int(-f.face.hhea.descender)), f.size)
"Natural line height per font: ascent + descent (no leading)"
font_line_height(f::Font) = ascent(f) + descent(f)
"""
Approximate capital-letter height. Most Latin fonts (Helvetica, Arial, Roboto,
Inter) have cap_height between 0.70 and 0.73 × em. We use 0.72 as a robust
default; without OS/2 table parsing it is the best estimate the framework can
make and keeps centred labels visually aligned to within a pixel.
"""
cap_height(f::Font) = 0.72 * f.size
