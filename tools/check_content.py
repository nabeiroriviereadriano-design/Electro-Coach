"""Pré-vérification locale du contenu (miroir Python du validateur Dart).

Le validateur de référence reste `dart run bin/validate.dart` (CI). Ce script
sert à détecter vite, sans Dart, les erreurs les plus courantes :
expressions illisibles, tirages impossibles, modèles non remplacés,
réponses arrondies refusées, notions inconnues ou hors programme,
notions au programme sans cours ou avec moins de 2 exercices.

Usage : python tools/check_content.py [--seeds 50] [--coverage]
"""
import cmath
import json
import math
import pathlib
import random
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "app/assets/content"


class ExprError(Exception):
    pass


def _real(z, fn):
    if abs(z.imag) > 1e-9 * max(1.0, abs(z)):
        raise ExprError(f"{fn} attend un réel")
    return z.real


def _comb(n, k):
    n, k = round(_real(n, "C")), round(_real(k, "C"))
    return complex(math.comb(n, k) if 0 <= k <= n else 0)


FUNCS = {
    "sqrt": lambda a: cmath.sqrt(a) if not (abs(a.imag) < 1e-12 and a.real >= 0) else complex(math.sqrt(a.real)),
    "racine": lambda a: cmath.sqrt(a),
    "exp": cmath.exp, "ln": cmath.log,
    "log": lambda a: complex(math.log10(_real(a, "log"))),
    "sin": cmath.sin, "cos": cmath.cos, "tan": cmath.tan,
    "atan": lambda a: complex(math.atan(_real(a, "atan"))), "arctan": lambda a: complex(math.atan(_real(a, "atan"))),
    "asin": lambda a: complex(math.asin(_real(a, "asin"))), "acos": lambda a: complex(math.acos(_real(a, "acos"))),
    "atan2": lambda y, x: complex(math.atan2(_real(y, "atan2"), _real(x, "atan2"))),
    "abs": lambda a: complex(abs(a)), "mod": lambda a: complex(abs(a)), "arg": lambda a: complex(cmath.phase(a)),
    "re": lambda a: complex(a.real), "im": lambda a: complex(a.imag), "conj": lambda a: a.conjugate(),
    "deg": lambda a: complex(math.degrees(_real(a, "deg"))), "rad": lambda a: complex(math.radians(_real(a, "rad"))),
    "min": lambda *a: complex(min(_real(x, "min") for x in a)), "max": lambda *a: complex(max(_real(x, "max") for x in a)),
    "round": lambda a, d=0j: complex(round(_real(a, "round"), int(round(d.real)))),
    "C": _comb,
    "gt": lambda a, b: complex(1 if _real(a, "gt") > _real(b, "gt") else 0),
    "lt": lambda a, b: complex(1 if _real(a, "lt") < _real(b, "lt") else 0),
    "eq": lambda a, b: complex(1 if abs(a.real - b.real) <= 1e-9 * max(1, abs(a.real), abs(b.real)) else 0),
}
CONSTS = {"pi": complex(math.pi), "π": complex(math.pi), "j": 1j, "i": 1j, "e": complex(math.e)}

TOK = re.compile(r"\s*(?:(\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)([ji](?![A-Za-z0-9_]))?|([A-Za-z_αβγδεθλμρστφψωΩπΔ][A-Za-z0-9_αβγδεθλμρστφψωΩπΔ]*)|(.))")


def tokenize(s):
    s = s.replace("−", "-").replace("×", "*").replace("·", "*").replace("²", "^2").replace("³", "^3")
    out, pos = [], 0
    while pos < len(s):
        m = TOK.match(s, pos)
        if not m or m.end() == pos:
            if s[pos:].strip() == "":
                break
            raise ExprError(f"caractère illisible dans {s!r}")
        pos = m.end()
        num, imag, ident, other = m.groups()
        if num is not None:
            v = float(num)
            out.append(("num", complex(0, v) if imag else complex(v)))
        elif ident is not None:
            out.append(("id", ident))
        elif other is not None:
            if other.isspace():
                continue
            if other in "+-*/^∠°(),":
                out.append(("op", other))
            elif other == "√":
                out.append(("id", "sqrt"))
            else:
                raise ExprError(f"caractère « {other} » dans {s!r}")
    out.append(("end", None))
    return out


