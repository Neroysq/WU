# WU Keyframe Provenance

Approved Hu keyframes live under `art/keyframes/hu/<action>/<slot>.png`.

`keyframes.manifest.json` records provenance. Each `actions.<action>.slots.<slot>` entry should use:

```json
{
  "file": "art/keyframes/hu/<action>/<slot>.png",
  "prompt": "prompt or edit instruction used",
  "backend": "codex",
  "seed": null,
  "approved": "YYYY-MM-DD",
  "notes": "review notes, recovery session id, rejection history"
}
```

Do not record rejected candidates as approved files. Keep rejection notes in the relevant action's manifest notes so later runs can reuse approved stills without losing the decision trail.
