# Reef Finds

This build preserves the blue Reef Finds theme and adds saved posts, word/location/date search, profile sharing, reposts, nested comment replies with reply notifications, copied post links, and a daily sighting count. Run `supabase/migrations/202610130001_social_features.sql` in the Supabase SQL Editor after the base migration.

A Finding Nemo inspired lost and found app built with Flutter and Supabase.

The app theme uses layered navy and blue surfaces with pale blue text for contrast. The coral color is preserved on the floating action button.

## Features

- Email registration and login
- Lost and found posts with gallery photo uploads
- Edit, delete, and mark your posts as returned
- Personal and public profiles with profile photos and an uploads grid
- Comments with reply threads
- In-app activity notifications when someone comments on your post
- Animated ocean colors, transitions, cards, and responsive navigation

## Set up Supabase

The app uses the Supabase project configured in `lib/main.dart`. In that project's SQL editor, run [`supabase/migrations/202610110001_reef_finds.sql`](supabase/migrations/202610110001_reef_finds.sql). The migration extends the existing `posts` and `comments` tables used by the starter app, creates profiles and notifications, and adds row security and the public `uploads` storage bucket.

The migration expects the starter tables to have `posts.id`, `posts.title`, `posts.description`, `posts.location`, `posts.type`, `posts.created_at`, and `comments.id`, `comments.post_id`, `comments.body`, `comments.created_at`. If your project uses different column names, adjust those before running the migration.

## Run

Install Flutter dependencies and launch the app from this directory:

```sh
flutter pub get
flutter run
```

Image uploads use the device photo picker. iOS includes the required photo library usage description in `ios/Runner/Info.plist`.

## Source version

This repository contains Reef Finds version 1.0.1+2, prepared from the latest local project. Apply the Supabase migrations in filename order, including the comment images migration.

## Android release signing

Release signing credentials and keystores are intentionally excluded. To build a signed Android release, provide your own local android/key.properties with keyAlias, keyPassword, storePassword, and storeFile. Never commit that file or your keystore.
