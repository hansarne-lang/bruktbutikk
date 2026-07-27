# Kom i gang – Bruktbutikk-spillet

## 1. Opprett GitHub-repo

Gå til https://github.com/new og lag et nytt repo:
- **Repository name:** `bruktbutikk-spill`
- **Visibility:** Private (anbefalt mens spillet er under utvikling)
- **IKKE** huk av for README eller .gitignore (vi har dem allerede)

## 2. Initialiser git lokalt

Åpne terminal/kommandolinje i mappen `bruktbutikk-spill/` og kjør:

```bash
git init
git add .
git commit -m "første commit – prosjektstruktur"
git branch -M main
git remote add origin https://github.com/hansarne-lang/bruktbutikk-spill.git
git push -u origin main
```

## 3. Åpne i Godot

1. Start Godot
2. Klikk **Import**
3. Naviger til `bruktbutikk-spill/` og velg `project.godot`
4. Klikk **Import & Edit**

Godot oppretter da en `.godot/`-mappe (ignoreres av git via .gitignore).

## 4. Legg til Autoloads i Godot

Godot må vite om de globale scriptene. Gå til:
**Project → Project Settings → Autoload** og legg til:

| Navn          | Fil                              |
|---------------|----------------------------------|
| SaveManager   | res://scripts/SaveManager.gd     |
| DataLoader    | res://scripts/DataLoader.gd      |

## 5. Eksporter regnearket til CSV (for bruk i spillet)

Spillets `DataLoader.gd` leser CSV-filer fra `data/`-mappen.
Når du oppdaterer `game_data.xlsx`:

1. Åpne `data/game_data.xlsx`
2. For hver fane (Items, Rooms, Characters, Settings):
   - Gå til fanen
   - **File → Save As → CSV**
   - Lagre som `data/items.csv`, `data/rooms.csv` osv.
3. Commit og push til GitHub

## 6. Arbeidsflyt fremover

```
Ny funksjon?  →  lag branch:  git checkout -b feature/butikk-vareplassering
Ferdig?       →  push:        git push origin feature/butikk-vareplassering
                              → Lag Pull Request på GitHub
                              → GitHub Actions sjekker automatisk ✅
```

## Prosjektstruktur

```
bruktbutikk-spill/
├── project.godot              ← Godot-prosjektfil
├── .gitignore
├── .github/workflows/ci.yml  ← Automatisk CI/CD
├── data/
│   ├── game_data.xlsx         ← Rediger her for nye items/rom/karakterer
│   ├── items.csv              ← Eksporter fra xlsx
│   ├── rooms.csv
│   ├── characters.csv
│   └── settings.csv
├── scenes/
│   ├── main_menu/             ← Hovedmeny (Nytt spill, Lagre, Last inn, Innstillinger)
│   ├── shop/                  ← Del 1: Bruktbutikken
│   ├── cleanup/               ← Del 2: Rydding av hus/dødsbo
│   └── home/                  ← Del 3: Familielivet
├── scripts/
│   ├── SaveManager.gd         ← Autoload: lagring og lasting
│   ├── DataLoader.gd          ← Autoload: leser CSV fra regnearket
│   ├── main_menu/
│   ├── shop/
│   ├── cleanup/
│   └── home/
└── assets/
    ├── images/
    └── audio/
```
