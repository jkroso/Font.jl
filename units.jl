@use "github.com/jkroso/Units.jl" Length basefactor @abbreviate m mm conversion_factor short_name ["Imperial.jl" inch]
@use "github.com/jkroso/Prospects.jl" @struct

const dispid = UInt8(@ccall "CoreGraphics.framework/CoreGraphics".CGMainDisplayID()::UInt32)
const display_size = mm.(@ccall "CoreGraphics.framework/CoreGraphics".CGDisplayScreenSize(dispid::UInt32)::Tuple{Float64,Float64})

"This is the number of pixels the display is pretending to have"
const perceived_pixels = (@ccall("CoreGraphics.framework/CoreGraphics".CGDisplayPixelsWide(dispid::UInt32)::Int),
                          @ccall("CoreGraphics.framework/CoreGraphics".CGDisplayPixelsHigh(dispid::UInt32)::Int))

"This is the actual pixel resolution of the display"
const max_pixels = let
  modes = @ccall "CoreGraphics.framework/CoreGraphics".CGDisplayCopyAllDisplayModes(dispid::UInt32, C_NULL::Ptr{Cvoid})::Ptr{Cvoid}
  @assert modes != C_NULL "Failed to get display modes"

  count = @ccall "CoreFoundation.framework/CoreFoundation".CFArrayGetCount(modes::Ptr{Cvoid})::Clong
  sizes = map(0:count-1) do i
    mode = @ccall "CoreFoundation.framework/CoreFoundation".CFArrayGetValueAtIndex(modes::Ptr{Nothing}, i::Clong)::Ptr{Nothing}
    w = @ccall "CoreGraphics.framework/CoreGraphics".CGDisplayModeGetWidth(mode::Ptr{Nothing})::UInt
    h = @ccall "CoreGraphics.framework/CoreGraphics".CGDisplayModeGetHeight(mode::Ptr{Nothing})::UInt
    (Int(w), Int(h))
  end
  @ccall "CoreFoundation.framework/CoreFoundation".CFRelease(modes::Ptr{Cvoid})::Cvoid

  sort(sizes, by=s->reduce(*, s))[end]
end

"This is perceived pixel density, which isn't necessarily the highest density the display is capable of"
const PPI = round(Int, perceived_pixels[1]/display_size[1].value * conversion_factor(inch, mm))
"This is the max pixel density the display is capable of"
const max_PPI = round(Int, max_pixels[1]/display_size[1].value * conversion_factor(inch, mm))

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
relative(l::Length, size::pt) = em((l/size).value)
relative(F::Type{FontUnit}, l::Length, size::pt) = relative(F, convert(pt, l), size)
relative(::Type{FontUnit{per_em}}, l::pt, size::pt) where per_em = FontUnit{per_em}(round(Int, (l.value/size.value)*per_em))

# enables 3px < 1mm etc...
Base.promote_rule(::Type{<:Length}, ::Type{F}) where F<:TypographicLength = px
