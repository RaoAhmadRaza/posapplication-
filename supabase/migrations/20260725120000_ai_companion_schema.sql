-- SCHEMA EXTENSION (sign-off): AI companion chat persistence — not in DATABASE_SCHEMA.md.
-- Two tables backing the in-app AI assistant (lib/features/assistant/ + edge fn llm-proxy).
-- Tenant + user owned: a user sees only their OWN conversations, within their tenant.
-- Additive + idempotent. RLS + indexes + realtime shipped in-file.

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references public.users(id),
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references public.users(id),
  role text not null check (role in ('user', 'assistant')),
  content text not null default '',
  tool_calls jsonb,                 -- audit: which read RPCs the assistant invoked
  usage jsonb,                      -- token usage for cost attribution (assistant rows)
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_conv_tenant_user on public.chat_conversations(tenant_id, user_id);
create index if not exists idx_chat_msg_conv on public.chat_messages(conversation_id, created_at);

-- RLS: tenant-scoped AND user-owned. Mirrors device_tokens "own" idiom + tenant guard.
alter table public.chat_conversations enable row level security;
drop policy if exists "chat conv own" on public.chat_conversations;
create policy "chat conv own" on public.chat_conversations for all to authenticated
  using (tenant_id = public.auth_tenant_id() and user_id = auth.uid())
  with check (tenant_id = public.auth_tenant_id() and user_id = auth.uid());

alter table public.chat_messages enable row level security;
drop policy if exists "chat msg own" on public.chat_messages;
create policy "chat msg own" on public.chat_messages for all to authenticated
  using (tenant_id = public.auth_tenant_id() and user_id = auth.uid())
  with check (tenant_id = public.auth_tenant_id() and user_id = auth.uid());

-- Realtime: live message sync across a user's devices. Realtime respects RLS, so the
-- stream is tenant/user-scoped exactly like a read. REPLICA IDENTITY FULL so DELETE
-- events carry the scoping columns for RLS. Idempotent: skip already-published tables.
do $$
declare
  t text;
begin
  foreach t in array array['chat_conversations', 'chat_messages']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;
    execute format('alter table public.%I replica identity full', t);
  end loop;
end $$;
