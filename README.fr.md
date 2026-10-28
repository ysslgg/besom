<div align="center">

**[English](README.md) · Français**

<img src="Resources/AppIcon-1024.png" width="128" alt="Icône de Besom">

# Besom

**Passe le balai sur ton Mac.**

Fichiers temporaires, caches, journaux, données d'apps orphelines, vieux installeurs, corbeille : Besom repère ce qui peut partir, te montre exactement de quoi il s'agit, et le supprime en un clic.

[![Télécharger Besom](https://img.shields.io/badge/%E2%AC%87%EF%B8%8E%20T%C3%A9l%C3%A9charger-Besom.dmg-14b8a6?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/ysslgg/besom/releases/latest/download/Besom.dmg)

![Dernière version](https://img.shields.io/github/v/release/ysslgg/besom?color=14b8a6&label=version)

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-444?logo=apple&logoColor=white)
![Apple Silicon et Intel](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-444)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)

</div>

## Fonctionnalités

### 🧹 Ce qu'il repère

| Famille | Contenu | Suppression |
|---|---|---|
| **Caches des apps** | `~/Library/Caches` (ceux d'Apple et des apps ouvertes sont laissés) | Définitive |
| **Journaux et rapports de plantage** | `~/Library/Logs`, rapports de diagnostic | Définitive |
| **Fichiers temporaires** | ton dossier temporaire, inchangés depuis plus de 3 jours | Définitive |
| **Restes de développement** | Xcode DerivedData et DeviceSupport, caches du simulateur, cache npm | Définitive |
| **Données d'apps orphelines** | fichiers de support, préférences, états sauvegardés et lanceurs laissés par des apps désinstallées | **Corbeille** |
| **Anciens installeurs** | DMG / PKG / ISO dans Téléchargements (14 jours et plus), téléchargements inachevés | **Corbeille** |
| **Anciennes sauvegardes d'appareils** | sauvegardes d'iPhone et d'iPad | **Corbeille** |
| **Corbeille** | tout son contenu | Vidée définitivement |

### 🛡️ Pensé pour être sûr
- **Rien n'est supprimé sans ta confirmation.** La boîte de dialogue indique ce qui part définitivement et ce qui passe par la corbeille.
- **Seules les données régénérables sont cochées d'office** (caches, journaux, temporaires, caches de développement). Orphelins, installeurs, sauvegardes et corbeille restent ton choix.
- **Tout ce qui n'est pas régénérable passe d'abord par la corbeille** : tu peux encore le récupérer.
- **Chaque élément est consultable** : décoche-le, ou affiche-le dans le Finder, avant de nettoyer.
- **Un garde-fou revérifie chaque chemin juste avant la suppression.** Il doit se trouver strictement dans les dossiers autorisés de sa famille. Les liens symboliques sont résolus : un lien ne peut pas mener ailleurs.
- **La détection des orphelins est prudente.** Tout ce qui a été modifié depuis moins de 30 jours, les données d'Apple, et ce qui correspond à une app installée, une app ouverte, un outil Homebrew ou un binaire système est laissé tranquille.
- **Essai à blanc depuis le terminal** : `Besom --scan` affiche ce qui serait nettoyé puis quitte, sans rien supprimer.

### Et aussi
- **Native et légère** : SwiftUI, une barre latérale des familles avec leurs tailles, une liste détaillée par famille, analyse en direct.
- **Analyse automatique** au lancement puis toutes les quelques heures tant que l'app reste ouverte.
- **Français ou anglais** : suit la langue du système, modifiable dans les Réglages (⌘,).
- **Lancement au démarrage** et retour haptique, tous deux optionnels.

## Installation

1. Télécharge **Besom.dmg** avec le bouton ci-dessus.
2. Ouvre le DMG et glisse **Besom** dans **Applications**.
3. Au premier lancement, macOS affiche un avertissement car l'app n'est pas notarisée. Ouvre **Réglages Système → Confidentialité et sécurité**, descends jusqu'à Besom et clique sur **Ouvrir quand même**.

### Accès complet au disque

macOS garde la corbeille et les sauvegardes d'appareils privées. Pour les voir, autorise Besom dans **Réglages Système → Confidentialité et sécurité → Accès complet au disque**. L'app te prévient quand une famille en a besoin et ouvre le bon panneau. Tout le reste fonctionne sans.

## Limites

- Seules les données de l'utilisateur courant sont analysées : rien dans `/Library` ni `/System`.
- La détection des orphelins est une heuristique. C'est pourquoi ces éléments ne sont jamais cochés d'office et passent toujours par la corbeille.
- Un élément utilisé par une app ouverte peut ne pas se supprimer ; Besom indique combien ont été ignorés.
- La corbeille des volumes externes n'est pas analysée.
- L'app n'est pas notarisée par Apple, d'où l'avertissement au premier lancement.
- Usage personnel uniquement, voir la [licence](LICENSE).
