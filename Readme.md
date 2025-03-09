# Font.jl

Provides a Font type and a font file parser. It uses [fontconfig](https://github.com/JuliaGraphics/Fontconfig.jl) to parse font names so you can specify font size and style along with the font family.

```julia
@use "github.com/jkroso/Font.jl" Font width ["units" pt px mm inch]

font = Font("Helvetica-10:light") # family=Helvetica subfamily=light size=10pt
w = width("button", font) # 28.35pt
convert(px, w) # 41.34375px
convert(mm, w) # 10.00125mm
convert(inch, w) # 0.39375"
```
