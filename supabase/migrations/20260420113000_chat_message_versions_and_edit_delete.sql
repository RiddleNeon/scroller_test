-- Chat message editing, deletion, and version history.

alter table public.messages
    add column if not exists edited_at timestamptz;

create table if not exists public.message_versions (
                                                       id bigint generated always as identity primary key,
                                                       message_id bigint not null references public.messages(id) on delete cascade,
    conversation_id bigint not null references public.conversations(id) on delete cascade,
    version_no integer not null,
    content text not null,
    edited_at timestamptz not null default now(),
    edited_by uuid references public.profiles(id),
    change_type text not null default 'edit' check (change_type in ('initial', 'edit', 'delete')),
    unique (message_id, version_no)
    );

create index if not exists idx_message_versions_message_id on public.message_versions(message_id, version_no desc);
create index if not exists idx_message_versions_conversation_id on public.message_versions(conversation_id);

create or replace function public.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
           or coalesce((auth.jwt() ->> 'role') = 'admin', false)
           or auth.role() = 'service_role';
$$;

create or replace function public.is_conversation_member(p_conversation_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
select exists(
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.profile_id = auth.uid()
);
$$;

create or replace function public.refresh_conversation_last_message(p_conversation_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
v_last_sender uuid;
  v_last_content text;
begin
select m.sender_id, m.content
into v_last_sender, v_last_content
from public.messages m
where m.conversation_id = p_conversation_id
  and m.deleted_at is null
order by m.created_at desc
    limit 1;

update public.conversations
set
    updated_at = now(),
    last_message = case
                       when v_last_sender is null then ''
                       else v_last_sender::text || ': ' || coalesce(v_last_content, '')
end
where id = p_conversation_id;
end;
$$;

create or replace function public.track_message_versions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
v_next_version integer;
begin
  if tg_op = 'INSERT' then
    insert into public.message_versions (
      message_id,
      conversation_id,
      version_no,
      content,
      edited_at,
      edited_by,
      change_type
    )
    values (
      new.id,
      new.conversation_id,
      1,
      coalesce(new.content, ''),
      coalesce(new.created_at, now()),
      new.sender_id,
      'initial'
    )
    on conflict do nothing;

    perform public.refresh_conversation_last_message(new.conversation_id);
return new;
end if;

  if tg_op = 'UPDATE' then
    if new.content is distinct from old.content then
select coalesce(max(version_no), 0) + 1
into v_next_version
from public.message_versions
where message_id = new.id;

insert into public.message_versions (
    message_id,
    conversation_id,
    version_no,
    content,
    edited_at,
    edited_by,
    change_type
)
values (
           new.id,
           new.conversation_id,
           v_next_version,
           coalesce(new.content, ''),
           coalesce(new.edited_at, now()),
           auth.uid(),
           'edit'
       );
end if;

    if new.deleted_at is distinct from old.deleted_at and new.deleted_at is not null then
select coalesce(max(version_no), 0) + 1
into v_next_version
from public.message_versions
where message_id = new.id;

insert into public.message_versions (
    message_id,
    conversation_id,
    version_no,
    content,
    edited_at,
    edited_by,
    change_type
)
values (
           new.id,
           new.conversation_id,
           v_next_version,
           coalesce(new.content, ''),
           new.deleted_at,
           auth.uid(),
           'delete'
       );
end if;

    perform public.refresh_conversation_last_message(new.conversation_id);
return new;
end if;

return new;
end;
$$;

drop trigger if exists trg_track_message_versions on public.messages;
create trigger trg_track_message_versions
    after insert or update on public.messages
                        for each row
                        execute function public.track_message_versions();

insert into public.message_versions (
    message_id,
    conversation_id,
    version_no,
    content,
    edited_at,
    edited_by,
    change_type
)
select
    m.id,
    m.conversation_id,
    1,
    coalesce(m.content, ''),
    m.created_at,
    m.sender_id,
    'initial'
from public.messages m
where not exists (
    select 1 from public.message_versions mv where mv.message_id = m.id
);

create or replace function public.edit_message(p_message_id bigint, p_new_content text)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
v_message public.messages;
  v_content text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
end if;

  v_content := trim(coalesce(p_new_content, ''));
  if v_content = '' then
    raise exception 'Message cannot be empty';
end if;

select *
into v_message
from public.messages m
where m.id = p_message_id
  and m.deleted_at is null
    for update;

if not found then
    raise exception 'Message not found';
end if;

  if v_message.sender_id <> auth.uid() then
    raise exception 'Only the sender can edit this message' using errcode = '42501';
end if;

  if not public.is_conversation_member(v_message.conversation_id) then
    raise exception 'Conversation access denied' using errcode = '42501';
end if;

update public.messages
set
    content = v_content,
    edited_at = now()
where id = p_message_id
    returning * into v_message;

return v_message;
end;
$$;

create or replace function public.delete_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
v_message public.messages;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
end if;

select *
into v_message
from public.messages m
where m.id = p_message_id
  and m.deleted_at is null
    for update;

if not found then
    return;
end if;

  if v_message.sender_id <> auth.uid() then
    raise exception 'Only the sender can delete this message' using errcode = '42501';
end if;

  if not public.is_conversation_member(v_message.conversation_id) then
    raise exception 'Conversation access denied' using errcode = '42501';
end if;

update public.messages
set deleted_at = now()
where id = p_message_id;
end;
$$;

create or replace function public.get_message_versions(p_message_id bigint)
returns setof public.message_versions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv_id bigint;
begin
  select conversation_id into v_conv_id
  from public.messages
  where id = p_message_id;

  if not public.is_current_user_admin() and not public.is_conversation_member(v_conv_id) then
    raise exception 'Only admins or participants can access message history' using errcode = '42501';
  end if;

return query
select mv.*
from public.message_versions mv
where mv.message_id = p_message_id
order by mv.version_no desc;
end;
$$;

alter table public.message_versions enable row level security;

drop policy if exists message_versions_admin_read on public.message_versions;
create policy message_versions_admin_read
on public.message_versions
for select
                    using (public.is_current_user_admin());

drop policy if exists message_versions_service_all on public.message_versions;
create policy message_versions_service_all
on public.message_versions
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

grant execute on function public.is_current_user_admin() to authenticated;
grant execute on function public.edit_message(bigint, text) to authenticated;
grant execute on function public.delete_message(bigint) to authenticated;
grant execute on function public.get_message_versions(bigint) to authenticated;