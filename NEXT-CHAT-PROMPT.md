# PROMPT POUR NOUVEAU CHAT - DevBox-Foundry

Copie-colle ce prompt au démarrage du nouveau chat:

---

Bonjour! Je travaille sur le projet **DevBox-Foundry** - un système de workspace bootstrap PowerShell pour développement cross-platform (Windows/Amiga).

## Contexte Actuel

**Repo**: `c:\Users\reddoc\Projects\amiga-projects\DevBoxFoundry`
**Branch**: `main`
**Dernier commit**: `e7e5d09` - Documentation updates

J'ai complété les Specs 001 (Compilation) et 002 (Installer). Je suis maintenant sur **Spec 003 - Template System**.

## Spec 003 - État Actuel

**Phase 0-2**: ✅ COMPLÈTES (21/21 tasks)
- Phase 0: 7 fonctions template dans `devbox/inc/templates.ps1`
- Phase 1: Commande `box env update` fonctionnelle (régénère tous les templates)
- Phase 2: Commande `box template apply <name>` fonctionnelle (régénère un template spécifique)

**Phase 3-4**: ⏳ À FAIRE (22 tasks restantes)
- Phase 3: Gestion d'erreurs et cas limites (11 tasks)
- Phase 4: Intégration finale et tests (11 tasks)

## Ce Qui Fonctionne Déjà

✅ Template discovery (patterns `*.template` et `*.template.md`)
✅ Variable loading (.env + config.box → hashtable)
✅ Token replacement ({{VAR}} → valeur)
✅ Backups automatiques (.bak.timestamp)
✅ Headers de génération (commentaires "DO NOT EDIT")
✅ Logging ASCII-safe (pas d'emojis)
✅ Build system (dist/box.ps1 compile, 78.31 KB)

## Problèmes Résolus (À Ne Pas Refaire)

1. ✅ Emoji encoding → Utiliser ASCII-safe ([OK], [ERR], etc.)
2. ✅ Export-ModuleMember → NE PAS utiliser (dot-sourcing, pas import module)
3. ✅ Template discovery → Pattern `*.template*` pour extensions composées
4. ✅ Path resolution → Gestion Makefile.template ET README.template.md

## Ce Qu'il Faut Faire (Phase 3)

**Fichiers à modifier**:
- `devbox/inc/templates.ps1` - Fonctions core
- `devbox/inc/commands.ps1` - Invoke-EnvUpdate, Invoke-TemplateApply

**Tasks Phase 3** (voir `specs/003-template-system/tasks.md` T032-T042):
- Gérer tokens inconnus {{UNKNOWN}} → warning + laisser tel quel
- Validation case sensitivity
- Détection références circulaires
- Caractères spéciaux dans valeurs
- Erreurs permissions (backup/write)
- Validation encoding UTF-8
- Fichiers .env ou config.box manquants
- Fichiers très larges (>10MB)

## Fichier de Référence Complet

**Lis d'abord**: `start.md` - Contient:
- Status détaillé de tous les specs
- Détails techniques Phase 1-2
- Evidence de tests
- Standards de code
- Instructions de build

## Ce Que Tu Dois Faire

1. Lis `start.md` pour le contexte complet
2. Lis `specs/003-template-system/tasks.md` lignes 84-105 (Phase 3)
3. Lis `specs/003-template-system/plan.md` pour les décisions techniques
4. Implémente Phase 3: gestion d'erreurs robuste
5. Teste avec build: `.\scripts\build-box.ps1`
6. Marque les tasks complètes dans tasks.md
7. Commit propre

## Standards Importants

- Code EN ANGLAIS, discussion en FRANÇAIS
- UTF-8 encoding partout
- Try/catch sur opérations risquées
- Pas d'emojis dans output console
- LF line endings (\n)
- Utilise TODO lists pour tracker le travail

## Question de Démarrage

**Peux-tu commencer par lire `start.md` puis `specs/003-template-system/tasks.md` Phase 3, et me proposer un plan pour implémenter la gestion d'erreurs robuste?**

---

Fin du prompt. Prêt pour nouveau chat! 🚀
