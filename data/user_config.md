# Pet configuration

Edit `assets/user_config.json`, then restart the pet to load the changes. Use valid JSON: double-quoted keys, arrays such as `[50, 100]`, and unquoted `true`, `false`, and `null`.

`settings` contains shared behavior and window defaults. `animations` contains an entry for every named pet animation and the `pet` / `feed_ignore` hand interactions. `RESET` is an internal Godot animation and is excluded. The defaults follow the current Godot script, including the 23:00–08:00 sleep schedule and one-hour stat decay.

## Animation settings

| Field | Meaning |
| --- | --- |
| `type` | State category. Enabled states with type `idle_variant` form the random idle pool. |
| `enabled` | Include an idle variant in the random pool. Set to `false` to disable it. |
| `repeat_count` | For an idle variant, an inclusive integer range of complete animation loops. `null` uses `idle.variant_play_seconds` instead. |
| `play_seconds` | Optional per-variant duration range when `repeat_count` is `null` or omitted; otherwise the shared idle duration applies. |
| `click_interactable` | Allow click and tilt animation reactions when a drag starts in this state. `false` keeps the animation playing while dragging. |
| `hover_interactable` | Allow hover animation reactions. `false` keeps the current animation when the pointer enters or leaves. |
| `face_type` | `custom` retains authored face frames; `none` hides the face; `neutral` uses frame 0; `blink` uses frame 2. |
| `face_anchor` | `face` retains the authored face-marker movement. Another existing marker name or a node path relative to `body` can anchor the face there. An unresolved anchor warns and uses `face`. There is no built-in `eye` marker. |

Dragging, right-click menus, and middle-click tips remain available regardless of these flags. The flags control their respective automatic animation reactions; explicit menu actions and scheduled state changes keep their normal behavior. A drag with `click_interactable: false` preserves the current animation and pauses its idle timer until release, then resumes the timer's remaining duration.

For example, this lets `idle_work` switch to click and tilt animations while dragging and plays it for 50–100 complete loops:

```json
"idle_work": {
    "type": "idle_variant",
    "enabled": true,
    "repeat_count": [50, 100],
    "click_interactable": true,
    "hover_interactable": false,
    "face_type": "custom",
    "face_anchor": "face"
}
```

The checked-in variants use `repeat_count: null` to retain the existing 180–360 seconds of playback. `idle.variant_wait_seconds` replaces `IDLE_VARIANT_WAIT_MIN` / `IDLE_VARIANT_WAIT_MAX`; its default `[60, 90]` waits 60–90 seconds before choosing a variant. `idle.variant_play_seconds` replaces the former playback duration constants. A non-null `repeat_count` overrides that duration for its variant.

`sleep.time_window` and each entry in `dinner.time_windows` contain start and end times as `[[hour, minute], [hour, minute]]`, using the local system clock and an exclusive end time. Overnight windows can cross midnight. `idle_nap.inactivity_seconds` controls the inactivity delay. `pet.mood_gain` and `feed_success.health_gain` control interaction rewards.

## Shared settings

Scales, drag-tilt thresholds, stat limits and initial values, decay interval, popup sizes and spacing, note-save delay, tip duration, and menu-close grace are under `settings`. Time values ending in `_seconds` are measured in seconds; window sizes are `[width, height]` pairs.

The UI still saves personal pet scale, startup choice, and window position in `user://data/config.txt`. Saved scale and startup choices take precedence over the JSON defaults. The application does not overwrite `user_config.json` when saving these preferences.

The old flat state lists, CSS labels, birthday entry, and scale presets were unused by the current Godot application. Their supported settings are now organized under `settings` and individual animation entries.
