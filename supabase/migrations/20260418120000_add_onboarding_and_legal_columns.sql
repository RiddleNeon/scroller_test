alter table profiles
  add column if not exists accepted_eula boolean not null default false,
  add column if not exists accepted_data_processing boolean not null default false,
  add column if not exists onboarding_completed boolean not null default false;

update profiles
set
  accepted_eula = true,
  accepted_data_processing = true,
  onboarding_completed = true
where onboarding_completed = false;

