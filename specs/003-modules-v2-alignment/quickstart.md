# Quickstart — Module System v2 Alignment

1) **Lire les références**
- `MODULES2.md` (architecture v2), `docs/modules-overview.md`, `docs/modules-development.md`, `docs/modules-embedded.md`, `docs/modules-metadata.md`.

2) **Mettre à jour le bootstrapper**
- Adapter `boxing.ps1` pour exécuter directement les scripts externes (single-file et dossiers) et conserver la priorité externe > embarqué.
- Conserver l’enregistrement des fonctions `Invoke-{Mode}-*` pour les modules embarqués.

3) **Aligner les scripts de build**
- `scripts/build-boxer.ps1` et `scripts/build-box.ps1`: s’assurer que seuls les modules embarqués sont enveloppés en fonctions, aide commentée préservée, flags embedded définis.

4) **Valider le metadata pkg**
- Vérifier `modules/shared/pkg/metadata.psd1` contre le schéma (`ModuleName`, `Version`, `Commands`, handlers/dispatcher/subcommands exclusifs, hooks optionnels).

5) **Tests**
- Exécuter la suite Pester (`Invoke-Pester`) après modifications.
- Vérifier le build mono-fichier: `Invoke-Pester -Script tests/test-build-artifacts.ps1` (assure `$script:IsEmbedded`, wrappers et pkg embarqué).
- Tests spec-003: `Invoke-Pester -Script tests/test-module-discovery-v2.ps1, tests/test-module-loader.ps1, tests/test-build-artifacts.ps1, tests/test-bootstrapper.ps1, tests/test-pkg-module.ps1 -Passthru` (44 tests de validation).
- Capturer les résultats globaux: `Invoke-Pester -Script tests/*.ps1 -Passthru *> tests/TEST-RESULTS-v2.txt`.
- Scénarios manuels: `boxer install`, `box pkg install <pkg>`, module externe simple (`modules/hello.ps1`), module dossier (`modules/foo/bar.ps1`), metadata dispatcher.

6) **Critères de validation**
- Rétrocompatibilité: commandes embarquées inchangées.
- External simple: script s’exécute sans wrapper.
- Priorité: module externe remplace embarqué si même nom.
- Help: `Get-Help` fonctionne pour fonctions et scripts; `help.ps1` pris en compte.
