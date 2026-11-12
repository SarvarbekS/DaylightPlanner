# Daylight Planner

A calm, local-first macOS planner for organizing calendar events, reminders, to-do lists, goals, and daily habits. Built with SwiftUI and SwiftData, with local AI-assisted capture and a customizable personal workspace.

## Project status

Daylight Planner is an actively developed personal-use macOS application. It can be built as a standalone app and launched without Xcode.

The current focus is a reliable, lightweight experience on one Mac. Accounts, a hosted backend, cross-device synchronization, subscriptions, and additional platforms are future work, not requirements for using the current app.

Documentation reflects the current development direction; the checked-in source and Xcode settings are authoritative for build requirements and exact behavior.

## Features

### Calendar

- Create, edit, and organize events.
- Track event times, locations, colors, and importance.
- Configure recurring events.
- Use natural-language quick-add with the configured AI/parser integration.

### Reminders

- Organize reminders into lists.
- Track due dates, completion, flags, and priorities.
- Keep notes alongside actionable items.

### To-do lists

- Group tasks into lists.
- Add, edit, and complete individual items.
- Keep everyday checklists separate from calendar events and long-term goals.

### Goals

- Track progress toward a target.
- Organize milestones and next actions.
- Record deadlines and goal status.

### Discipline tracker

- Create and edit habits with names, icons, colors, and optional details.
- Set daily or weekly completion targets.
- Check off habits in a weekly grid.
- Review monthly completion patterns.
- View consistency over 30-day and 90-day windows.
- Track all-time longest streaks.
- Save weekly reflection notes.
- Archive and restore habits, or delete their history.

The coach and animated mascot have been removed from the tracker UI for now. Earlier supporting source files may remain in the project; their presence does not mean the coach is an active feature.

### Profile and settings

- Customize the display name and workspace name.
- Choose an avatar color with automatically generated initials.
- Show or hide the workspace subtitle in the sidebar.
- Store profile preferences locally.
- Reduce transaction-based UI animations.
- Enable launch at login through macOS Service Management.

The profile is a local preference, not an online account.

## Notifications: planned integration

Native notifications have been requested but are not documented as implemented yet.

The proposed behavior is:

| Type | Proposed schedule |
| --- | --- |
| Normal calendar event | 1 hour and 10 minutes before the event starts |
| Important / critical calendar event | 1 day, 3 hours, 1 hour, 30 minutes, and 10 minutes before, plus the event start |
| Reminder check-ins | Every day at 11:00 AM and 3:00 PM in the Mac's local time |

The two reminder check-ins are initially intended as generic prompts to review reminders, not live task-count summaries. Event edits and deletions must update or cancel their pending alerts.

Notification presentation will depend on macOS permissions, Focus, device availability, and notification settings. The one-hour important-event alert is a scheduling requirement, not a guarantee that a banner will be seen at that moment.

## Technology

| Area | Implementation |
| --- | --- |
| Interface | SwiftUI |
| Planning data | SwiftData |
| Profile and preferences | UserDefaults through `@AppStorage` |
| Local AI | Qwen through the project's MLX-based integration |
| Optional AI routing | Existing code may also include Apple Foundation Models and external-provider integrations |
| Launch at login | `SMAppService.mainApp` |
| Planned notifications | UserNotifications |
| Primary development environment | Xcode on macOS |

No hosted backend or cloud account is required for the current local workflow.

## Architecture

The application separates its main concerns into:

- **App entry and shell:** window setup, navigation, and shared presentation.
- **Feature views:** Calendar, Reminders, To-do lists, Goals, and Discipline.
- **Persistent models:** planning records stored through SwiftData.
- **Habit calculations:** streak, consistency, and pattern logic in `HabitMath`.
- **AI integration:** parsing and model loading, separate from ordinary planning actions.
- **Local preferences:** profile customization and app settings.
- **System integration:** launch at login and future notification scheduling.

Relevant source files include `DaylightPlannerApp.swift`, `RootView.swift`, `SideBarView.swift`, `Models.swift`, `DisciplineView.swift`, `HabitMath.swift`, `LocalLLM.swift`, `ProfileSettings.swift`, and `LaunchAtLoginSetting.swift`. Models or views may be split across additional files as development continues.

This is a conceptual overview, not a guarantee of a particular repository folder layout.

## Requirements

- A Mac and an Xcode version compatible with the project's Swift toolchain and package dependencies.
- Apple Silicon for the current MLX-based local model workflow.
- Enough disk space for the app, dependencies, and separately downloaded model weights.
- Internet access for initial package resolution and any model download or optional remote AI usage.

Check the app target's deployment setting and dependency manifests for the exact minimum macOS and Xcode requirements. Earlier versions targeted macOS 14+, while direct Foundation Models usage requires macOS 26+ unless properly availability-gated. Do not assume every intermediate development revision supports the original minimum.

## Build and run

1. Clone or download this repository.
2. Open the `DaylightPlanner` Xcode project. If the repository contains a workspace intended for development, open that instead.
3. Allow Swift Package Manager to resolve dependencies.
4. Select the `DaylightPlanner` scheme and the `My Mac` destination.
5. Review Signing & Capabilities and use a suitable local signing configuration.
6. Configure or download the local model if AI features are needed.
7. Build and run with Command+R.

Ordinary planner features should not need a backend configuration. AI feature availability depends on the configured provider and local model setup.

### Local AI setup

Use the model identifier, download path, and configuration expected by the checked-in `LocalLLM` implementation. This README intentionally does not invent a model size or universal filesystem path.

