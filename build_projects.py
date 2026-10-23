"""
build_projects.py — génère le contenu de la page Projects à partir du fichier Excel.

Lancé automatiquement par Quarto avant chaque rendu (voir « pre-render » dans
_quarto.yml), en local comme sur GitHub. Il n'utilise que Python standard :
rien à installer.

Fichier lu : Projets_complete.xlsx (première feuille), colonnes :
  A Titre du projet        F Financements
  B Image                  G Collaborateur          (un par ligne)
  C Titre du sous-projet   H Liens collaborateurs   (un par ligne, même ordre que G)
  D Period                 I Students               (un par ligne)
  E Affiliations           J Publications associées (DOI ou liens, un par ligne)

Règles :
  - Une ligne dont la colonne A est vide appartient au projet de la ligne du dessus.
    Un projet avec plusieurs lignes devient une « Research line » avec des sous-projets.
  - « (PhD project) », « (Master project) »… en fin de titre s'affichent dans la
    pastille de période.
  - « Titre: sous-titre » est coupé en titre + sous-titre.
  - Une période qui finit par « - » s'affiche « … – present ».
  - Les DOI de la colonne J sont transformés en « Auteur et al. année · Revue »
    à partir des fichiers .bib de la page Publications.
"""

import json
import re
import subprocess
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

XLSX = Path("Projets_complete.xlsx")
BIB_FILES = [Path("Mes_Publications.bib"), Path("publications-extra.bib")]
OUTPUT = Path("projects.qmd")
IMAGE_DIR = "images/"

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"


# --------------------------------------------------------------------------
# Reading the spreadsheet (standard library only)
# --------------------------------------------------------------------------
def read_xlsx(path):
    with zipfile.ZipFile(path) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.findall("m:si", NS):
                shared.append("".join(t.text or "" for t in si.iter(f"{{{NS['m']}}}t")))
        # first worksheet listed in the workbook
        wb = ET.fromstring(z.read("xl/workbook.xml"))
        first = wb.find("m:sheets/m:sheet", NS)
        rid = first.get(REL_NS)
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        target = next(r.get("Target") for r in rels if r.get("Id") == rid)
        target = target.lstrip("/")
        sheet_path = target if target.startswith("xl/") else "xl/" + target
        sheet = ET.fromstring(z.read(sheet_path))

    rows = {}
    for c in sheet.iter(f"{{{NS['m']}}}c"):
        ref = c.get("r")
        col = re.match(r"[A-Z]+", ref).group()
        row = int(re.search(r"\d+", ref).group())
        t = c.get("t")
        if t == "s":
            v = c.find("m:v", NS)
            val = shared[int(v.text)] if v is not None else ""
        elif t == "inlineStr":
            val = "".join(x.text or "" for x in c.iter(f"{{{NS['m']}}}t"))
        else:
            v = c.find("m:v", NS)
            val = v.text if v is not None else ""
        rows.setdefault(row, {})[col] = (val or "").strip()
    return [rows[r] for r in sorted(rows)]


# --------------------------------------------------------------------------
# Publication labels from the .bib files
# --------------------------------------------------------------------------
def load_publications():
    pubs = {}
    for bib in BIB_FILES:
        if not bib.exists():
            continue
        try:
            out = subprocess.run(
                ["quarto", "pandoc", str(bib), "-f", "bibtex", "-t", "csljson"],
                capture_output=True, text=True, check=True,
            ).stdout
        except Exception:
            continue
        for e in json.loads(out):
            doi = (e.get("DOI") or "").lower()
            if doi:
                pubs[doi] = e
    return pubs


