-- ========== ui_preferences — §3.14 VERBATIM (one row per user) ==========
create table if not exists public.ui_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  theme varchar(20) not null default 'light',
  language varchar(10) not null default 'en',
  sidebar_collapsed boolean not null default false,
  default_branch_id uuid references public.branches(id),
  dashboard_layout_json jsonb,
  table_preferences_json jsonb,
  keyboard_shortcuts_json jsonb,
  pos_layout_json jsonb,
  preferences_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_ui_preferences_user on public.ui_preferences(user_id);

alter table public.ui_preferences enable row level security;
drop policy if exists "uiprefs own" on public.ui_preferences;
create policy "uiprefs own" on public.ui_preferences for all to authenticated
  using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.upsert_ui_preferences(
  p_theme varchar, p_language varchar, p_sidebar_collapsed boolean, p_default_branch_id uuid,
  p_dashboard_layout jsonb, p_table_preferences jsonb, p_pos_layout jsonb, p_preferences jsonb
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_id uuid;
begin
  insert into ui_preferences (user_id, theme, language, sidebar_collapsed, default_branch_id,
    dashboard_layout_json, table_preferences_json, pos_layout_json, preferences_json)
  values (auth.uid(), coalesce(p_theme,'light'), coalesce(p_language,'en'), coalesce(p_sidebar_collapsed,false),
    p_default_branch_id, p_dashboard_layout, p_table_preferences, p_pos_layout, coalesce(p_preferences,'{}'))
  on conflict (user_id) do update set
    theme=coalesce(p_theme, ui_preferences.theme), language=coalesce(p_language, ui_preferences.language),
    sidebar_collapsed=coalesce(p_sidebar_collapsed, ui_preferences.sidebar_collapsed),
    default_branch_id=coalesce(p_default_branch_id, ui_preferences.default_branch_id),
    dashboard_layout_json=coalesce(p_dashboard_layout, ui_preferences.dashboard_layout_json),
    table_preferences_json=coalesce(p_table_preferences, ui_preferences.table_preferences_json),
    pos_layout_json=coalesce(p_pos_layout, ui_preferences.pos_layout_json),
    preferences_json=coalesce(p_preferences, ui_preferences.preferences_json), updated_at=now()
  returning id into v_id;
  return jsonb_build_object('ui_preferences_id', v_id);
end; $function$;