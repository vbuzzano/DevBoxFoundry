# Specification: Module System Alignment

**Purpose**: Formalize the work needed to align the module system implementation with the behavior documented in `MODULES.md` and the gaps identified in `MODULES-GAP-ACTION.md`.

## Contexte et objectifs
- Garantir la découverte dynamique des commandes (aucun registre statique) pour modules simples et partagés.
- Rendre explicite le contrat des modules partagés via `metadata.psd1` et valider sa présence/clé.
- Préserver le registre embedded (`Register-EmbeddedCommands`) pour les builds embarqués.
- S’assurer que le dispatcher `pkg` couvre toutes les commandes déclarées.
- Sécuriser l’ordre d’override `.box/modules` → shared → core.

## Portée
- Chargement et découverte des modules (box et boxer).
- Modules partagés et leur metadata (`modules/shared/**/metadata.psd1`).
- Dispatchers CLI et enregistrement des commandes (runtime et embedded).
- Priorité de chargement et overrides.
- Documentation associée.

### Hors périmètre
- Ajout de nouvelles fonctionnalités pkg ou box/boxer hors dispatch existant.
- Refactoring large du core non lié à la découverte/dispatch.
- Changements de format de state/config.

## Exigences fonctionnelles
1. Découverte dynamique
   - Le système doit enregistrer les commandes de modules simples via le nom de fichier `modules/<mode>/<cmd>.ps1` → `Invoke-<Mode>-<Cmd>`.
   - Aucun registre statique ne doit être introduit pour les commandes.

2. Modules partagés et metadata
   - Chaque module partagé doit contenir `metadata.psd1` avec au minimum `ModuleName` et `Commands` renseignés.
   - Le chargement doit échouer avec message clair si `metadata.psd1` est absent ou incomplet.

3. Enregistrement embedded
   - En mode embedded, le système doit scanner les fonctions `Invoke-<Mode>-*` et enregistrer les commandes sans lecture disque, en supprimant le suffixe de sous-commande après le premier tiret.

4. Dispatcher pkg
   - `Invoke-Box-Pkg` doit router `install`, `uninstall`, `list`, `validate`, `state` conformément aux entrées de `modules/shared/pkg/metadata.psd1`.
   - Appel sans sous-commande ou sous-commande inconnue doit afficher l’aide pkg.

5. Priorité d’override
   - L’ordre de résolution doit rester `.box/modules` (projet) > `modules/<mode>` (core) > modules partagés.
   - Le système doit tracer/logguer quand un override de module est appliqué.

## Exigences non fonctionnelles
- Compatibilité existante préservée (pas de régression sur install/profile/versioning déjà en place).
- Messages d’erreur explicites pour les validations metadata et sous-commandes inconnues.
- Documentation mise à jour pour refléter les règles (référence à `MODULES.md`).

## Assomptions
- Structure des répertoires actuelle (`modules/<mode>`, `modules/shared`) est conservée.
- Les builds embedded conservent la disponibilité des fonctions déjà chargées en mémoire.
- Les tests existants couvrent les chemins principaux box/boxer (à compléter pour overrides et pkg).

## Risques
- Régressions possibles sur chargement embedded si la logique de scan est modifiée sans tests.
- Modules partagés existants sans metadata pourraient casser au moment de l’ajout de validations (prévoir migration ou exception contrôlée).
- Overrides projet mal nommés pourraient masquer des commandes si non validés.

## Critères d’acceptation
- Tous les modules partagés chargés disposent d’un `metadata.psd1` valide ; absence ou clé manquante provoque une erreur claire et testée.
- En embedded, les commandes sont enregistrées via scan des fonctions sans accès disque, et les sous-commandes sont correctement tronquées au premier tiret.
- `box pkg` :
  - `box pkg install <name>` installe le paquet ;
  - `list`, `validate`, `uninstall <name>`, `state` fonctionnent ;
  - appel sans sous-commande affiche l’aide.
- Overrides : un module présent dans `.box/modules` remplace le module core homonyme ; ce comportement est couvert par un test.
- Aucune liste statique de commandes n’est introduite ; la découverte reste runtime par fichiers/metadata ou scan embedded.

## Livrables
- Code : validations metadata, maintien du scan embedded, éventuels logs/trace override, ajustements dispatcher pkg si besoin.
- Tests : cas de succès/échec metadata, override `.box/modules`, dispatcher pkg (sous-commandes valides et inconnues), scan embedded si possible.
- Docs : référence à `MODULES.md` depuis la spec/notes de release, mention des validations ajoutées.