- Keep model weights out of Git.
- Do not commit API keys or credentials.
- Do not delete model files merely because the app bundle has been copied to Applications.
- Test AI capture after moving the app, especially if development used an absolute model path.
- Review the model's own license before redistributing weights.

Keeping the local model is the current direction; switching exclusively to Apple Intelligence was considered and deferred.

## Install a standalone app

1. In Xcode, open Product > Scheme > Edit Scheme.
2. Select Run > Info and set Build Configuration to Release.
3. Choose Product > Build.
4. Open Product > Show Build Folder in Finder.
5. Locate the built app under the Release products folder.
6. Stop any running development copy.
7. Copy the entire `.app` bundle into Applications.
8. Launch the Applications copy and confirm your data and AI capture behave as expected.

Xcode does not need to remain open while you use the installed app. Keep the source project for updates.

### Launch at login

After installing the app in Applications:

1. Open Profile & Settings.
2. Enable Launch Daylight at login.
3. Approve the login item in macOS System Settings if requested.

This opens the app after you sign in; it is not a system service that runs before login.

### Updating the installed app

Quit the installed app, build a new Release version, and replace the app in Applications. Keep the bundle identifier, signing setup, and data-store configuration consistent. Back up important data before schema changes or migrations.

## Habit streak rules

The tracker uses all-time personal bests rather than only the streak ending today.

- **Daily habit:** longest uninterrupted sequence of completed calendar days.
- **Weekly habit:** longest uninterrupted sequence of Monday-based weeks that met the weekly target.
- A missed day or week ends a run but does not erase an earlier record.
- Duplicate check-ins on one date count once.
- Future check-ins do not contribute.
- A current week can qualify as soon as its target is met.
- Longest streak is not the same as total lifetime completions.

Examples:

| History | All-time best |
| --- | --- |
| 12 completed days in a row, a break, then 3 in a row | 12 days |
| Four consecutive weeks meeting a three-times-weekly target, then a missed week | 4 weeks |

Historical weekly streaks currently use the habit's present target because target-change history is not stored. Changing that target can therefore change historical results. Date interpretation follows the calendar/time-zone handling in the current implementation.

## Data and privacy

- Planning records are stored locally through SwiftData.
- Profile settings are stored locally through UserDefaults.
- There is no active backend account or implemented cross-device sync in the current scope.
- Local inference does not require sending prompts to a hosted model provider, but initial downloads may require network access.
- If an external AI provider is configured and used, submitted content is sent to that provider. Review routing and fallback settings before processing sensitive information.

Do not assume encryption beyond the protections provided by the current implementation and macOS. Export/import backups have been discussed but are not documented as shipped. Protect important data with a suitable backup workflow.

## Performance and known limitations

Performance tuning is ongoing. Recent work has focused on:

- Caching discipline statistics rather than calculating them repeatedly during rendering.
- Using completion-date sets for grid and heatmap lookups.
- Removing the coach and mascot from the active tracker.
- Avoiding AI generation for routine habit toggles.
- Narrowing animations to the affected UI element.

Known areas to verify include synchronous statistics refreshes, model loading and generation, task lifetimes, and actor-isolation warnings in AI parsing code. A cancelled UI task does not necessarily stop underlying model computation unless that implementation cooperates with cancellation.

Use Instruments to investigate responsiveness rather than assuming Release builds or caching alone solve a freeze.

### Troubleshooting

| Symptom | What to check |
| --- | --- |
| SwiftSyntax or compiler-plugin build failures | Xcode/toolchain compatibility, pinned package versions, macro approvals, and cached or prebuilt package artifacts |
| Local AI unavailable | Model files, download completion, selected provider, supported hardware, and the loader's configured path |
| UI becomes sluggish | Main-thread work, model initialization, repeated calculations, and background tasks |
| Existing data appears missing after installation | Bundle identifier, signing/container changes, and SwiftData store configuration; do not delete the old store |
| Launch at login does not work | Registration status and macOS Login Items approval |

Do not bypass macro trust checks or delete app data as a routine troubleshooting step.

## Roadmap

### Near term

- [ ] Finish native calendar and reminder notifications.
- [ ] Profile and improve app-wide responsiveness.
- [ ] Review AI cancellation and concurrency boundaries.
- [ ] Add data export/import and a tested backup/restore workflow.
- [ ] Add regression tests for daily and weekly streak edge cases.
- [ ] Refine recurring events and notification rescheduling.

### Longer term

- [ ] Extend the Apple app to iPhone.
- [ ] Build Windows and Android clients.
- [ ] Introduce one shared backend for accounts and cross-device progress.
- [ ] Design and validate offline synchronization and conflict handling.
- [ ] Revisit optional AI planning, scheduling, and weekly reviews.

A separate backend design was prepared earlier. It describes a possible future architecture, not a deployed component of this macOS app. Backend implementation, subscriptions, and cloud AI quotas are deferred while the local product is the priority.

## Development notes

When changing persistence or synchronization-related code:

- Preserve existing records and identifiers.
- Plan schema changes and migrations before shipping them.
- Verify date-only behavior, week boundaries, duplicate check-ins, and daylight-saving transitions.
- Test packaged builds as well as Xcode launches.
- Check that removed UI does not leave expensive background work running.

Before publishing the repository, exclude local databases, personal exports, model weights, credentials, DerivedData, build output, and user-specific Xcode state. Keep dependency resolution reproducible according to the project's package-management policy.

## Contributing

This is currently a personal-use project. Discuss substantial architecture or dependency changes before implementing them. Changes should preserve the calm interface, local-first workflow, and existing user data.

## License

A project license has not been specified in this documentation. Consult the repository's LICENSE file if one is added. Third-party packages and model weights remain subject to their own licenses.
