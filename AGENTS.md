# Protect player saves

- Never use the player's save for testing, visual previews, fixtures, or debugging.
- Run Godot tests and previews through a `--script` entry point, and include `-- --no-save` for graphical runs. Prefer headless tests when visual inspection is unnecessary.
- Never bypass `save_access_blocked()`, enable persistence in a test, or write directly to the real `user://quiblets_save.json`.
- Test serialization with `save_data()` and `apply_save_data()` in memory. If disk testing becomes necessary, use an explicitly separate temporary file.
- Do not restore, migrate, reset, edit, or replace an existing player save or backup without explicit user authorization.
