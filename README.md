# Fusioncrash

Les jeux d'Axel.

Deux jeux en couleurs, et chaque coup fait de la musique.

- **Bonbons** : échange deux bonbons voisins pour en aligner 3. Bonbons rayés,
  emballés, bombe de couleurs, gelée, combos. 10 niveaux de Facile à Expert,
  avec des étoiles.
- **Fusion** : fais glisser les tuiles, deux tuiles pareilles fusionnent.
  4 niveaux de difficulté.

Chaque jeu a son tutoriel « Apprendre à jouer ».

Tout tient dans `index.html` : aucune installation, aucune dépendance.
Il suffit d'ouvrir le fichier dans un navigateur, ou de déployer le dépôt
sur Vercel (site statique, aucun réglage).

## Comptes (pseudo + mot de passe)

Chaque joueur peut garder sa partie, ses étoiles et ses records sur tous ses
appareils. Pas d'adresse e-mail : un pseudo et un mot de passe suffisent
(le mot de passe oublié ne se récupère pas).

Mise en route, une seule fois :

1. Créer un projet sur https://supabase.com (gratuit).
2. Supabase → **SQL Editor** → coller `supabase/comptes.sql` → **Run**
   (rejouable sans risque).
3. Supabase → **Project Settings → API** : copier l'**URL du projet** et la
   clé publique (**anon** ou **publishable**) dans `index.html`
   (`SUPABASE_URL` et `SUPABASE_CLE`). Ne jamais y mettre la clé
   `service_role` / `secret`.

Tant que ces deux valeurs sont vides, le jeu marche sans comptes et garde la
partie sur l'appareil.
