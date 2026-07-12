# S4MOFLIX iOS App

WebView wrapper qui charge https://s4moflix.xyz

## Build via GitHub Actions (sans Mac)

1. Créer un repo GitHub (public ou privé)
2. Push ce dossier dessus
3. Aller dans **Actions** → **Build S4MOFLIX IPA** → **Run workflow**
4. Télécharger l'artifact `S4MOFLIX-unsigned.ipa`
5. Signer avec zsign :
   ```
   zsign -k cert.p12 -p password -o S4MOFLIX-signed.ipa S4MOFLIX-unsigned.ipa
   ```
6. Distribuer via Iosrocket / AltStore / TrollStore
