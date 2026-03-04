create table if not exists comments (
                          id bigint generated always as identity primary key,
                          video_id bigint references videos(id) on delete cascade,
                          author_id uuid references profiles(id) on delete cascade,
                          parent_id bigint references comments(id),
                          content varchar(500) not null,
                          like_count int4 default 0,
                          created_at timestamptz default now()
);

create index on comments(video_id);