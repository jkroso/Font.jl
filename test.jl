@use "github.com/jkroso/Rutherford.jl/test.jl" @test testset
@use "./units.jl" pt FontUnit font_size mm inch absolute
@use "./TTF.jl" TTFont width widths!
@use "./TTC.jl" TTCollection
@use "." Font
@use BenchmarkTools: @btime

const Fu = FontUnit{UInt16(2048)}
const fu = FontUnit{UInt16(1000)}

const helvetica = Font("Helvetica")
const papyrus = Font("Papyrus")

@test width('a', helvetica.face) == 1139Fu
@test width("button", helvetica) == convert(pt, 5694Fu)
@test width("button", helvetica.face) == 5694Fu
@test width('b', Font("Source Code Pro").face) == 600fu
@test width("button", Font("Source Code Pro").face) == 6*600fu
@test width("button", papyrus.face) == 6211Fu

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

@test width('A', 'V', x) < width('V', x)

@test widths!("WAibz", helvetica.face) == FontUnit{0x0800}[1933, 1366, 455, 1139, 1024]
const sentence = "Wibz UIflibber jabberz devz n’ zany toolz setz to flibber flabber snazzy, zippy facez widda wacko eazy twisty"
const words = split(sentence)
@test widths!(words, helvetica.face) == FontUnit{0x0800}[4551, 7626, 6717, 4326, 1594, 4326, 4326, 3756, 1708, 5578, 6262, 6943, 4781, 4895, 5351, 5805, 4326, 5120]
