@use "github.com/jkroso/Prospects.jl" @mutable @lazyprop @property ["Enum.jl" @Enum]
@use "github.com/jkroso/URI.jl/FSPath.jl" FSPath
@use "./tables/post.jl" parse_post
@use "./TTC.jl" TTCollection
@use "./TTF.jl" TTFont width
@use Fontconfig

@Enum FontStyle regular italic bold light

@kwdef mutable struct Font
  family::String
  size::Int
  width::Int
  style::FontStyle=FontStyle.regular
  weight::Int=80
  path::FSPath
  face::TTFont
  Font(s::String) = begin
    p = Fontconfig.match(Fontconfig.Pattern(s))
    f = split(Fontconfig.format(p, "%{family}:%{size}:%{width}:%{style[0]}:%{weight}:%{file}"), ':')
    new(f[1], parse(Int, f[2]), parse(Int, f[3]), getproperty(FontStyle, Symbol(lowercase(f[4]))), parse(Int, f[5]), FSPath(f[6]))
  end
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

width(str::AbstractString, f::Font) = width(str, f.face)
width(c::Char, f::Font) = width(c, f.face)