class Parser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self):
        return self.t[self.i]

    def next(self):
        self.i += 1
        return self.t[self.i - 1]

    def isop(self, o):
        k, v = self.peek()
        return k == "op" and v == o

    def top(self):
        a = self.add()
        if self.isop("∠"):
            self.next()
            b = self.add()
            return ("polar", a, b)
        return a

    def add(self):
        a = self.mul()
        while self.isop("+") or self.isop("-"):
            o = self.next()[1]
            a = (o, a, self.mul())
        return a

    def starts(self):
        k, v = self.peek()
        return k in ("num", "id") or (k == "op" and v == "(")

    def mul(self):
        a = self.unary()
        while True:
            if self.isop("*") or self.isop("/"):
                o = self.next()[1]
                a = (o, a, self.unary())
            elif self.starts():
                a = ("*", a, self.pow())
            else:
                return a

    def unary(self):
        if self.isop("-"):
            self.next()
            return ("neg", self.unary())
        if self.isop("+"):
            self.next()
            return self.unary()
        return self.pow()

    def pow(self):
        b = self.postfix()
        if self.isop("^"):
            self.next()
            return ("^", b, self.unary())
        return b

    def postfix(self):
        e = self.primary()
        while self.isop("°"):
            self.next()
            e = ("*", e, ("num", complex(math.pi / 180)))
        return e

    def primary(self):
        k, v = self.next()
        if k == "num":
            return ("num", v)
        if k == "id":
            if self.isop("("):
                self.next()
                args = []
                if not self.isop(")"):
                    args.append(self.top())
                    while self.isop(","):
                        self.next()
                        args.append(self.top())
                if not self.isop(")"):
                    raise ExprError("parenthèse manquante")
                self.next()
                return ("call", v, args)
            if v == "sqrt":
                return ("call", "sqrt", [self.pow()])
            return ("var", v)
        if k == "op" and v == "(":
            e = self.top()
            if not self.isop(")"):
                raise ExprError("parenthèse manquante")
            self.next()
            return e
        raise ExprError(f"symbole inattendu {v!r}")


_cache = {}


def parse(src):
    if src not in _cache:
        p = Parser(tokenize(src))
        e = p.top()
        if p.peek()[0] != "end":
            raise ExprError(f"symbole en trop dans {src!r}")
        _cache[src] = e
    return _cache[src]


def ev(node, env):
    k = node[0]
    if k == "num":
        return node[1]
    if k == "var":
        if node[1] in env:
            return env[node[1]]
        if node[1] in CONSTS:
            return CONSTS[node[1]]
        raise ExprError(f"variable inconnue {node[1]}")
    if k == "neg":
        return -ev(node[1], env)
    if k == "call":
        f = FUNCS.get(node[1])
        if f is None:
            raise ExprError(f"fonction inconnue {node[1]}")
        return f(*[ev(a, env) for a in node[2]])
    if k == "polar":
        return cmath.rect(ev(node[1], env).real, ev(node[2], env).real)
    a, b = ev(node[1], env), ev(node[2], env)
    if k == "+":
        return a + b
    if k == "-":
        return a - b
    if k == "*":
        return a * b
    if k == "/":
        if b == 0:
            return complex(float("nan"), float("nan"))
        return a / b
    if k == "^":
        if abs(a.imag) < 1e-12 and abs(b.imag) < 1e-12 and (a.real >= 0 or float(b.real).is_integer()):
            try:
                return complex(a.real ** b.real)
            except (OverflowError, ZeroDivisionError):
                return complex(float("nan"))
        if a == 0:
            return 0j
        return a ** b
    raise ExprError(k)


def evaluate(src, env):
    try:
        return ev(parse(src), env)
    except (ZeroDivisionError, OverflowError, ValueError) as e:
        raise ExprError(f"{src} : {e}")


def finite(z):
    return math.isfinite(z.real) and math.isfinite(z.imag)


TPL = re.compile(r"\[\[(=?)([^\[\]|]+?)(?::(\d+))?(?:\|([^\[\]]*))?\]\]")


def round_sig(x, sig):
    if x == 0 or not math.isfinite(x):
        return x
    return round(x, sig - 1 - int(math.floor(math.log10(abs(x)))))


def fmt_tpl(m, env):
    v = evaluate(m.group(2).strip(), env).real
    opts = (m.group(4) or "")
    if "bin" in opts:
        return bin(round(v))[2:]
    if "hex" in opts:
        return hex(round(v))[2:].upper()
    return f"{round_sig(v, int(m.group(3) or 3)):g}"


def draw(spec, rnd):
    if spec.get("values"):
        return float(rnd.choice(spec["values"]))
    lo, hi, st = spec["min"], spec["max"], spec.get("step")
    if st:
        n = int(math.floor((hi - lo) / st + 1e-9))
        return float(f"{lo + st * rnd.randint(0, n):.12g}")
    return lo + (hi - lo) * rnd.random()


def check_constraint(c, env):
    for op in (">=", "<=", "!=", ">", "<", "=="):
        i = c.find(op)
        if i > 0:
            x, y = evaluate(c[:i], env).real, evaluate(c[i + len(op):], env).real
            return {">=": x >= y, "<=": x <= y, "!=": abs(x - y) > 1e-12 * max(1, abs(x)), ">": x > y, "<": x < y,
                    "==": abs(x - y) <= 1e-12 * max(1, abs(x))}[op]
    raise ExprError(f"contrainte illisible {c}")


