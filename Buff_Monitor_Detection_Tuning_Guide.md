# Buff Monitor Detection Tuning Guide

The main setting is **`DetectionIntervalMs`**. When the buff bar rearranges, Python temporarily keeps copying pixels from the old coordinates until the next template search finds Rend at the new position.

## Recommended Starting Preset

```ini
DetectionIntervalMs=100
DisplayIntervalMs=33
MissesBeforeGone=3
RendThreshold=0.72
PowerChargeThreshold=0.72
```

### What Changes

- **Detection: 200 ms to 100 ms**  
  Rend's new position can be found up to twice as quickly.

- **Display: 50 ms to 33 ms**  
  Live icon pixels update at approximately 30 FPS instead of 20 FPS.

- **Misses: 2 to 3**  
  Three consecutive misses are required before switching to the grayscale icon.

At 100 ms detection and three misses, confirmed disappearance takes roughly 300 ms. This should suppress brief false-negative flickers while keeping the indicator responsive.

## What Each Setting Affects

### `DetectionIntervalMs`

Controls how frequently Python searches the buff bar.

Lower values:

- Reacquire Rend faster when icons rearrange
- Reduce the time spent copying the wrong old location
- Increase CPU use

Try in this order:

```ini
DetectionIntervalMs=100
```

Then, only if needed:

```ini
DetectionIntervalMs=75
```

Do not go below 50 ms for this feature. The timer and icon position do not require extremely high-frequency detection.

### `DisplayIntervalMs`

Controls how frequently pixels are copied from the **last detected location**.

Lower values make the live timer look smoother:

```ini
DisplayIntervalMs=33
```

or:

```ini
DisplayIntervalMs=25
```

However, this does **not** find the new position faster. If the stored position is temporarily stale, faster display refresh can reproduce the wrong pixels more frequently. Therefore, adjust detection first.

### `MissesBeforeGone`

Controls false-negative filtering:

```ini
MissesBeforeGone=3
```

If the gray fallback still appears briefly:

```ini
MissesBeforeGone=4
```

Use this together with faster detection. For example:

```ini
DetectionIntervalMs=75
MissesBeforeGone=4
```

That still gives approximately 300 ms before confirmed disappearance.

Higher values reduce flicker but delay the correct transition when Rend genuinely expires.

### Thresholds

Do not adjust thresholds first.

Observed scores were roughly:

```text
Rend present:         0.971 to 1.000
Rend absent:          around 0.461

Power Charge present: 0.979 to 1.000
Power Charge absent:  as high as 0.691
```

The current thresholds:

```ini
RendThreshold=0.72
PowerChargeThreshold=0.72
```

have good separation. In particular, lowering the Power Charge threshold below approximately `0.70` could classify an absent state scoring `0.691` as present.

## Suggested Test Presets

### Balanced, Recommended First

```ini
DetectionIntervalMs=100
DisplayIntervalMs=33
MissesBeforeGone=3
```

### Faster Response

```ini
DetectionIntervalMs=75
DisplayIntervalMs=25
MissesBeforeGone=4
```

### Lower Processing

```ini
DetectionIntervalMs=125
DisplayIntervalMs=33
MissesBeforeGone=3
```

## How to Test Consistently

Use a situation where another buff repeatedly appears and disappears before Rend, forcing Rend to move between slots.

Watch for different problems:

1. **Wrong icon appears briefly**  
   Reduce `DetectionIntervalMs`.

2. **Gray Rend icon appears briefly**  
   Increase `MissesBeforeGone`.

3. **Correct Rend icon looks visually choppy**  
   Reduce `DisplayIntervalMs`.

Change only one parameter per test, so the effect of each change is clear.

## If Settings Cannot Remove the Blip Completely

A brief wrong-icon flash may remain because the display loop continuously copies the old screen rectangle while detection is reacquiring Rend.

The clean code-level fix would be:

- Save the last valid Rend crop
- When the old location becomes questionable, freeze that saved crop
- Resume live copying only after Rend is found at the new location

This prevents a neighboring icon from appearing during buff-bar reflow. Start with the balanced preset first because measured CPU headroom is substantial and faster detection may already make the transition effectively invisible.
