-- USERS
create table profiles (
                          id uuid references auth.users(id) primary key,
                          username varchar(30) not null unique,
                          display_name varchar(50),
                          avatar_url text,
                          bio varchar(150),
                          created_at timestamptz default now()
);

-- VIDEOS
create table videos (
                        id bigint generated always as identity primary key,
                        author_id uuid references profiles(id) on delete cascade not null,
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

--n:m
create table video_tags (
                            video_id bigint references videos(id) on delete cascade,
                            tag_id int2 references tags(id) on delete cascade,
                            primary key (video_id, tag_id)
);

-- LIKES
create table likes (
                       user_id uuid references profiles(id) on delete cascade,
                       video_id bigint references videos(id) on delete cascade,
                       created_at timestamptz default now(),
                       primary key (user_id, video_id)
);

-- FOLLOWS
create table follows (
                         follower_id uuid references profiles(id) on delete cascade,
                         following_id uuid references profiles(id) on delete cascade,
                         created_at timestamptz default now(),
                         primary key (follower_id, following_id)
);