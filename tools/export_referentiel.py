"""Convertit le classeur de couverture (onglet « Couverture ») en notions.json.

Usage : python tools/export_referentiel.py couverture.xlsx
(télécharger le classeur Claude Sheets en .xlsx, puis lancer ce script :
 le fichier app/assets/content/notions.json est réécrit).
"""
import json
import pathlib
import sys

from openpyxl import load_workbook

COLS = {
    "ID": "id", "Matière": "subject", "Domaine": "domain", "Chapitre": "chapter",
    "Sous-chapitre (notion)": "title", "Année indicative": "year", "Statut de validation": "status",
    "Compétences attendues": "skills", "Formules et méthodes": "formulas", "Prérequis": "prerequisites",
    "Référence officielle": "reference", "Fiabilité de l'inventaire": "inventory", "Remarque": "remark",
}


def year(v):
    v = (v or "").strip()
    if v.startswith("1re"):
        return 1
    if v.startswith("2e"):
        return 2
    return None


def main(path):
    ws = load_workbook(path, data_only=True)["Couverture"]
    rows = list(ws.iter_rows(values_only=True))
    head = [str(h).strip() if h else "" for h in rows[0]]
    idx = {COLS[h]: i for i, h in enumerate(head) if h in COLS}
    missing = set(COLS.values()) - set(idx)
    if missing:
        sys.exit(f"Colonnes absentes : {sorted(missing)}")
    out = []
    for r in rows[1:]:
        g = lambda k: (r[idx[k]] if r[idx[k]] is not None else "")
        if not g("id"):
            continue
        prer = [p.strip() for p in str(g("prerequisites")).split(";") if p.strip() and p.strip() != "Aucun"]
        out.append({
            "id": str(g("id")).strip(),
            "subject": g("subject"), "domain": g("domain"), "chapter": g("chapter"), "title": g("title"),
            "year": year(str(g("year"))), "status": g("status"), "skills": g("skills"), "formulas": g("formulas"),
            "prerequisites": prer, "reference": g("reference"),
            "inventoryChecked": not str(g("inventory")).startswith("À vérifier"),
            "remark": g("remark"),
        })
    dest = pathlib.Path(__file__).resolve().parent.parent / "app/assets/content/notions.json"
    dest.write_text(json.dumps({"source": "Classeur de couverture BTS Électro Coach", "notions": out},
                               ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(out)} notions écrites dans {dest}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "couverture.xlsx")
