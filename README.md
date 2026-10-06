# 📞 takephone

> Tool rund ums Telefon – Anrufe, Kontakte und Automatisierung an einem Ort.

Teil der [MountainV](https://github.com/MountainV)-Organisation.

## Was ist takephone?

takephone ist unser internes Werkzeug, um Telefon-Workflows zu steuern:
Anrufe verwalten, Kontakte organisieren und wiederkehrende Abläufe
automatisieren.

## Branches

| Branch | Zweck |
|--------|-------|
| `main` | stabile, veröffentlichte Version |
| `develop` | aktueller Entwicklungsstand (**takephonedev**) |
| `feat/*` | einzelne Features |
| `fix/*` | Fehlerbehebungen |

Entwickelt wird auf `develop`; stabile Stände werden nach `main` gemergt.

## Entwicklung

```bash
git clone https://github.com/MountainV/takephone.git
cd takephone
git checkout develop
```

Siehe den [Git-Workflow](https://github.com/MountainV/docs/blob/main/docs/guides/git-workflow.md)
in der zentralen Doku.

## Struktur

```
takephone/
├─ src/        Quellcode
├─ docs/       projektspezifische Doku
└─ README.md
```
