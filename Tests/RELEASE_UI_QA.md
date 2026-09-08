# Release UI verification

Latest: see [2026-09-09 interactive UI verification](UI_VERIFICATION_2026-09-09.md)
and [2026-09-08 release hardening verification](RELEASE_READINESS_2026-09-08.md).
The entries below are historical UI passes, not evidence that the latest changes
have completed interactive or physical-device QA. The latest pass supersedes the
old Watch background-recording and storage-warning notes below.

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
- Watch ready/recording/transfer presentation has been checked on a 40mm simulator;
  real-device checks and accessibility-size interaction remain.
- Dark folder/export views use the shared adaptive surfaces; their final interactive
  inspection was interrupted by concurrent user interaction.
- Existing `nonisolated(unsafe)` warnings in WatchRecordingStorage remain unchanged.
- The repository has no configured XCTest target; the standalone smoke test uses
  production model/parser/analysis sources without touching user recordings or defaults.

## Manual follow-up

Before submission, test receiving on real devices, create/edit/delete a disposable
snap, exercise folder membership and both exporters, and inspect both themes at
minimum window width. Confirm iPhone/Watch text at larger accessibility sizes.

## iPhone recording-review redesign

- Removed activity-specific detection settings, flip analysis, automatic peak overlays,
  and 3D visualizations from the detail UI. Legacy detection identifiers and export
  fields remain intact; existing recordings are not migrated or discarded.
- Retained three-axis 2D acceleration, gyroscope, and attitude previews, sensor units,
  real elapsed timestamps, recording information, notes, original export, and Mac transfer.
- Shared Mac connection controls and a single automatic-transfer setting replace
  duplicate settings. Transfer feedback is associated with its recording, and sending
  is disabled until the peer is actually connected.
- iPhone 17e / iOS 26.5 simulator: light/dark detail preview, attitude switch, notes
  editor/cancel, disconnected transfer button, and connection settings visually checked.
- Unsigned Debug simulator build and Release generic iOS build (including Watch) pass.
- `bash Tests/run-phone-ui-smoke.sh` passes: elapsed-time gaps and invalid timestamps,
  all nine sensor axes and units, failed-load retry, memo save/cancel/failure, 15-column
  CSV, original notes, and legacy `jeonFlip` metadata in the three-file export.
- `bash Tests/run-release-ui-smoke.sh` still passes for the Mac models.
- DEBUG simulator launch argument `--ui-preview` seeds isolated, in-memory sample
  recordings with temporary binary files. Omit the argument for normal persistence.
  This fixture is excluded from physical-device and Release builds.
- Accessibility layouts use a menu sensor picker and vertical Watch controls/row
  metadata at accessibility sizes; final large-text visual QA and real-device transfer
  (including automatic transfer and retry) remain manual follow-up items.

## Watch recording UI redesign

- The primary screen now emphasizes recording status, elapsed time from the real
  session start date, sample count, and a full-width Record/Stop button.
- A separate Saved Files screen contains retained recordings, file details,
  resend controls, and the existing explicit delete confirmation. Binary storage,
  transfer metadata, and import-acknowledgment cleanup are unchanged.
- Transfer progress remains indeterminate: queued transfer is not presented as a
  percentage or proof of iPhone import. Saved files explain acknowledgment semantics.
- Black system surfaces and red recording controls are used on Watch; no forced
  light theme is introduced. Semantic fonts and scrolling support longer content.
- Apple Watch SE 3 (40mm), watchOS 26.5: ready and recording screenshots inspected.
  Timer/button spacing was reduced after the first capture to keep Stop fully visible.
  Transfer presentation was inspected; the redundant disabled action was then removed.
- DEBUG simulator argument `--watch-ui-preview` renders a sample recording state;
  append `sending`, `error`, or `large-text` for visual fixtures. Fixture callbacks
  are no-ops: no sensor recording, file writes, or transfers. This mode is excluded
  from Release and physical-device builds.
- `bash Tests/run-watch-ui-smoke.sh` verifies production start/stop/state logic using
  fake recorder/storage/transfer/haptics: duplicate starts do not clear the buffer,
  late transfer callbacks do not overwrite recording, repeat resends are blocked,
  and failure states remain actionable. No real recording files are created or deleted.
- Manual follow-up: retained-file expansion/resend/delete/cancel on disposable
  recordings, large-text interaction, physical-device haptics/background recording,
  and Watch → iPhone import acknowledgment → Mac transfer end to end.

## Project settings and export naming

- Added project-scoped label names, colors, ordering, optional numeric shortcuts,
  and archiving. Existing label IDs and annotations are preserved; archived labels
  remain on saved annotations but are hidden from selection menus.
- App Settings contains appearance and default project export name, date suffix,
  and `.watchmotion` / `.zip` format. Legacy `.jeonstarlab` projects still open.
- Project format v2 includes the label catalog. Opening v1 archives preserves
  default labels. New project locations use WatchMotion Editor; existing receiver
  data stays at its old location when present.
- `bash Tests/run-project-settings-smoke.sh` passes: stable label identity, legacy
  decoding, unknown IDs, validation, custom-label persistence, workspace isolation,
  current/legacy archive round trips, original CSV bytes, and safe export naming.
- Mac UI: temporary workspace only; rename/save, duplicate-name rejection, and
  Reload verified. Project Labels inspected in light and dark; Export settings
  and its filename preview inspected in light. No user recordings were modified.
- Watch Saved Files button now omits the tray icon and gives the count its own
  padded badge. Its simulator build passes; final 40mm visual recheck remains.

## First-run guides

- Mac and iPhone each present a three-page English guide once per installation's
  defaults. Presentation is remembered even when skipped or closed; all pages
  remain accessible through Show Tutorial in Mac Settings and iPhone Connection
  Settings. Mac also exposes the guide in the workspace menu and Window menu.
- Guidance follows existing controls: Watch recording, iPhone motion review and
  transfer, Mac receiving, snap labeling, project labels, and dataset/project export.
  The guide itself starts no recording, transfer, or permission request.
- Shared scrollable content keeps navigation buttons separate from long text.
  Mac dark UI: all three steps, Back, Skip, and reopening at page one verified.
  iPhone 17e / iOS 26.5: first-page dark screenshot inspected without clipping.
- DEBUG `--show-tutorial` forces presentation without changing the persisted
  first-run flag. Combine with iPhone `--ui-preview` or Mac `--ui-workspace PATH`
  for isolated UI inspection. The normal path uses versioned AppStorage flags.
- Unsigned Mac and iPhone simulator Debug builds pass; Mac Release and generic
  iOS Release (including Watch) builds also pass. Full iPhone button-flow,
  clean-install/relaunch persistence, light-mode guide, and larger accessibility
  text remain manual follow-up checks; real-device transfer is still unverified.
