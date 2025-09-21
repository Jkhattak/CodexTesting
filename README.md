# CodexTesting

This repository now includes a Swift implementation of the "Super Productivity" core logic described in the build brief. The implementation is delivered as a Swift Package containing:

- **SuperProductivityCore** – the application domain models, Auto-Plan scheduler, natural language quick-add parser, persistence layer, search service, and insight calculators.
- **superproductivity-cli** – a command-line client that exercises the core logic for quick capture, Auto-Plan scheduling, timeline inspection, insights, and search.
- **Unit tests** covering key behaviours such as natural-language parsing and deterministic scheduling.

## Requirements

- Swift 6.1 or newer (the default toolchain provided in the container is sufficient).

## Usage

Build and run the CLI from the repository root:

```bash
swift run superproductivity-cli quickadd "Write report tmrw 3pm 45m high #work @ops"
```

Additional commands are available:

- `superproductivity-cli tasks` – list all captured tasks.
- `superproductivity-cli autoplan [--event HH:MM-HH:MM]` – fill the day around busy events.
- `superproductivity-cli timeline [--event HH:MM-HH:MM]` – render today’s unified timeline.
- `superproductivity-cli insights` – view the current week’s summary metrics.
- `superproductivity-cli search <query>` – search across tasks, habits, focus sessions, and notes.

All data is persisted to `workspace.json` in the working directory; this file is ignored by Git.

## Tests

Run the test suite with:

```bash
swift test
```

The tests verify that the natural-language quick add parser recognises priority, scheduling, and metadata tokens, and that the Auto-Plan scheduler produces non-overlapping task allocations.
