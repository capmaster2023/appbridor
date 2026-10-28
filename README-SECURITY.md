# README-SECURITY
m

## Ce qui a été ajouté

- Plugin natif `Security`.
- Auto-wipe après 3 erreurs de code maître.
- Compteur d’échecs dans `EncryptedSharedPreferences` via Android Keystore.
- Wipe sécurisé des coffres `main` et `secondary` avec overwrite 3 passes puis suppression.
- Annulation des téléchargements en cours et nettoyage des caches vidéo.
- Détection root basique + check signature release prêt à configurer.
- R8/ProGuard activé par le script Android.

## Méthodes JavaScript

```js
await Capacitor.Plugins.Security.recordFailedMasterPassword();
await Capacitor.Plugins.Security.resetMasterPasswordAttempts();
await Capacitor.Plugins.Security.secureWipeAll();
await Capacitor.Plugins.Security.isDeviceCompromised();
```

## Tamper check

Dans `SecurityPlugin.java`, remplis :

```java
private static final String EXPECTED_RELEASE_CERT_SHA256 = "TON_HASH_SHA256_RELEASE";
```

Sans cette valeur, `tampered` reste `false` et `tamperCheckConfigured` vaut `false`.

## Limite importante

Sur stockage flash Android, “irréversible” veut dire best effort. Le chiffrement + overwrite + suppression rend la récupération beaucoup plus dure, mais personne de sérieux ne promet 100 %. Ceux qui promettent 100 % vendent souvent aussi des rêves en plastique.

## Caméra

La caméra garde une notification/service visible. Une caméra cachée sans notification, c’est légalement et techniquement sale sur Android moderne.
