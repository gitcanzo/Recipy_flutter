# Recipy — Brand handoff (Flutter)

Drop this file at your Flutter repo root as `BRAND.md`. Paste relevant sections into Claude in VSCode when asking it to build screens. The Dart snippets below are production-ready — copy them into your project.

---

## 1. Setup

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
```

Then in `lib/theme/recipy_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Recipy palette — Mint (primary direction).
class RecipyColors {
  static const paper    = Color(0xFFF4F6EE); // page background
  static const paperHi  = Color(0xFFFBFCF4); // surface / icon tile
  static const surface  = Color(0xFFFFFFFF); // elevated card
  static const ink      = Color(0xFF0F1F18); // primary text
  static const inkSoft  = Color(0xFF52685D); // secondary text
  static const rule     = Color(0xFFDEE5D2); // dividers, borders
  static const accent   = Color(0xFF73A14A); // primary green — buttons, "Recipy", hat
  static const accent2  = Color(0xFF3C5B22); // dark green — hat band, subtitle, headings
  static const soft     = Color(0xFFE1ECCB); // sage tint — chips, icon backdrop disc
}
```

## 2. ThemeData

`lib/theme/recipy_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'recipy_colors.dart';

class RecipyTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final body = GoogleFonts.geistTextTheme(base.textTheme).apply(
      bodyColor: RecipyColors.ink,
      displayColor: RecipyColors.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: RecipyColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RecipyColors.accent,
        primary: RecipyColors.accent,
        onPrimary: RecipyColors.paperHi,
        secondary: RecipyColors.accent2,
        surface: RecipyColors.surface,
        onSurface: RecipyColors.ink,
        outline: RecipyColors.rule,
        brightness: Brightness.light,
      ),
      textTheme: body.copyWith(
        // section eyebrows
        labelSmall: body.labelSmall?.copyWith(
          fontSize: 10.5,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
          color: RecipyColors.accent,
        ),
        // body
        bodyMedium: body.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.5,
          color: RecipyColors.ink,
        ),
        bodySmall: body.bodySmall?.copyWith(
          fontSize: 11,
          color: RecipyColors.inkSoft,
        ),
        // headings — use Recipy.titleLarge for "Charred leeks…" etc.
        titleLarge: body.titleLarge?.copyWith(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: RecipyColors.ink,
        ),
      ),
      dividerColor: RecipyColors.rule,
      cardTheme: CardTheme(
        color: RecipyColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RecipyColors.accent,
          foregroundColor: RecipyColors.paperHi,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
          shadowColor: RecipyColors.accent.withOpacity(0.27),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RecipyColors.accent,
        foregroundColor: RecipyColors.paperHi,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RecipyColors.paperHi,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
```

Then in `main.dart`:

```dart
MaterialApp(
  title: 'Recipy',
  theme: RecipyTheme.light(),
  home: const TodayScreen(),
);
```

## 3. The wordmark widget

Use `Pacifico` from Google Fonts for "Recipy" everywhere it appears.

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/recipy_colors.dart';

class RecipyWordmark extends StatelessWidget {
  final double size;
  final bool showSubtitle;
  const RecipyWordmark({super.key, this.size = 32, this.showSubtitle = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Recipy',
          style: GoogleFonts.pacifico(
            fontSize: size,
            color: RecipyColors.accent,
            height: 1.0,
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: size * 0.15),
          Padding(
            padding: EdgeInsets.only(left: size * 0.08),
            child: Text(
              'COOK · SAVE · SHARE',
              style: GoogleFonts.geist(
                fontSize: size * 0.10,
                letterSpacing: size * 0.10 * 0.32,
                fontWeight: FontWeight.w500,
                color: RecipyColors.accent2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

Use in your `AppBar`:

```dart
AppBar(
  backgroundColor: RecipyColors.paper,
  elevation: 0,
  title: const RecipyWordmark(size: 28),
  titleSpacing: 22,
)
```

## 4. Logo & icon assets

Drop these files into `assets/`:

| File | Where to use |
|---|---|
| `recipy-icon-1024.png` | `flutter_launcher_icons` source — see below |
| `recipy-splash.png` | `flutter_native_splash` source |
| `recipy-wordmark.png` | Optional fallback if you don't want runtime font load |

Add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/recipy-icon-1024.png"
  remove_alpha_ios: true
  adaptive_icon_background: "#FBFCF4"
  adaptive_icon_foreground: "assets/recipy-icon-1024.png"

flutter_native_splash:
  color: "#F4F6EE"
  image: assets/recipy-splash.png
  android_12:
    color: "#F4F6EE"
    image: assets/recipy-icon-1024.png
```

Run:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## 5. Design principles

- **Simplicity over options.** One clear primary action per screen.
- **Generous whitespace.** Default screen padding: 22px horizontal, 16px vertical.
- **Soft cards.** Radius 18, no elevation — use soft shadow instead.
- **Pill buttons.** `StadiumBorder()`, height 54.
- **3 bottom nav destinations max.** Today / Cookbook / You. Use a FAB for "New recipe".
- **Pantry-aware ingredients.** Checkbox = "have it"; show "4 of 6 in pantry" subtle counter.

## 6. Reusable component snippets

### Soft card

```dart
Container(
  decoration: BoxDecoration(
    color: RecipyColors.surface,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  ),
  child: const Padding(padding: EdgeInsets.all(22), child: /* ... */),
)
```

### Eyebrow text (above headings)

```dart
Text(
  'FOR TONIGHT',
  style: Theme.of(context).textTheme.labelSmall,
)
```

### Chip / tag

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  decoration: BoxDecoration(
    color: selected ? RecipyColors.soft : Colors.transparent,
    border: selected ? null : Border.all(color: RecipyColors.rule),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(
    label,
    style: GoogleFonts.geist(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: selected ? RecipyColors.accent2 : RecipyColors.inkSoft,
    ),
  ),
)
```

### Bottom navigation (3 destinations + FAB)

```dart
Scaffold(
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => Navigator.pushNamed(context, '/create'),
    icon: const Icon(Icons.add),
    label: const Text('New recipe'),
  ),
  bottomNavigationBar: NavigationBar(
    backgroundColor: RecipyColors.surface,
    indicatorColor: RecipyColors.soft,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Today'),
      NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Cookbook'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'You'),
    ],
  ),
)
```

### Hero recipe card

```dart
Container(
  decoration: BoxDecoration(
    color: RecipyColors.surface,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8))],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Image.asset('assets/hero.jpg', height: 260, fit: BoxFit.cover),
      ),
      Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FOR TONIGHT', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Text('Charred leeks with\nbuttered pasta',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: RecipyColors.inkSoft),
              const SizedBox(width: 5),
              Text('25 min', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 16),
              const Icon(Icons.local_fire_department_outlined, size: 14, color: RecipyColors.inkSoft),
              const SizedBox(width: 5),
              Text('Easy', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ],
        ),
      ),
    ],
  ),
)
```

## 7. Screens to build

See `Recipy.html` (in the design project) for visual reference:

- **Today** — daily greeting + one hero card + two secondary cards
- **Recipe detail** — hero photo, title, time/serves/level strip, ingredient checklist, "Start cooking" CTA
- **Cook mode** — single step large, progress bar, timer ring, prev/next pill
- **Cookbook** — 2-column grid with status chips
- **Create flow** (3 steps) — Basics → Ingredients → Steps

---

## How to use this with Claude in VSCode

When asking Claude to build a screen:

> *"Follow `BRAND.md`. Build the Recipe Detail screen as a StatefulWidget. Use the `RecipyColors` and `RecipyTheme` already in `lib/theme/`. Reference section 6 for the soft card and eyebrow patterns. The hero image should be a placeholder `Image.asset` for now."*

That gives Claude the tokens, the components, and a clear scope. Iterate from there.