alter table if exists profiles add column if not exists fcm_token text;
alter table if exists profiles add column if not exists followers_count int4 default 0;
alter table if exists profiles add column if not exists following_count int4 default 0;
alter table if exists profiles add column if not exists total_videos_count int4 default 0;
alter table if exists profiles add column if not exists total_likes_count int4 default 0;

alter table if exists videos add column if not exists comment_count int4 default 0;
alter table if exists videos add column if not exists dislike_count int4 default 0;
alter table if exists videos add column if not exists share_count int4 default 0;

alter table if exists comments add column if not exists parent_id bigint references comments(id) on delete cascade;
alter table if exists comments add column if not exists reply_count int4 default 0;

create table if not exists dislikes (
  user_id text references profiles(id) on delete cascade,
  video_id bigint references videos(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, video_id)
);

create table if not exists saved_videos (
  user_id text references profiles(id) on delete cascade,
  video_id bigint references videos(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, video_id)
);

create table if not exists video_reports (
  id bigint generated always as identity primary key,
  user_id text references profiles(id) on delete cascade not null,
  video_id bigint references videos(id) on delete cascade not null,
  reason text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists user_preferences (
  user_id text primary key references profiles(id) on delete cascade,
  recommendation_profile jsonb not null default '{}'::jsonb,
  cursor_vector jsonb not null default '{}'::jsonb,
  blacklisted_tags jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists recent_interactions (
  id bigint generated always as identity primary key,
  user_id text not null references profiles(id) on delete cascade,
  video_id bigint not null references videos(id) on delete cascade,
  timestamp timestamptz not null default now(),
  watch_time double precision,
  video_duration double precision,
  liked boolean not null default false,
  disliked boolean not null default false,
  shared boolean not null default false,
  commented boolean not null default false,
  saved boolean not null default false,
  author_id text references profiles(id) on delete set null,
  tags text[] not null default '{}',
  unique (user_id, video_id)
);

create index if not exists recent_interactions_user_timestamp_idx on recent_interactions(user_id, timestamp desc);

create or replace function increment_video_metric(p_video_id bigint, p_column text, p_delta int)
returns void
language plpgsql
as $$
begin
  if p_column not in ('like_count', 'view_count', 'comment_count', 'dislike_count', 'share_count') then
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

alter table dislikes enable row level security;
alter table saved_videos enable row level security;
alter table video_reports enable row level security;
alter table user_preferences enable row level security;
alter table recent_interactions enable row level security;

drop policy if exists "Public read dislikes" on dislikes;
create policy "Public read dislikes" on dislikes for select using (true);
drop policy if exists "Auth modify dislikes" on dislikes;
create policy "Auth modify dislikes" on dislikes for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);

drop policy if exists "Public read saved_videos" on saved_videos;
create policy "Public read saved_videos" on saved_videos for select using (true);
drop policy if exists "Auth modify saved_videos" on saved_videos;
create policy "Auth modify saved_videos" on saved_videos for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);

drop policy if exists "Auth insert video_reports" on video_reports;
create policy "Auth insert video_reports" on video_reports for insert with check (auth.uid()::text = user_id);
drop policy if exists "Auth read own video_reports" on video_reports;
create policy "Auth read own video_reports" on video_reports for select using (auth.uid()::text = user_id);

drop policy if exists "Auth modify user_preferences" on user_preferences;
create policy "Auth modify user_preferences" on user_preferences for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);

drop policy if exists "Auth modify recent_interactions" on recent_interactions;
create policy "Auth modify recent_interactions" on recent_interactions for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
