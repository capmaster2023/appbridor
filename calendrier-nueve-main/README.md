# Calculatrice APK

Projet prêt pour GitHub Actions.

- Nom de l’app : Calculatrice
- Icône : calculatrice
- Écran récent : l’app revient à la calculatrice quand elle passe en arrière-plan via JS.
- Build : Actions > Build Android APK > Run workflow.


## Modification galerie
- La calculatrice reste dans `www/index.html`.
- Le calcul secret ouvre maintenant `www/galerie.html`.
- `www/galerie.html` vient du projet `coffre-app.zip`.

## Fix vidéos longues / codecs
Cette version ajoute un pont natif Android `NativeVideo` + ExoPlayer.

- Les vidéos ne sont plus lancées avec la balise HTML `<video>` quand l'app tourne dans Capacitor Android.
- La vidéo est copiée par morceaux depuis IndexedDB vers le cache Android, puis ouverte avec ExoPlayer.
- Ça corrige les vidéos longues et les codecs/conteneurs que la WebView Android ne sait pas lire, comme certains `.ts`, HEVC/H.265 ou AV1 selon le téléphone.
- Si l'app est ouverte dans un navigateur normal, elle garde le fallback `<video>`.

## Mise à jour demandée
- Quand l'application passe en arrière-plan (Accueil, applications récentes, changement d'app), Android recharge automatiquement l'écran Calculatrice.
- Les vidéos affichent maintenant une image preview prise vers le milieu de la vidéo avec le pont natif Android quand l'APK est compilé.

## Ajout navigateur privé
- Bouton Navigateur dans la galerie.
- Permet d’ouvrir un lien web et de télécharger un lien direct de vidéo/fichier dans le coffre de l’app.
- Le téléchargement passe par le stockage privé/cache de l’application, puis est importé dans la galerie avec preview vidéo.
- Les fichiers ne sont pas enregistrés dans Download/DCIM par cette fonction.



## Debug logs
Ajouté: application `Logs` sur l'écran d'accueil. Ouvre-la, clique `Copier les logs`, puis colle le résultat pour diagnostiquer les erreurs.


## Caméra automatique

Non incluse. Le projet ne contient pas d’enregistrement caméra automatique ou caché pendant les calculs.


## qwe debug logs
- Logs détaillés ajoutés : erreurs JS, promesses rejetées, authentification, coffre actif, redirections avec raison exacte, pagehide/visibilitychange, clics d'apps, configuration des codes.
- Les logs sont visibles dans l'app via l'icône Logs et copiables.


Correctif qwe: champs de codes vides au premier lancement, bouton Ajouter de Files avec menu importer/créer, logs détaillés, navigation interne sans verrouillage accidentel, sauvegarde du code séparée par coffre.

## Refonte visuelle + vraie icône calculatrice (cette version)
- **Design entièrement repensé** sur tous les écrans (calculatrice, accueil, galerie, notes, PDF, files, logs) : palette ardoise profonde + accent laiton « Sanctuaire Numérique », touches rondes en relief, panneaux en verre dépoli, vraies icônes SVG à la place des glyphes unicode. **Aucune fonctionnalité changée** : tous les IDs, classes, `data-*` et le JS sont identiques.
- **Icône de calculatrice corrigée.** Capacitor 7 génère des icônes ADAPTATIVES (`mipmap-anydpi-v26/ic_launcher.xml`) qui passaient PAR-DESSUS les PNG copiés → c'est pourquoi l'icône Capacitor bleue par défaut s'affichait. Le script de build installe maintenant une icône adaptative complète (couches premier-plan + fond, toutes densités) + les PNG legacy/ronds, et supprime les références Capacitor par défaut. Les sources sont dans `android-res/ic_launcher*`.
- Correctif mineur : le bouton « Verrouiller » de la barre du haut de la galerie était inactif ; il est maintenant relié à `lockNow()`.
- Couleurs du manifest PWA passées en sombre pour matcher la calculatrice.


## Ajouts commerciaux
- Lecteur intégré: PDF via WebView, TXT/CSV avec recherche/zoom/reprise, DOC/DOCX/PPT/PPTX/XLS/XLSX déchiffrés en mémoire avec point de connexion plugin natif Office.
- Archives: page ZIP/RAR/7Z avec stockage et point de connexion extraction native/serveur.
- Admin: code admin haché SHA-256, accès depuis la calculatrice, tableau de bord licences, génération jusqu’à 50 licences, exports CSV/TXT.
- Serveur: dossier `server/` avec API licences SQLite.
- Protection: script Android ajoute R8/ProGuard/minify/shrink resources et suppression logs release quand Android est généré.
