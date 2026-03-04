-- activate rls
alter table profiles enable row level security;
alter table videos enable row level security;
alter table tags enable row level security;
alter table video_tags enable row level security;
alter table likes enable row level security;
alter table follows enable row level security;
alter table comments enable row level security;

-- everyone is allowed to read if its published
create policy "Public read" on profiles for select using (true);
create policy "Public read" on videos for select using (is_published = true);
create policy "Public read" on tags for select using (true);
create policy "Public read" on video_tags for select using (true);
create policy "Public read" on comments for select using (true);
create policy "Public read" on follows for select using (true);
create policy "Public read" on likes for select using (true);

-- Youre only allowed to insert into your own data
create policy "Auth insert" on profiles for insert with check (auth.uid() = id);
create policy "Auth insert" on videos for insert with check (auth.uid() = author_id);
create policy "Auth insert" on comments for insert with check (auth.uid() = author_id);
create policy "Auth insert" on likes for insert with check (auth.uid() = user_id);
create policy "Auth insert" on follows for insert with check (auth.uid() = follower_id);

-- Youre only allowed to edit your own data
create policy "Auth update" on profiles for update using (auth.uid() = id);
create policy "Auth update" on videos for update using (auth.uid() = author_id);

-- Youre only allowed to delete your own data
create policy "Auth delete" on videos for delete using (auth.uid() = author_id);
create policy "Auth delete" on comments for delete using (auth.uid() = author_id);
create policy "Auth delete" on likes for delete using (auth.uid() = user_id);
create policy "Auth delete" on follows for delete using (auth.uid() = follower_id);