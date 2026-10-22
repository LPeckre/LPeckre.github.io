#!/usr/bin/env bash
# Télécharge les images et le CV depuis l'ancien site Wix vers le projet Quarto.
# À lancer une seule fois depuis le dossier du projet :  bash download_images.sh
set -e
W="https://static.wixstatic.com/media"
mkdir -p images/collaborators images/books files

get() { echo "-> $2"; curl -sSL "$W/$1" -o "$2"; }

# Bandeau, photo de profil, pages
get 0976b8_5b0d2665a90d4657a18f4de8e24aef45~mv2.jpg                 images/banner.jpg
get 0976b8_23f57928519849db8a0db9dc80f55da7~mv2.jpeg                images/profile.jpeg
get 0976b8_724f803643724e05a9cdd9fad46bf474~mv2_d_5184_3888_s_4_2.jpg images/home.jpg
cp images/home.jpg images/complexity.jpg
get 0976b8_4138815f540f4829956cf1bcb70e624d~mv2_d_4896_3672_s_4_2.jpg images/grasping.jpg
get 0976b8_c8d0e3690b2044afa2c9b8ea1ec62957~mv2.jpg                 images/selfmedication.jpg
get 0976b8_dd478e5efe0644b9bcb4cb963ff676cb~mv2.jpg                 images/collar.jpg
get 0976b8_c64e7c72aeec4d12b4c53d2c64f7d54c~mv2.jpg                 images/outreach.jpg
get 0976b8_48ca3ef00e50494dad6c6416919e2514~mv2.jpg                 images/millipede.jpg

# Collaborateurs
C=images/collaborators
get 0976b8_68aca048fba24f0a86e45a705a15ff1d~mv2.jpg  $C/boeckx.jpg
get 0976b8_e0c1cccd48b2430a9f518eb7616f613a~mv2.jpg  $C/buil.jpg
get 0976b8_8e25c61280d845e4a4219012b8b4ad6e~mv2.jpg  $C/defolie.jpg
get 0976b8_3a7c32e908164e2aba8c124f1d6131ec~mv2.jpg  $C/dunn.jpg
get 0976b8_f70b0d20470c438d963033068e36cf0b~mv2.jpg  $C/fabre.jpg
get 0976b8_4d99bb97f01d4ee5a6c5dcb00435c0eb~mv2.jpeg $C/fichtel.jpeg
get 0976b8_e6c44f3357874a41ab15a7b3fe08074d~mv2.jpg  $C/hambuckers.jpg
get 0976b8_1d52156e50234cfdba7b850071d00af3~mv2.jpg  $C/kappeler.jpg
get 0976b8_b6ad1a623bad4583a69eda9fea10651f~mv2.jpg  $C/lowie.jpg
get 0976b8_38ec3269d9f04fc59b0b1ff859a15b6f~mv2.png  $C/parra.png
get 0976b8_a1fc63126e654a7295f24111bc5e61ed~mv2.jpg  $C/pouydebat.jpg
get 0976b8_945b1a1016484693bc76d9c045c0b36a~mv2.jpg  $C/raviv.jpg
get 0976b8_42894493db8c428ba370e450a1626244~mv2.jpeg $C/rico-guevara.jpeg
get 0976b8_749dd86c12904f90a2528e00dac14739~mv2_d_4618_3464_s_4_2.jpg $C/socias.jpg
get 0976b8_1f5fae34a57445d79741611b6a968e2d~mv2.jpg  $C/wall.jpg
get 0976b8_1a1189ec9f294e7ba33151594b707030~mv2.jpg  $C/whishaw.jpg

# Livres
B=images/books
get 0976b8_817f01b0dc3d4e819ced2b0b1924cf24~mv2.jpg $B/intelligence-animale.jpg
get 0976b8_bef2553ea653490497196b4c62879162~mv2.jpg $B/atlas-zoologie.jpg
get 0976b8_1b4175c5cb4942d596abeafc8acab719~mv2.jpg $B/animaux-vegetaux.jpg
get 0976b8_3b5e889ac70a45ebbdf69946359b2888~mv2.jpg $B/sexus-animalus.jpg

# CV (PDF)
echo "-> files/CV_Peckre.pdf"
curl -sSL "https://697de1c9-7636-4189-a973-c4d545757661.filesusr.com/ugd/0976b8_bafb1e4fcd8c4eeea24254a0ac472cb8.pdf" -o files/CV_Peckre.pdf

echo "Terminé."
