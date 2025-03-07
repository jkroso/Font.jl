@use "github.com/jkroso/Rutherford.jl/test.jl" @test testset
@use "./TTF.jl" TTFont width
@use "./TTC.jl" TTCollection
@use "." Font
@use BenchmarkTools: @btime

const helvetica = Font("Helvetica")
const papyrus = Font("Papyrus")
@test width('a', helvetica) == 1139
@test width("button", helvetica) == 5694
@test width('b', Font("Source Code Pro")) == 600
@test width("button", Font("Source Code Pro")) == 6*600
@test width("button", papyrus) == 6211

@test !Font("Arial").ismonospaced
@test !Font("Noteworthy").ismonospaced
@test Font("Source Code Pro").ismonospaced

const x = TTFont("/System/Library/Fonts/Keyboard.ttf")

@test width('W', x) + width('A', x) == 3448
@test width("WA", x) == 3448 - 113
@test width('W', x) + width('A', x) + width('W', x) == 5481
@test width("WAW", x) == 5481 - 113 - 113
@test width('W', x) + width('A', x) + width('W', x) + width('a', x) == 6640
@test width("WAWa", x) == 5481 - 113 - 113 + width('a', x)

@btime width("WAWa", $x) #118ns
@btime width("adfa", $x) #111ns

const ttc = TTCollection("/System/Library/Fonts/Helvetica.ttc")
@test ttc.default.subfamily == "Regular"
