# Customize Finder Icon

[English](README.md) · [简体中文](README.zh-CN.md)

A small Codex skill that turns a Finder icon reference and a text description into a custom icon. Preview the image, approve the result, and apply it locally to a macOS file or folder—with a backup for restoration.

**Reference → design direction → generate → approve → apply.** No separate icon-customization app is needed.

## How it works

1. Use your reference image, or extract the target's current Finder icon.
2. If you have not chosen a style, Codex offers **three text-only design directions** describing shape, material, and colors. It waits for your choice before generating. An explicit style or “you decide” skips this step.
3. Generate one transparent image using Codex's built-in image-generation tool. Defaults: **straight-on front view, recognizable folder silhouette, upper-left tab, transparent background, clear margins, no text**. Ordinary files retain their reference silhouette instead.
4. Preview and refine the result. Choosing a design direction does not authorize changing a file's icon.
5. After you confirm both the final image and the target path, a Swift script backs up the previous icon, calls `NSWorkspace.setIcon`, and checks the custom-icon flag. Codex then extracts the applied icon for visual verification.

The workflow follows Occam's razor: one reference, one description, one image, one approved replacement.

## Requirements

- macOS with AppKit and a working Swift toolchain (`xcrun --find swift`).
- Codex with the built-in `image_gen` tool available for image creation. Availability depends on your environment; this repository does not supply that tool.
- Write access to the target file or folder.

The icon script needs no Python packages, API key, or network connection. Image generation uses Codex's image service and is **not an offline operation**. This workflow does not require a separate API key; existing Codex access and applicable usage limits still apply. If the built-in tool is unavailable, do not silently switch to a paid API or another model.

## Install

Clone directly into your personal Codex skills directory. If that destination already exists, inspect it first rather than overwriting it.

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
git clone https://github.com/liaocaoxuezhe/Customize-Finder-Icon.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/finder-icon"
```

Open a new Codex chat if the skill does not appear immediately. The skill identifier is **`finder-icon`**, regardless of the repository name. Skill instructions are currently written in Chinese; the default project documentation is English.

## Use in Codex

```text
Use $finder-icon to design an icon for /absolute/path/to/My Folder.
I haven't chosen a style yet. Offer text directions first, then generate
the selected design. Wait for my approval before applying it.
```

Or give a specific direction:

```text
Use $finder-icon for /absolute/path/to/My Folder: a yellow LEGO-style
folder, straight-on front view, transparent background. Show me the result
before replacing the icon.
```

You can provide your own reference image. Keep generated images and backups outside this repository; the script records the target's absolute path in the backup manifest.

## Use the script directly

Run these commands from the repository root. Replace all example paths with absolute paths. The direct CLI executes immediately; the approval step is part of the **Codex skill**, not an interactive prompt in the script.

```sh
# Export the current Finder appearance as a 1024 × 1024 transparent PNG.
# The output parent directory must exist; an existing output is not overwritten.
swift scripts/finder_icon.swift reference \
  "/absolute/path/to/My Folder" "/absolute/path/to/reference.png"

# Back up and apply a local image.
# Use a NEW backup directory outside the target; its parent must exist.
swift scripts/finder_icon.swift set \
  "/absolute/path/to/My Folder" "/absolute/path/to/icon.png" \
  "/absolute/path/to/backups/change-001"

# Restore the appearance saved by that specific backup.
swift scripts/finder_icon.swift restore \
  "/absolute/path/to/My Folder" "/absolute/path/to/backups/change-001"
```

PNG with a genuine alpha channel is recommended. The script accepts images macOS can decode. It rejects symbolic-link targets and package directories such as `.app` bundles. It changes the icon, not the file contents.

Each backup contains `state.json` and, when a custom icon already existed, `previous.tiff`. Restoration returns to that custom appearance, or removes the custom icon if the target originally used the system default. Backups are appearance snapshots, **not byte-for-byte archives of the original resource fork**. Restoration requires the target to remain at the recorded path. Keep the backup if a write fails; do not force changes with `sudo` or manually delete metadata.

## Tests

On macOS, run the integration test with Python 3.9+ (standard library only):

```sh
python3 test/test_roundtrip.py
```

The test compiles the Swift helper, creates its own PNG fixture, and uses temporary targets under `test/`. It covers files and folders, Unicode paths, custom/default restoration, file-content preservation, and rejected invalid inputs. It does not call image generation or modify your working folders.

## Privacy and repository contents

Only the skill, Swift source, documentation, and tests belong in this repository. Do not commit API keys, `.env` files, user images, backups, or personal paths. `.gitignore` excludes common local artifacts but is not a substitute for reviewing a commit. Reference images supplied to image generation are processed by the configured Codex image service; the local Swift script makes no network requests.

## License

[MIT](LICENSE). The license covers this repository's code and documentation, not third-party artwork, trademarks, or user-provided references. This is an independent project, not an Apple or OpenAI product.
