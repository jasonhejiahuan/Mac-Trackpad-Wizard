# Trackpad Haptic Pattern Standard

Trackpad Wizard 0.2 uses a portable JSON format for recorded, imported, exported, and saved haptic patterns.

## Identity and versioning

- `format`: `cc.jasonstu.trackpadwizard.haptic-pattern`
- `schemaVersion`: `1`
- File naming convention: `*.trackpadhaptic.json`
- Date fields: ISO 8601 in exported files
- Time fields: seconds
- Amplitude: normalized `0.0...1.0`
- Frequency: pulse-repetition rate in `8...120 Hz`

Frequency is not the private actuator’s internal carrier frequency. Each event describes one or more complete actuator calls. Trackpad Wizard calculates the count as `round(durationSeconds * frequencyHz)`, with a minimum of one oscillation, then spaces those calls at `1 / frequencyHz` seconds.

## Document shape

```json
{
  "format": "cc.jasonstu.trackpadwizard.haptic-pattern",
  "schemaVersion": 1,
  "id": "45D2A41C-845A-45C4-AE2C-8FB9DE2E9121",
  "name": "Measured Rhythm",
  "createdAt": "2026-08-28T12:00:00Z",
  "modifiedAt": "2026-08-28T12:00:00Z",
  "events": [
    {
      "id": "1078C12B-FC30-4ADB-97E4-88DBCB7A45EC",
      "timeSeconds": 0.0,
      "amplitude": 0.42,
      "frequencyHz": 80.0,
      "durationSeconds": 0.0125,
      "feedback": 4
    }
  ]
}
```

`feedback` is the empirical actuator waveform identifier represented by `HapticFeedbackKind`: `1...6`, `15`, or `16`.

## Validation limits

- Pattern name: 1–80 non-whitespace characters
- Events: 1–500
- Pattern duration: at most 300 seconds
- Expanded oscillations: at most 20,000
- Event start time: finite and nonnegative
- Event duration: at least one period (`1 / frequencyHz`)

Events are sorted by `timeSeconds` after validation. Imports outside these bounds are rejected rather than silently clamped.

## Click recording

The recording surface stores the physical click timestamp reported by AppKit. If click pressure is reported, it becomes the event amplitude; otherwise the current Custom Signal amplitude is used. The current Custom Signal waveform and pulse frequency are captured with each click. Because AppKit does not identify whether a pointer click came from a trackpad or mouse, the recording surface describes the intended input but does not claim device attribution.
