-- Fusioncrash : comptes « pseudo + mot de passe » et sauvegarde des parties.
-- À coller dans Supabase → SQL Editor → Run. Rejouable sans risque.
--
-- Aucune adresse e-mail n'est demandée. Les mots de passe sont chiffrés
-- (bcrypt). Le jeu ne lit jamais la table directement : il passe par les
-- fonctions ci-dessous, qui vérifient le jeton de connexion.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.joueurs (
  id uuid primary key default gen_random_uuid(),
  pseudo text not null,
  mdp text not null,
  sauvegarde jsonb not null default '{}'::jsonb,
  maj bigint not null default 0,
  cree_le timestamptz not null default now()
);
create unique index if not exists joueurs_pseudo_unique on public.joueurs (lower(pseudo));

-- Un jeton par appareil connecté (on garde sa partie sur plusieurs appareils).
create table if not exists public.jetons (
  empreinte text primary key,
  joueur uuid not null references public.joueurs(id) on delete cascade,
  cree_le timestamptz not null default now()
);

-- Personne ne lit ni n'écrit les tables en direct.
alter table public.joueurs enable row level security;
alter table public.jetons enable row level security;
revoke all on public.joueurs from anon, authenticated;
revoke all on public.jetons from anon, authenticated;

create or replace function public.fc_nouveau_jeton(p_joueur uuid)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare j text := encode(gen_random_bytes(24), 'hex');
begin
  insert into jetons(empreinte, joueur) values (encode(digest(j, 'sha256'), 'hex'), p_joueur);
  return j;
end $$;
revoke all on function public.fc_nouveau_jeton(uuid) from public, anon, authenticated;

create or replace function public.fc_joueur(p_jeton text)
returns uuid language sql security definer set search_path = public, extensions as $$
  select joueur from jetons where empreinte = encode(digest(coalesce(p_jeton, ''), 'sha256'), 'hex');
$$;
revoke all on function public.fc_joueur(text) from public, anon, authenticated;

create or replace function public.inscrire(p_pseudo text, p_mdp text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare id_joueur uuid;
begin
  if p_pseudo is null or p_pseudo !~ '^[A-Za-z0-9_-]{3,20}$' then return json_build_object('erreur', 'pseudo'); end if;
  if p_mdp is null or length(p_mdp) < 4 or length(p_mdp) > 100 then return json_build_object('erreur', 'mdp'); end if;
  begin
    insert into joueurs(pseudo, mdp) values (p_pseudo, crypt(p_mdp, gen_salt('bf', 8))) returning id into id_joueur;
  exception when unique_violation then
    return json_build_object('erreur', 'pris');
  end;
  return json_build_object('jeton', fc_nouveau_jeton(id_joueur), 'pseudo', p_pseudo, 'maj', 0, 'sauvegarde', '{}'::jsonb);
end $$;

create or replace function public.connexion(p_pseudo text, p_mdp text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare j joueurs;
begin
  select * into j from joueurs where lower(pseudo) = lower(coalesce(p_pseudo, ''));
  if not found or j.mdp <> crypt(coalesce(p_mdp, ''), j.mdp) then
    perform pg_sleep(0.5); -- freine les essais au hasard
    return json_build_object('erreur', 'identifiants');
  end if;
  return json_build_object('jeton', fc_nouveau_jeton(j.id), 'pseudo', j.pseudo, 'maj', j.maj, 'sauvegarde', j.sauvegarde);
end $$;

create or replace function public.charger(p_jeton text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare j joueurs;
begin
  select * into j from joueurs where id = fc_joueur(p_jeton);
  if not found then return json_build_object('erreur', 'jeton'); end if;
  return json_build_object('pseudo', j.pseudo, 'maj', j.maj, 'sauvegarde', j.sauvegarde);
end $$;

-- La sauvegarde la plus récente gagne (horodatage de l'appareil).
create or replace function public.sauver(p_jeton text, p_sauvegarde jsonb, p_maj bigint)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare id_joueur uuid := fc_joueur(p_jeton);
begin
  if id_joueur is null then return json_build_object('erreur', 'jeton'); end if;
  if pg_column_size(p_sauvegarde) > 200000 then return json_build_object('erreur', 'taille'); end if;
  update joueurs set sauvegarde = p_sauvegarde, maj = p_maj where id = id_joueur and maj <= p_maj;
  return json_build_object('ok', true);
end $$;

create or replace function public.deconnecter(p_jeton text)
returns json language sql security definer set search_path = public, extensions as $$
  delete from jetons where empreinte = encode(digest(coalesce(p_jeton, ''), 'sha256'), 'hex');
  select json_build_object('ok', true);
$$;

grant execute on function public.inscrire(text, text) to anon, authenticated;
grant execute on function public.connexion(text, text) to anon, authenticated;
grant execute on function public.charger(text) to anon, authenticated;
grant execute on function public.sauver(text, jsonb, bigint) to anon, authenticated;
grant execute on function public.deconnecter(text) to anon, authenticated;
