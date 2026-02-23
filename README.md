# Image Annotation Tool

`Image Annotation Tool` is a macOS app for bounding-box image annotation with Pascal VOC XML as the source of truth and YOLO export as derived output.

# License

This project continues under the MIT License. See `LICENSE` for full terms.

# Overview

![ScreenShot1](docs/Screenshot1.png)

# Current functionality:

- Recursive directory scanning for `.jpg`, `.jpeg`, `.png`
- Collapsible file tree sidebar (collapsed by default)
- Interactive AppKit-backed annotation canvas (draw/select/move/resize boxes)
- Separate overlay label banner for box names (not part of recorded box geometry)
- Pascal VOC XML read/write
- YOLO `.txt` export generation
- Root-level `classes.txt` management with deterministic class IDs
- Unsaved annotations tracking and save-all
- Keyboard shortcuts for open/save/navigation
- Undo/redo for annotation edits
- Scan progress and error/warning reporting for malformed XML/unreadable images


# Credits

- Maintainer: David P. Discher
- Large parts of this app were developed with OpenAI Codex (Codex app).
    - that's a slight understatement, GPT-5.3-Codex, Extra High reasoning, and used about 9% of weekly credits of the $20/mo "plus" level. A human never actually looked at or wrote any of this code.

# Post Application build

I went ahead and ask Codex to sum up everything that we did, as the initial MD prompt files, didn't include the iterations I did interactively.  I did not review or test these prompts.

```
OK, take [001-Inital Requirements.md](VibeCodingPrompts/001-Inital Requirements.md)  and [002-implement-stage-001.md](VibeCodingPrompts/002-implement-stage-001.md)  ... and all the feed back I gave you in this thread, and create files prefixing the names with 101 and 102 ... (and so on as needed)  in the VibeCodingPrompts,  "final AI requirements and prompts" or something like that, in as many stages as you want, that, if someone from a blank directory and new GPT-5.3-codex session could use to replicate this application with a high precentage change in one-shot.  It doesn't have to be prefect, doesn't need to be tested, and only create new files in the VibeCodingPrompts directory, don't modify anything else.
```


# QA / Validation

- Manual checklist: `QA/Manual-QA-Checklist.md`
- Stage 005 local validation script: `./Tests/run-stage005-validation.sh`
