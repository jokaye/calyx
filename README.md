<p align="center">
  <img src="Resources/AppIcon.iconset/icon_512x512@2x.png" alt="Calyx app icon" width="220" />
</p>

<h1 align="center">Calyx</h1>

<p align="center">
  A translucent macOS container console for Apple's <code>container</code> CLI.
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-blue" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF" />
</p>

## Overview

Calyx is a native macOS UI for working with Apple's `container` command line runtime. It focuses on a calm glass-style interface for inspecting containers, watching resource usage, reading logs, and browsing runtime metadata without pretending to support Docker-only workflows.

The app currently targets Apple container CLI workflows only.

## Features

- Dashboard with live container counts and real runtime metrics sampled every 5 seconds.
- Container list with start, stop, restart, remove, logs, inspect, stats, environment, and mounts views.
- Drawer mode for compact quick actions.
- Images and volumes views backed by Apple container CLI JSON output.
- Network attachment view derived from container configuration and runtime network data.
- Configs view derived from non-sensitive environment variables and labels.
- Secrets view that detects secret-like keys while keeping values masked.
- Events view backed by bounded `container system logs --last ...` output.
- Compose file preview for local `compose.yaml`, `compose.yml`, and `docker-compose.yml` files, with runtime actions disabled unless a real Apple Compose plugin is available.

## Requirements

- macOS 14 or newer.
- Swift 5.9 toolchain.
- Apple's `container` CLI installed and initialized.
- Container services started with:

```bash
container system start
```

## Run Locally

Build and launch the app bundle:

```bash
script/build_and_run.sh
```

Verify that the app starts:

```bash
script/build_and_run.sh --verify
```

The script uses SwiftPM when the local toolchain supports it, and falls back to a direct `swiftc` build on Command Line Tools installations where SwiftPM cannot resolve the macOS platform path.

## Project Structure

```text
Sources/Portainer/
  App/                         App entry point
  Models/                      Runtime and UI models
  Services/                    Apple container CLI wrapper and JSON parser
  Stores/                      App state and refresh loops
  Views/                       SwiftUI views and design system
Resources/                     App icon assets
Tests/                         Parser and client tests
script/build_and_run.sh        Local build and app bundle launcher
```

## Notes

Calyx intentionally keeps unsupported or unsafe actions disabled instead of emulating missing runtime features. For example, Compose lifecycle actions are not implemented without the Apple `container-compose` plugin, and secret values are never shown in the Secrets view.
