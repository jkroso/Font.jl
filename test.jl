@use "github.com/jkroso/Rutherford.jl/test.jl" @test testset
@use "./units.jl" pt FontUnit font_size mm inch absolute
@use "./TTF.jl" TTFont width
@use "./TTC.jl" TTCollection
@use "." Font
@use BenchmarkTools: @btime

const Fu = FontUnit{UInt16(2048)}
const fu = FontUnit{UInt16(1000)}

const helvetica = Font("Helvetica")
const papyrus = Font("Papyrus")

@test width('a', helvetica) == 1139Fu
@test width("button", helvetica) == convert(pt, 5694Fu)
@test width("button", helvetica) == 5694Fu
@test width('b', Font("Source Code Pro")) == 600fu
@test width("button", Font("Source Code Pro")) == 6*600fu
@test width("button", papyrus) == 6211Fu

@test !Font("Arial").ismonospaced
@test !Font("Noteworthy").ismonospaced
@test Font("Source Code Pro").ismonospaced

const x = TTFont("/System/Library/Fonts/Keyboard.ttf")

@test width('W', x) + width('A', x) == 3448Fu
@test width("WA", x) == 3448Fu - 113Fu
@test width('W', x) + width('A', x) + width('W', x) == 5481Fu
@test width("WAW", x) == 5481Fu - 113Fu - 113Fu
@test width('W', x) + width('A', x) + width('W', x) + width('a', x) == 6640Fu
@test width("WAWa", x) == 5481Fu - 113Fu - 113Fu + width('a', x)

@btime width("WAWa", $x) #116ns
@btime width("adfa", $x) #111ns

const ttc = TTCollection("/System/Library/Fonts/Helvetica.ttc")
@test ttc.default.subfamily == "Regular"

@test width("button", Font("Helvetica-10:light")) ≈ 28.35pt
@test width("button", Font("Helvetica-12:light")) ≈ 34.02pt
