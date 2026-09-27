# Twitch sans pubs

Petit lecteur Windows gratuit : entre le nom ou l'URL d'une chaîne Twitch, puis clique sur **Regarder**. La vidéo s'ouvre dans VLC ; le bouton **Ouvrir le chat** ouvre seulement le chat Twitch dans ton navigateur.

## Prérequis

- Windows 10 ou 11
- [PowerShell 7](https://github.com/PowerShell/PowerShell/releases)
- [Python 3.12](https://www.python.org/downloads/)
- [VLC](https://www.videolan.org/vlc/)

## Première utilisation

1. Double-clique sur `Installer.cmd` (connexion Internet requise). Il installe Streamlink dans le dossier `.venv` de ce projet, sans toucher à ton Python global.
2. Double-clique sur `Lancer.cmd`.

VLC doit aussi être installé. L'application le cherche dans les dossiers Windows habituels.

## Ce que fait le filtre

[Streamlink](https://streamlink.github.io/) retire les segments publicitaires du flux Twitch avant de l'envoyer à VLC. Pendant une pub, **l'image se fige** et tu **rates la partie du direct** diffusée pendant ce temps. Twitch ne fournit pas gratuitement le direct sans cette coupure. Aucune connexion à ton compte Twitch ni aucun jeton ne sont demandés.

Si Twitch change son flux, mets Streamlink à jour en relançant `Installer.cmd`. Le filtrage dépend de Streamlink et peut cesser de fonctionner après un changement de Twitch.

Le projet n'est ni une extension de navigateur ni un service IPTV. Tout tourne localement sur ton PC.