def block_strings(b):
    for k in ("text", "tex", "title", "caption", "xLabel", "yLabel"):
        if isinstance(b.get(k), str):
            yield b[k]
    for r in b.get("rows", []) or []:
        for c in r:
            if isinstance(c, str):
                yield c
    for c in b.get("curves", []) or []:
        if isinstance(c.get("label"), str):
            yield c["label"]


FORBIDDEN = ["TIA Portal", "Grafcet", "GRAFCET", "ladder", "Ladder", "câblage", "armoire électrique",
             "schéma de commande", "programmation d'automate", "programmer l'automate"]
BLOCK_TYPES = {"text", "tex", "formula", "tip", "warning", "method", "plot", "circuit", "table"}


def dollars(s):
    return len(re.findall(r"(?<!\\)\$", s))


def main():
    seeds = 50
    if "--seeds" in sys.argv:
        seeds = int(sys.argv[sys.argv.index("--seeds") + 1])
    notions = {n["id"]: n for n in json.loads((ROOT / "notions.json").read_text(encoding="utf-8"))["notions"]}
    index = json.loads((ROOT / "index.json").read_text(encoding="utf-8"))
    errors, warns = [], []
    ids = set()
    courses, exercises, examples = {}, {}, {}

    def notion_ok(where, ns):
        if not ns:
            errors.append(f"{where} : aucune notion")
        for n in ns:
            if n not in notions:
                errors.append(f"{where} : notion inconnue {n}")
            elif notions[n]["status"] in ("Hors programme", "Non exigible"):
                errors.append(f"{where} : notion {n} « {notions[n]['status']} »")

    def blocks_ok(where, blocks, templates):
        for b in blocks:
            if b.get("type") not in BLOCK_TYPES:
                errors.append(f"{where} : bloc inconnu {b.get('type')}")
            for s in block_strings(b):
                for t in FORBIDDEN:
                    if t in s:
                        warns.append(f"{where} : terme hors périmètre « {t} »")
                if dollars(s) % 2:
                    errors.append(f"{where} : $ non refermé dans {s[:60]!r}")
                if not templates and ("[[" in s or "]]" in s):
                    errors.append(f"{where} : modèle hors exercice")
            if b.get("type") == "plot":
                for c in b.get("curves", []):
                    try:
                        parse(c["expr"])
                        if not templates:
                            a0, a1 = float(b.get("from", 0)), float(b.get("to", 1))
                            for k in range(21):
                                t = a0 + (a1 - a0) * k / 20
                                if not finite(evaluate(c["expr"], {b.get("var", "t"): complex(t)})):
                                    raise ExprError(f"non définie en {t}")
                    except ExprError as e:
                        errors.append(f"{where} : courbe {e}")
            if b.get("type") == "circuit" and not b.get("parts"):
                errors.append(f"{where} : schéma vide")

    for p in index["packs"]:
        pk = json.loads((ROOT / p).read_text(encoding="utf-8"))
        for c in pk.get("courses", []):
            w = f"cours {c['id']}"
            if c["id"] in ids:
                errors.append(f"{w} : id en double")
            ids.add(c["id"])
            notion_ok(w, c["notions"])
            blocks_ok(w, c["blocks"], False)
            for n in c["notions"]:
                courses.setdefault(n, []).append(c["id"])
            if not c["blocks"]:
                errors.append(f"{w} : vide")
        for e in pk.get("examples", []):
            w = f"exemple {e['id']}"
            if e["id"] in ids:
                errors.append(f"{w} : id en double")
            ids.add(e["id"])
            notion_ok(w, e["notions"])
            blocks_ok(w, e["problem"] + e["solution"], False)
            for n in e["notions"]:
                examples.setdefault(n, []).append(e["id"])
            if not e["solution"]:
                errors.append(f"{w} : sans corrigé")
        for x in pk.get("exercises", []):
            w = f"exercice {x['id']}"
            if x["id"] in ids:
                errors.append(f"{w} : id en double")
            ids.add(x["id"])
            notion_ok(w, x["notions"])
            blocks_ok(w, x["statement"] + x["solution"], True)
            for n in x["notions"]:
                exercises.setdefault(n, []).append(x["id"])
            if not x["questions"]:
                errors.append(f"{w} : aucune question")
            if not x["solution"]:
                errors.append(f"{w} : pas de corrigé")
            units = {k: v.get("unit", "") for k, v in x.get("params", {}).items()}
            texts = [s for b in x["statement"] + x["solution"] for s in block_strings(b)] + [x.get("hint", ""), x.get("method", "")]
            for q in x["questions"]:
                texts += [q["prompt"]] + q.get("choices", [])
                if q["kind"] == "choice":
                    if len(q["choices"]) < 2 or len(set(q["choices"])) != len(q["choices"]):
                        errors.append(f"{w} {q['id']} : propositions invalides")
                elif not q.get("answer"):
                    errors.append(f"{w} {q['id']} : pas de réponse")
            rnd = random.Random(1)
            seen, flagged = set(), set()
            for s in range(seeds):
                env = None
                for _ in range(200):
                    try:
                        env = {k: complex(draw(v, rnd)) for k, v in x.get("params", {}).items()}
                        for k, v in x.get("vars", {}).items():
                            env[k] = evaluate(v, env)
                        if all(check_constraint(c, env) for c in x.get("constraints", [])):
                            break
                        env = None
                    except ExprError:
                        env = None
                if env is None:
                    errors.append(f"{w} : tirage impossible (contraintes ou calcul)")
                    break
                seen.add(tuple(sorted((k, round(v.real, 9)) for k, v in env.items() if k in x.get("params", {}))))
                try:
                    for t in texts:
                        for m in TPL.finditer(t):
                            v = evaluate(m.group(2).strip(), env)
                            if not finite(v):
                                raise ExprError(f"valeur non finie : {m.group(0)}")
                        left = TPL.sub("", t)
                        if "[[" in left or "]]" in left:
                            raise ExprError(f"modèle mal écrit : {t[:60]!r}")
                    for q in x["questions"]:
                        if q["kind"] == "choice":
                            if q.get("correctExpr"):
                                idx = round(evaluate(q["correctExpr"], env).real)
                                if not 0 <= idx < len(q["choices"]):
                                    raise ExprError(f"{q['id']} : bonne proposition hors liste")
                            vals = []
                            for c in q["choices"]:
                                vals.append(TPL.sub(lambda m: fmt_tpl(m, env), c))
                            if len(set(vals)) != len(vals) and ("dup", q["id"]) not in flagged:
                                flagged.add(("dup", q["id"]))
                                errors.append(f"{w} {q['id']} : propositions identiques au tirage ({vals})")
                            continue
                        v = evaluate(q["answer"], env)
                        if q["kind"] == "base":
                            if abs(v.imag) > 1e-9 or v.real < 0 or abs(v.real - round(v.real)) > 1e-9:
                                raise ExprError(f"{q['id']} : la réponse doit être un entier positif")
                            continue
                        if not finite(v):
                            raise ExprError(f"{q['id']} : réponse non finie")
                        if q["kind"] == "numeric" and abs(v.imag) > 1e-9 * max(1, abs(v)):
                            raise ExprError(f"{q['id']} : réponse complexe pour une question numérique")
                        sig = q.get("sig", 3)
                        shown = complex(round_sig(v.real, sig), round_sig(v.imag, sig) if q["kind"] == "complex" else 0)
                        tol = q.get("tolerance", 0.02)
                        if abs(shown - v) > tol * max(abs(v), 1e-300) + 1e-15 and q["id"] not in flagged:
                            flagged.add(q["id"])
                            errors.append(f"{w} {q['id']} : arrondi à {sig} chiffres ({shown}) hors tolérance {tol} (attendu {v})")
                    for b in x["statement"] + x["solution"]:
                        if b.get("type") == "plot":
                            a0 = b.get("from", 0)
                            a1 = b.get("to", 1)
                            a0 = a0 if isinstance(a0, (int, float)) else evaluate(a0, env).real
                            a1 = a1 if isinstance(a1, (int, float)) else evaluate(a1, env).real
                            for c in b["curves"]:
                                for k in range(21):
                                    t = a0 + (a1 - a0) * k / 20
                                    if not finite(evaluate(c["expr"], {**env, b.get("var", "t"): complex(t)})):
                                        raise ExprError("courbe non définie")
                except ExprError as e:
                    errors.append(f"{w} : {e}")
                    break
            if x.get("params", {}) and len(seen) < 3:
                warns.append(f"{w} : moins de 3 énoncés différents")

    prog = [n for n in notions.values() if n["status"] not in ("Hors programme", "Non exigible")]
    missing = [n["id"] for n in prog if n["id"] not in courses or len(exercises.get(n["id"], [])) < 2]
    done = len(prog) - len(missing)
    print(f"Contenu : {sum(len(v) for v in courses.values())} rattachements de cours, "
          f"{len(set(i for v in exercises.values() for i in v))} exercices, {len(set(i for v in examples.values() for i in v))} exemples")
    print(f"Notions au programme avec cours + ≥ 2 exercices : {done} / {len(prog)}")
    if "--coverage" in sys.argv and missing:
        print("Manquantes :", " ".join(missing))
    for e in errors:
        print("ERREUR", e)
    for w in warns:
        print("alerte", w)
    print(f"{len(errors)} erreur(s), {len(warns)} alerte(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
