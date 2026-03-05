drop policy "Auth insert" on profiles;

create policy "Auth insert" on profiles
    for insert
    with check (true);