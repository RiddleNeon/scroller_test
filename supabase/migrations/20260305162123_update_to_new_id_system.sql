-- DROP EVERYTHING
drop table if exists follows cascade;
drop table if exists likes cascade;
drop table if exists video_tags cascade;
drop table if exists tags cascade;
drop table if exists comments cascade;
drop table if exists videos cascade;
drop table if exists profiles cascade;

-- PROFILES
create table profiles (
                          id text primary key,
                          username varchar(30) not null unique,
                          display_name varchar(50),
                          avatar_url text,
                          bio varchar(150),
                          created_at timestamptz default now()
);

-- VIDEOS
create table videos (
                        id bigint generated always as identity primary key,
                        author_id text references profiles(id) on delete cascade not null,
                        title varchar(100),
                        description varchar(300),
                        video_url text not null,
                        thumbnail_url text,
                        duration_ms int2,
                        view_count int4 default 0,
                        like_count int4 default 0,
                        is_published bool default true,
                        created_at timestamptz default now()
);

-- TAGS
create table tags (
                      id int2 generated always as identity primary key,
                      name varchar(30) not null unique
);

-- VIDEO_TAGS
create table video_tags (
                            video_id bigint references videos(id) on delete cascade,
                            tag_id int2 references tags(id) on delete cascade,
                            primary key (video_id, tag_id)
);

-- LIKES
create table likes (
                       user_id text references profiles(id) on delete cascade,
                       video_id bigint references videos(id) on delete cascade,
                       created_at timestamptz default now(),
                       primary key (user_id, video_id)
);

-- FOLLOWS
create table follows (
                         follower_id text references profiles(id) on delete cascade,
                         following_id text references profiles(id) on delete cascade,
                         created_at timestamptz default now(),
                         primary key (follower_id, following_id)
);

-- COMMENTS
create table comments (
                          id bigint generated always as identity primary key,
                          author_id text references profiles(id) on delete cascade not null,
                          video_id bigint references videos(id) on delete cascade not null,
                          content varchar(300) not null,
                          created_at timestamptz default now()
);

-- RLS
alter table profiles enable row level security;
alter table videos enable row level security;
alter table tags enable row level security;
alter table video_tags enable row level security;
alter table likes enable row level security;
alter table follows enable row level security;
alter table comments enable row level security;

-- PUBLIC READ
create policy "Public read" on profiles for select using (true);
create policy "Public read" on videos for select using (is_published = true);
create policy "Public read" on tags for select using (true);
create policy "Public read" on video_tags for select using (true);
create policy "Public read" on comments for select using (true);
create policy "Public read" on follows for select using (true);
create policy "Public read" on likes for select using (true);

-- AUTH INSERT
create policy "Auth insert" on profiles for insert with check (auth.uid()::text = id);
create policy "Auth insert" on videos for insert with check (auth.uid()::text = author_id);
create policy "Auth insert" on comments for insert with check (auth.uid()::text = author_id);
create policy "Auth insert" on likes for insert with check (auth.uid()::text = user_id);
create policy "Auth insert" on follows for insert with check (auth.uid()::text = follower_id);

-- AUTH UPDATE
create policy "Auth update" on profiles for update using (auth.uid()::text = id);
create policy "Auth update" on videos for update using (auth.uid()::text = author_id);

-- AUTH DELETE
create policy "Auth delete" on videos for delete using (auth.uid()::text = author_id);
create policy "Auth delete" on comments for delete using (auth.uid()::text = author_id);
create policy "Auth delete" on likes for delete using (auth.uid()::text = user_id);
create policy "Auth delete" on follows for delete using (auth.uid()::text = follower_id);