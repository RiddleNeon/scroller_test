create index if not exists idx_user_interactions_user_type_created_desc
  on public.user_interactions (user_id, interaction_type, created_at desc);

create index if not exists idx_user_interactions_user_type_created
  on public.user_interactions (user_id, interaction_type, created_at);

alter table public.user_interactions enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_interactions'
      and policyname = 'user_interactions_select_own'
  ) then
    create policy user_interactions_select_own
      on public.user_interactions
      for select
      using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_interactions'
      and policyname = 'user_interactions_insert_own'
  ) then
    create policy user_interactions_insert_own
      on public.user_interactions
      for insert
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_interactions'
      and policyname = 'user_interactions_update_none'
  ) then
    create policy user_interactions_update_none
      on public.user_interactions
      for update
      using (false)
      with check (false);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_interactions'
      and policyname = 'user_interactions_delete_none'
  ) then
    create policy user_interactions_delete_none
      on public.user_interactions
      for delete
      using (false);
  end if;
end
$$;

