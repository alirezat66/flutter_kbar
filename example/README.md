# flutter_kbar example

A runnable demo of [flutter_kbar](../) for macOS, Windows, Linux and web.

```
flutter run -d macos     # or -d windows, -d linux, -d chrome
```

Press <kbd>⌘K</kbd> (<kbd>Ctrl+K</kbd> off Apple platforms) to open the palette.

## What it demonstrates

| File | Shows |
|---|---|
| `lib/main.dart` | `KBarProvider` + `KBarPalette` in `MaterialApp.builder`, live theming |
| `lib/demo_actions.dart` | sections with priorities, nested actions, sequence shortcuts, undoable commands, an async command |
| `lib/feedback_dialog.dart` | a validated form opened as a dialog **from a palette command** |
| `lib/escape_to_go_back.dart` | app-wide <kbd>Esc</kbd> — closes a dialog, pops a page, ignored at the root |
| `lib/headless_example.dart` | `KBarRegisterActions`, `KBarSelector`, `KBarMatchesBuilder`, and a palette built from the raw primitives |

## Opening a dialog from a command

Commands are declared outside the widget tree, so they have no `BuildContext`.
The demo passes a `GlobalKey<NavigatorState>` to `buildDemoActions` and uses it to push
the dialog:

```dart
KBarAction(
  id: 'feedback',
  name: 'Send feedback…',
  shortcut: const [r'$mod+i'],
  // perform may be async — the palette closes first, then this runs.
  perform: (_) async {
    final result = await showFeedbackDialog(navigatorKey.currentContext!);
    ...
  },
)
```

The palette restores focus when it finishes its exit animation, which happens *after* the
dialog is already up. `KBarPortal` skips the restore when something else has taken focus in
the meantime, so the dialog's first field keeps it — see
`test/feedback_dialog_test.dart`.

Things worth trying once it's open:

- Type `feedback` (or press <kbd>⌘I</kbd>) — a command that opens a form dialog.
- Type `dark` — search flattens the tree, so nested actions surface directly.
- Press <kbd>t</kbd> while closed — a shortcut on a parent opens the palette *at* that parent.
- Press <kbd>g</kbd> then <kbd>h</kbd> — a two-key sequence.
- Press <kbd>Backspace</kbd> on an empty query inside a nested action — go back up.
- Press <kbd>Esc</kbd> repeatedly — closes the palette, then the dialog, then the page,
  and does nothing once you are home.
- Press <kbd>⌘Z</kbd> after changing the theme — undo.
- Open the headless example page, then search for `confetti` — actions registered by a page
  exist only while that page is mounted.
