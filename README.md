# BTS Électro Coach

Application de révision **Android + Windows** couvrant le programme officiel de
**mathématiques** et de **sciences appliquées (physique-chimie)** du BTS Électrotechnique
(référentiel de l'arrêté du 21 février 2020 modifié, applicable à la session 2027 ;
programme de mathématiques de l'arrêté du 4 juin 2013).

Hors périmètre, par choix : automatisme, programmation d'automates, câblage,
schémas de commande et de puissance en TP, conception d'armoires.

## Téléchargement

Page [Releases](../../releases) :

| Plateforme | Fichier |
|---|---|
| Windows 10 / 11 | `ElectroCoach-Setup-x.y.z.exe` — installateur sans droits admin, **désinstalleur inclus** |
| Windows sans installation | `ElectroCoach-x.y.z-portable.zip` — avec `DESINSTALLER-PORTABLE.bat` |
| Android 7.0+ | `ElectroCoach-x.y.z.apk` |

Désinstaller (Windows) : menu Démarrer > « Désinstaller BTS Électro Coach », ou
Paramètres > Applications. Le désinstalleur propose de garder ou d'effacer la progression.

## État (v0.1.0 — socle technique)

- Référentiel complet : 175 lignes, **163 notions au programme** (`app/assets/content/notions.json`,
  exporté du classeur de couverture).
- Moteur d'exercices : valeurs tirées au hasard, réponses numériques avec unité et préfixe SI
  (`4,7 kΩ`), réponses complexes (`3 + j4`, `5∠53°`), QCM, indice, méthode, corrigé.
- **Chaque corrigé est recalculé automatiquement** sur 50 tirages à chaque modification (CI).
- Indicateur de couverture du programme : jamais 100 % tant qu'une notion n'est pas écrite **et** vérifiée.
- Parcours 1re / 2e année ; répartition modifiable dans Réglages.
- Contenu de démonstration seulement (nombres complexes, impédances RLC) : le contenu complet arrive en phase 2.

Captures d'écran à jour : branche [`captures`](../../tree/captures).

## Structure

```
packages/coach_core/   noyau pur Dart : expressions et complexes, unités, générateur
                       d'exercices, correction, couverture, progression, validateur
app/                   application Flutter (écrans, rendu LaTeX, courbes, schémas)
app/assets/content/    notions.json (référentiel), parcours.json, packs/*.json (contenu)
tools/                 export du référentiel, sources du contenu, génération des plateformes
installer/             installateur Windows (Inno Setup) et désinstalleur portable
```

## Écrire du contenu

Un pack JSON contient des `courses`, `examples` et `exercises`, chacun rattaché à des
identifiants de notions (`M-NC-01`, `S-EL-10`…). Dans un exercice, `[[R]]` affiche un
paramètre, `[[=sqrt(R^2+X^2):3|Ω]]` une valeur calculée. Vérifier tout le contenu :

```
cd packages/coach_core && dart run bin/validate.dart
```

Le validateur refuse un contenu rattaché à une notion « Hors programme » et signale les
termes hors périmètre (TIA Portal, Grafcet, câblage…).

## Licence

MIT. Polices Inter, Doto et JetBrains Mono sous licence SIL OFL.