def pub_label(entry):
    authors = entry.get("author") or []
    fams = [a.get("family") or a.get("literal") or "" for a in authors]
    if len(fams) == 1:
        who = fams[0]
    elif len(fams) == 2:
        who = f"{fams[0]} & {fams[1]}"
    else:
        who = f"{fams[0]} et al."
    year = ""
    parts = (entry.get("issued") or {}).get("date-parts") or []
    if parts and parts[0]:
        year = str(parts[0][0])
    venue = entry.get("container-title") or ""
    if entry.get("type") == "thesis":
        venue = "PhD dissertation"
        return f"{md(who)} {year} · {venue}"
    return f"{md(who)} {year} · *{md(venue)}*" if venue else f"{md(who)} {year}"


# --------------------------------------------------------------------------
# Text helpers
# --------------------------------------------------------------------------
def md(s):
    """Escape characters that Markdown would interpret."""
    s = s.replace("\\", "\\\\")
    for ch in "*_[]`<>#":
        s = s.replace(ch, "\\" + ch)
    return s


def lines(s):
    return [x.strip() for x in (s or "").splitlines() if x.strip()]


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    words = re.sub(r"[^a-z0-9]+", " ", s).split()
    return "-".join(words[:4]) or "project"


KIND_RE = re.compile(r"\s*\(([^()]*\bproject)\)\s*$", re.I)


def split_kind(title):
    """'Foo (PhD project)' -> ('Foo', 'PhD project')."""
    m = KIND_RE.search(title or "")
    if m:
        k = m.group(1).strip()
        return title[: m.start()].strip(), k[:1].upper() + k[1:]
    return (title or "").strip(), ""


def split_title(title):
    """'Foo: bar baz' -> ('Foo', 'Bar baz')."""
    if ": " in title:
        a, b = title.split(": ", 1)
        return a.strip(), b[:1].upper() + b[1:]
    return title, ""


def fmt_period(p):
    p = (p or "").strip()
    if not p:
        return ""
    p = p.replace("Noveamber", "November")
    if re.search(r"-\s*$", p):
        start = p.rstrip(" -")
        years = re.findall(r"\d{4}", start)
        import datetime
        if years and int(years[-1]) > datetime.date.today().year:
            return "Starting " + start          # project not started yet
        return start + " – present"
    p = re.sub(r"\s+-\s+", " – ", p)
    return p


def fmt_funding(f):
    return re.sub(r"^\s*funded by (the )?", "", f or "", flags=re.I).strip()


# --------------------------------------------------------------------------
# Building blocks
# --------------------------------------------------------------------------
def fact(label, body):
    return f"::: {{.fact}}\n[{label}]{{.fact-label}}\n\n{body}\n:::\n"


def collaborators(names, links):
    chips = []
    for i, name in enumerate(names):
        link = links[i] if i < len(links) else ""
        if link.startswith("http"):
            chips.append(f"[{md(name)}]({link}){{.chip}}")
        else:
            chips.append(f"[{md(name)}]{{.chip}}")
    return " ".join(chips)


def publications(items, pubs):
    pills = []
    for raw in items:
        m = re.search(r"10\.\d{4,9}/\S+", raw)
        if m:
            doi = m.group().rstrip(".").lower()
            entry = pubs.get(doi)
            label = pub_label(entry) if entry else md("doi:" + m.group())
            pills.append(f"[{label}](https://doi.org/{m.group()}){{.pill}}")
        elif raw.endswith(".qmd") or ".qmd#" in raw:
            pills.append(f"[In the media → Outreach]({raw}){{.pill .pill-alt}}")
        elif raw.startswith("http"):
            host = re.sub(r"^https?://(www\.)?", "", raw).split("/")[0]
            pills.append(f"[{md(host)}]({raw}){{.pill}}")
    return " ".join(pills)


