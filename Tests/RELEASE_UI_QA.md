# Release UI verification

Scope: English interface copy on Mac, iPhone, and Watch; adaptive Mac workspace,
recording inspector, dataset folders, and CSV export options.

## Checks completed

- Unsigned Debug build of `JeonstarLab Mac` for Apple Silicon macOS.
- Unsigned Debug build of `JeonstarLab` for generic iOS, including its Watch app.
- Actual Mac app: existing recordings/folders load without migration.
- Light and dark appearance menu switches the window theme.
- Light sidebar contrast and per-chart legends verified after visual corrections.
- All three charts retain their X/Y/Z or roll/pitch/yaw traces.
- Selecting a saved snap populates range metrics, label, notes, and folder inspector.
- Recording and participant disclosures remain usable in the narrow inspector.
- Folder navigation and the CSV options sheet display correctly in light mode;
  required columns are fixed and the 7 participant/14 motion options are present.
- Cancel dismisses the export sheet without exporting files.
- No existing user recording names, folder names, notes, or saved labels were translated.
- `bash Tests/run-release-ui-smoke.sh` passes: CSV axes, normalized range analysis,
  empty-range rejection, required export headers, default options, persisted option
  round-trip, and stable detection-mode identifier.

## Boundaries

- No on-device Watch recording or Watch → iPhone → Mac transfer test in this pass.
- No distribution signing, archive upload, or App Store submission.
- iPhone/Watch English changes are build-verified; small-screen visual QA remains.
- Dark folder/export views use the shared adaptive surfaces; their final interactive
  inspection was interrupted by concurrent user interaction.
- Existing `nonisolated(unsafe)` warnings in WatchRecordingStorage remain unchanged.
- The repository has no configured XCTest target; the standalone smoke test uses
  production model/parser/analysis sources without touching user recordings or defaults.

## Manual follow-up

Before submission, test receiving on real devices, create/edit/delete a disposable
snap, exercise folder membership and both exporters, and inspect both themes at
minimum window width. Confirm iPhone/Watch text at larger accessibility sizes.
