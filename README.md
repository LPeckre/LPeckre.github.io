# Site personnel – Louise Peckre (Quarto + GitHub Pages)

Recréation du site Wix https://louisepeckre.wixsite.com/home avec [Quarto](https://quarto.org).

## Structure

| Fichier | Page |
|---|---|
| `index.qmd` | Home (présentation, contacts) |
| `projects.qmd` | Projects |
| `cv.qmd` | CV |
| `publications.qmd` | Publications |
| `outreach.qmd` | Outreach |
| `collaborators.qmd` | Collaborators |
| `_quarto.yml` | Menu, thème, pied de page |
| `_banner.html` | Bandeau en haut de chaque page |
| `styles.scss` | Couleurs, polices, mise en page |
| `.github/workflows/publish.yml` | Publication automatique sur GitHub Pages |

## 1. Installer les outils (une seule fois)

- Quarto : https://quarto.org/docs/get-started/
- Git : https://git-scm.com/downloads
- Un compte GitHub

## 2. Récupérer les images et le CV

Depuis le dossier du projet, dans un terminal :

```bash
bash download_images.sh
```

Le script télécharge les photos du site Wix dans `images/` et le CV dans `files/`.
(Sous Windows, lancez-le dans « Git Bash ».)

## 3. Prévisualiser en local

```bash
quarto preview
```

Le site s'ouvre dans le navigateur et se met à jour à chaque modification.

## 4. Mettre le site sur GitHub

1. Sur GitHub, créez un dépôt vide, par exemple `louisepeckre.github.io`
   (avec ce nom exact, le site sera à l'adresse `https://louisepeckre.github.io`,
   en remplaçant `louisepeckre` par votre identifiant GitHub).
2. Dans le dossier du projet :

   ```bash
   git init
   git add .
   git commit -m "Premier commit du site"
   git branch -M main
   git remote add origin https://github.com/VOTRE-IDENTIFIANT/louisepeckre.github.io.git
   git push -u origin main
   ```

3. Attendez que l'action « Publish site to GitHub Pages » se termine (onglet **Actions**).
4. Allez dans **Settings → Pages**, choisissez *Source : Deploy from a branch*,
   branche **gh-pages**, dossier **/ (root)**, puis *Save*.

Le site est en ligne après une ou deux minutes.

## 5. Mettre à jour le site

Modifiez les fichiers `.qmd`, puis :

```bash
git add .
git commit -m "Mise à jour"
git push
```

La publication se fait automatiquement.

## À compléter

- `outreach.qmd` : ajouter l'enregistrement « Listen and guess who I am? » (`files/…mp3`) et le contenu du cours *Raíces de lo Humano*.
- Mettre à jour le CV PDF dans `files/CV_Peckre.pdf` si besoin.
