"""Petit langage pour écrire le contenu de BTS Électro Coach en Python.

Les textes acceptent le LaTeX en ligne entre $…$ (écrire les chaînes en r"…"),
**gras**, listes « - » et « 1. ». Dans un exercice, [[R]] affiche un paramètre
et [[=expr:3|Ω]] une valeur calculée (3 chiffres significatifs, unité, préfixe SI).

Pour un QCM, la PREMIÈRE proposition est la bonne : l'application mélange
l'ordre à l'affichage.
"""


def T(text):
    return {"type": "text", "text": text}


def TEX(tex):
    return {"type": "tex", "tex": tex}


def F(tex, title=""):
    return {"type": "formula", "tex": tex, "title": title}


def TIP(text, title=""):
    return {"type": "tip", "text": text, "title": title}


def WARN(text, title=""):
    return {"type": "warning", "text": text, "title": title}


def METHOD(text, title="Méthode"):
    return {"type": "method", "text": text, "title": title}


def TABLE(*rows):
    return {"type": "table", "rows": [list(r) for r in rows]}


def PLOT(curves, frm, to, var="t", title="", xl="", yl="", samples=240):
    """curves : liste de (expression, légende)."""
    return {"type": "plot", "var": var, "from": frm, "to": to, "title": title, "xLabel": xl, "yLabel": yl,
            "samples": samples, "curves": [{"expr": e, "label": l} for e, l in curves]}


def CIRCUIT(parts, kind="series", source="ac", caption=""):
    """parts : liste de (type, étiquette) avec type R, L ou C."""
    return {"type": "circuit", "kind": kind, "source": source, "caption": caption,
            "parts": [{"type": t, "label": l} for t, l in parts]}


def _ids(n):
    return [n] if isinstance(n, str) else list(n)


def course(id, notions, title, *blocks):
    return {"id": id, "notions": _ids(notions), "title": title, "validated": False, "blocks": list(blocks)}


def example(id, notions, title, problem, solution):
    return {"id": id, "notions": _ids(notions), "title": title, "validated": False,
            "problem": list(problem), "solution": list(solution)}


def P(min=None, max=None, step=None, values=None, unit=""):
    d = {"unit": unit}
    if values is not None:
        d["values"] = list(values)
    else:
        d.update({"min": min, "max": max})
        if step is not None:
            d["step"] = step
    return d


def num(id, prompt, answer, unit="", tol=0.02, sig=3):
    return {"id": id, "kind": "numeric", "prompt": prompt, "answer": answer, "unit": unit, "tolerance": tol, "sig": sig}


def cplx(id, prompt, answer, tol=0.01, sig=3, polar=False):
    return {"id": id, "kind": "complex", "prompt": prompt, "answer": answer, "tolerance": tol, "sig": sig, "polar": polar}


def base(id, prompt, answer, b=2):
    """Entier à écrire en base 2 ou 16."""
    return {"id": id, "kind": "base", "prompt": prompt, "answer": answer, "base": b}


def mcq(id, prompt, *choices):
    """La première proposition est la bonne."""
    return {"id": id, "kind": "choice", "prompt": prompt, "choices": list(choices), "correct": 0}


def ex(id, notions, title, diff=1, params=None, vars=None, constraints=None, statement=(), questions=(),
       hint="", method="", solution=()):
    return {"id": id, "notions": _ids(notions), "title": title, "difficulty": diff, "validated": False,
            "params": params or {}, "vars": vars or {}, "constraints": list(constraints or []),
            "statement": list(statement), "questions": list(questions), "hint": hint, "method": method,
            "solution": list(solution)}


def pack(id, courses=(), examples=(), exercises=()):
    return {"id": id, "courses": list(courses), "examples": list(examples), "exercises": list(exercises)}


def yesno(id, prompt, cond):
    """QCM Oui / Non ; cond est une expression qui vaut 1 si la réponse est Oui."""
    return {"id": id, "kind": "choice", "prompt": prompt, "choices": ["Oui", "Non"], "correct": 0,
            "correctExpr": f"1 - ({cond})"}
