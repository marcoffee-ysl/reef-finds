-- Allow comments to include an optional image attachment.
alter table public.comments
  add column if not exists image_url text;
