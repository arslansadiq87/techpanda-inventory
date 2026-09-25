# Backup And Restore

Backups are stored in:

```text
local_data/backups
```

Manual backups create a single `.zip` file containing:

- `metadata.json`
- `inventory.sqlite3`
- `media/` with component and project images

Use Settings > Backups > Download backup to save a portable backup file.

Use Settings > Backups > Restore backup to import a `.zip` backup. The app keeps a safety copy of the current local database and media in `local_data/backups` before replacing them.

Backups on the same disk do not protect against disk failure. Keep downloaded backup zips on USB, NAS, or another machine when you want an off-machine backup.
