create or replace function increment_video_metric(p_video_id bigint, p_column text, p_delta int)
returns void
language plpgsql
as $$
begin
  -- The provided videos schema only exposes like_count, view_count, and
  -- comment_count. Dislike/share totals are tracked via separate rows and are
  -- intentionally excluded here.
  if p_column not in ('like_count', 'view_count', 'comment_count') then
    raise exception 'unsupported video metric %', p_column;
  end if;

  execute format(
    'update videos set %I = greatest(coalesce(%I, 0) + $1, 0) where id = $2',
    p_column,
    p_column
  ) using p_delta, p_video_id;
end;
$$;

create or replace function increment_profile_metric(p_user_id text, p_column text, p_delta int)
returns void
language plpgsql
as $$
begin
  if p_column not in ('followers_count', 'following_count', 'total_videos_count', 'total_likes_count') then
    raise exception 'unsupported profile metric %', p_column;
  end if;

  execute format(
    'update profiles set %I = greatest(coalesce(%I, 0) + $1, 0) where id = $2',
    p_column,
    p_column
  ) using p_delta, p_user_id;
end;
$$;

create or replace function increment_comment_metric(p_comment_id bigint, p_column text, p_delta int)
returns void
language plpgsql
as $$
begin
  if p_column not in ('reply_count') then
    raise exception 'unsupported comment metric %', p_column;
  end if;

  execute format(
    'update comments set %I = greatest(coalesce(%I, 0) + $1, 0) where id = $2',
    p_column,
    p_column
  ) using p_delta, p_comment_id;
end;
$$;
