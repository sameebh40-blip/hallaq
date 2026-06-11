# حلّاق (Hallaq) — Web Preview

## Run in Chrome (Flutter Web)

```bash
flutter config --enable-web
flutter pub get
flutter run -d chrome
```

## Preview Landing Page

Open:

- http://localhost:xxxx/#/preview (hash routing)
- or http://localhost:xxxx/preview (path routing, recommended)

The preview route includes quick buttons for:
- Customer App Preview
- Barber Dashboard Preview
- Barbershop Dashboard Preview
- Admin Panel Preview

## Supabase Configuration

Provide your Supabase credentials using Dart defines:

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

