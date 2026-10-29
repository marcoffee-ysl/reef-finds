-- Reef Finds social features: bookmarks, reposts, and nested-reply alerts.
create table if not exists public.saved_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id bigint not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.reposts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id bigint not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.saved_posts enable row level security;
alter table public.reposts enable row level security;
drop policy if exists "Users read their saved posts" on public.saved_posts;
create policy "Users read their saved posts" on public.saved_posts for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users save posts" on public.saved_posts;
create policy "Users save posts" on public.saved_posts for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove saved posts" on public.saved_posts;
create policy "Users remove saved posts" on public.saved_posts for delete to authenticated using (auth.uid() = user_id);
drop policy if exists "Reposts are visible" on public.reposts;
create policy "Reposts are visible" on public.reposts for select using (true);
drop policy if exists "Users create reposts" on public.reposts;
create policy "Users create reposts" on public.reposts for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove reposts" on public.reposts;
create policy "Users remove reposts" on public.reposts for delete to authenticated using (auth.uid() = user_id);

create or replace function public.notify_post_owner_on_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  recipient_id uuid;
  item_title text;
  actor_name text;
begin
  select title, user_id into item_title, recipient_id from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select user_id into recipient_id from public.comments where id = new.parent_id;
  end if;
  select username into actor_name from public.profiles where id = new.user_id;
  if recipient_id is not null and recipient_id <> new.user_id then
    insert into public.notifications(user_id, actor_id, post_id, body)
    values(recipient_id, new.user_id, new.post_id,
      coalesce(actor_name, 'Someone') || case when new.parent_id is null then ' commented on “' else ' replied to your comment on “' end || coalesce(item_title, 'your post') || '”.');
  end if;
  return new;
end $$;
drop trigger if exists comment_creates_notification on public.comments;
create trigger comment_creates_notification after insert on public.comments for each row execute function public.notify_post_owner_on_comment();