def card(row, title, subtitle, kind, level, pubs, anchor):
    period = fmt_period(row.get("D"))
    pill = " · ".join(x for x in (kind, period) if x)
    image = row.get("B", "")
    hashes = "#" * level

    out = [f"::: {{.proj #{anchor}}}\n"]
    if image:
        src = image if "/" in image else IMAGE_DIR + image
        out.append(f"::: {{.proj-banner}}\n![]({src}){{.proj-img fig-alt=\"{md(title)}\"}}\n")
    else:
        out.append("::: {.proj-banner .no-image}\n")
    out.append("::: {.proj-banner-text}")
    if pill:
        out.append(f"[{md(pill)}]{{.proj-period}}\n")
    out.append(f"{hashes} {md(title)}\n")
    if subtitle:
        out.append(f"[{md(subtitle)}]{{.proj-subtitle}}")
    out.append(":::\n:::\n")

    facts = []
    aff = lines(row.get("E"))
    if aff:
        facts.append(fact("Affiliations" if len(aff) > 1 else "Affiliation",
                          "\n\n".join(md(a) for a in aff)))
    fund = fmt_funding(row.get("F"))
    if fund:
        facts.append(fact("Funding", md(fund)))
    names = lines(row.get("G"))
    if names:
        facts.append(fact("Collaborators", collaborators(names, lines(row.get("H")))))
    students = lines(row.get("I"))
    if students:
        facts.append(fact("Students", "\n".join("- " + md(s) for s in students)))

    pub_items = lines(row.get("J"))
    out.append("::: {.proj-body}")
    if facts:
        out.append("::: {.proj-facts}\n" + "\n".join(facts) + ":::\n")
    if pub_items:
        out.append("::: {.proj-pubs}\n[Related publications]{.fact-label}\n\n"
                   + publications(pub_items, pubs) + "\n:::\n")
    out.append(":::\n\n:::\n")
    return "\n".join(out)


# --------------------------------------------------------------------------
def main():
    if not XLSX.exists():
        print(f"build_projects.py: {XLSX} not found, projects.qmd left unchanged")
        return

    rows = read_xlsx(XLSX)
    header, data = rows[0], rows[1:]

    # group rows: an empty column A continues the project above
    groups = []
    for r in data:
        if not any(r.get(c) for c in "ABCDEFGHIJ"):
            continue
        if r.get("A") or not groups:
            groups.append([r])
        else:
            groups[-1].append(r)

    pubs = load_publications()
    used = set()

    def unique(s):
        base = slug(s)
        a, i = base, 2
        while a in used:
            a, i = f"{base}-{i}", i + 1
        used.add(a)
        return a

    nav, body = [], []
    for g in groups:
        top_title, top_kind = split_kind(g[0].get("A", ""))
        if len(g) == 1:
            r = g[0]
            sub_title, sub_kind = split_kind(r.get("C", ""))
            title, subtitle = top_title, sub_title
            if not subtitle:
                title, subtitle = split_title(top_title)
            anchor = unique(title)
            nav.append((split_title(title)[0], anchor))
            body.append(card(r, title, subtitle, top_kind or sub_kind, 2, pubs, anchor))
        else:
            anchor = unique(top_title)
            nav.append((top_title, anchor))
            parts = [f"::: {{.proj-group #{anchor}}}\n",
                     "[Research line]{.proj-group-label}\n",
                     f"## {md(top_title)} {{.proj-group-title}}\n"]
            for r in g:
                sub_title, sub_kind = split_kind(r.get("C", ""))
                title, subtitle = split_title(sub_title)
                parts.append(card(r, title, subtitle, sub_kind, 3, pubs, unique(title)))
            parts.append(":::\n")
            body.append("\n".join(parts))

    out = ['---\ntitle: "Projects"\n---\n',
           "<!-- Page générée automatiquement par build_projects.py à partir de "
           f"{XLSX}.\n     Ne pas modifier ce fichier : modifiez le fichier Excel. -->\n",
           "::: {.proj-nav}\n" + "\n".join(f"[{md(t)}](#{a})" for t, a in nav) + "\n:::\n"]
    out += body
    OUTPUT.write_text("\n".join(out), encoding="utf-8")
    print(f"build_projects.py: {len(groups)} projects written to {OUTPUT}")


if __name__ == "__main__":
    main()
