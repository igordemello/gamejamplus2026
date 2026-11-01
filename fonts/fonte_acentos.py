# monta as letras acentuadas da Halloween Spooky com os acentos soltos da própria fonte
# (ela tem ´ ` ^ ~ ¨ ¸ e as letras, mas não as letras acentuadas) e salva uma cópia nova.
# precisa do fontTools (pip install fonttools). rode na pasta do projeto:
#   python fonts/fonte_acentos.py "fonts/Halloween Spooky.otf" "fonts/Halloween Spooky Acentos.otf"
import sys
import unicodedata
from fontTools.ttLib import TTFont
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

origem, destino = sys.argv[1], sys.argv[2]
f = TTFont(origem)
cff = f["CFF "].cff
top = cff.topDictIndex[0]
charstrings = top.CharStrings
gs = f.getGlyphSet()
cmap = f.getBestCmap()
ordem = list(f.getGlyphOrder())

ACENTO = {"´": "acute", "`": "grave", "^": "asciicircum", "~": "asciitilde", "¨": "dieresis", "¸": "cedilla"}
COMPOSTOS = {}
for base, acentos in {"a": "´`^~¨", "e": "´`^¨", "i": "´`^¨", "o": "´`^~¨", "u": "´`^¨", "c": "¸", "n": "~"}.items():
    for maiuscula in (False, True):
        b = base.upper() if maiuscula else base
        for ac in acentos:
            letra = {"´": "́", "`": "̀", "^": "̂", "~": "̃", "¨": "̈", "¸": "̧"}[ac]
            COMPOSTOS[unicodedata.normalize("NFC", b + letra)] = (cmap[ord(b)], ACENTO[ac])

def caixa(nome):
    p = BoundsPen(gs)
    gs[nome].draw(p)
    return p.bounds

novos = 0
for ch, (base, acento) in COMPOSTOS.items():
    if ord(ch) in cmap:
        continue
    bb = caixa(base)
    ab = caixa(acento)
    largura_base = bb[2] - bb[0]
    largura_acento = ab[2] - ab[0]
    # acento nunca mais largo que 80% da letra (o ^ e o ~ da fonte são enormes)
    s = min(1.0, largura_base * 0.8 / largura_acento)
    if acento in ("asciicircum", "asciitilde"):
        s = min(s, 0.55)
    meio = (bb[0] + bb[2]) / 2.0
    dx = meio - (ab[0] + ab[2]) / 2.0 * s
    if acento == "cedilla":
        dy = bb[1] + 30 - ab[3] * s
    else:
        dy = bb[3] + 40 - ab[1] * s
    largura = f["hmtx"][base][0]
    pen = T2CharStringPen(largura, gs)
    gs[base].draw(pen)
    gs[acento].draw(TransformPen(pen, (s, 0, 0, s, dx, dy)))
    cs = pen.getCharString(private=top.Private, globalSubrs=cff.GlobalSubrs)
    nome = "uni%04X" % ord(ch)
    if charstrings.charStringsAreIndexed:
        charstrings.charStringsIndex.append(cs)
        charstrings.charStrings[nome] = len(charstrings.charStringsIndex) - 1
    else:
        charstrings.charStrings[nome] = cs
    top.charset.append(nome)
    ordem.append(nome)
    f["hmtx"][nome] = (largura, int(min(bb[0], dx + ab[0] * s)))
    for t in f["cmap"].tables:
        if t.isUnicode():
            t.cmap[ord(ch)] = nome
    novos += 1

f.setGlyphOrder(ordem)
f.save(destino)
print("letras acentuadas novas:", novos)
