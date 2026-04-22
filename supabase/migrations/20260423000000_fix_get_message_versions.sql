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

  if not public.is_current_user_admin() and not coalesce(public.is_conversation_member(v_conv_id), false) then
    raise exception 'Only admins or participants can access message history' using errcode = '42501';
  end if;

return query
select mv.*
from public.message_versions mv
where mv.message_id = p_message_id
order by mv.version_no desc;
end;
$$;
