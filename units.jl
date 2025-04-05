@use "github.com/jkroso/Units.jl" Length basefactor @abbreviate m mm conversion_factor short_name ["Imperial.jl" inch]
@use "github.com/jkroso/Prospects.jl" @struct

"This is perceived pixel density, which isn't necessarily the highest density the display is capable of"
const PPI = let
  dispid = ccall((:CGMainDisplayID, "CoreGraphics.framework/CoreGraphics"), UInt32,())
  widthpx = ccall((:CGDisplayPixelsWide, "CoreGraphics.framework/CoreGraphics"), Int, (UInt32,), dispid)
  size_mm = ccall((:CGDisplayScreenSize, "CoreGraphics.framework/CoreGraphics"), Tuple{Float64,Float64}, (UInt32,), dispid)
  MMI = conversion_factor(inch, mm)
  round(Int, widthpx/size_mm[1] * MMI)
end

abstract type TypographicLength <: Length end

@struct Point(value::Float64) <: TypographicLength
@abbreviate pt Point

# math is faster with floats thans rationals and GUI's never need that much precision
const POINT_BASEFACTOR = Float64(basefactor(inch)/72)
basefactor(::Type{Point}) = POINT_BASEFACTOR

@struct Pixel(value::Float64) <: TypographicLength
@abbreviate px Pixel

const PIXEL_BASEFACTOR = Float64(basefactor(inch)/PPI)
basefactor(::Type{Pixel}) = PIXEL_BASEFACTOR

"The size of 1em. You can change this value at any time"
const font_size = Ref{pt}(12.0pt)

"em just means the size of an 'm' at a given `font_size`"
@struct em(value::Float64) <: TypographicLength
short_name(::Type{em}) = "em"
basefactor(::Type{em}) = basefactor(pt) * font_size[].value

"""
TrueType fonts have all their dimensions defined as integer values that represent a fraction of an
em. This fraction us usually 1/2048 but is sometimes 1/1024
"""
@struct FontUnit{per_m}(value::Int) <: TypographicLength
basefactor(::Type{FontUnit{per_m}}) where per_m = basefactor(em) / per_m
short_name(::Type{<:FontUnit}) = "fontunit"
Base.promote_rule(::Type{F}, ::Type{pt}) where F<:FontUnit = pt
Base.promote_rule(::Type{F}, ::Type{px}) where F<:FontUnit = px

"Convert an relative length into an absolute length"
absolute(fu::FontUnit{per_m}, size::pt) where per_m = pt(fu.value/per_m*size.value)
absolute(e::em, size::Length) = e.value*size
absolute(x::Length, size::Length) = x # already an absolute length

"Convert an absolute length back into a relative length"
relative(l::Length, size::pt) = em(l/size)
relative(::Type{FontUnit{per_em}}, l::Length, size::pt) where per_em = FontUnit{per_em}(round(Int, l/size*per_em))

# enables 3px < 1mm etc...
Base.promote_rule(::Type{<:Length}, ::Type{F}) where F<:TypographicLength = px
