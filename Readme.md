# Font.jl

Provides a Font type and a font file parser. It uses [fontconfig](https://github.com/JuliaGraphics/Fontconfig.jl) to parse font names so you can specify font size and style along with the font family.

```julia
@use "github.com/jkroso/Font.jl" Font width

font = Font("Helvetica-12:light")
w = width("button", font) # 2835
```
