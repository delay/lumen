# Lumen

Lumen is an [Omarchy](https://omarchy.org/) top-bar plugin for changing the
color temperature, saturation, and brightness of your entire display. It puts
comfortable reading modes, vivid color, grayscale, and your own display
presets one click away.

## Demo

<video src="https://github.com/user-attachments/assets/fec81f11-496b-4378-ae5c-28738cca7d25" autoplay loop muted playsinline controls title="Lumen display presets demo"></video>

[Play the Lumen demo](https://github.com/user-attachments/assets/fec81f11-496b-4378-ae5c-28738cca7d25)

## Features

- Six editable presets: Standard, Red Light, Candle, Black & White, Color Ink,
  and Vivid
- Custom presets with editable names and display values
- Color temperature from 1,000 K to 7,000 K
- Saturation from grayscale (0%) to vivid color (200%)
- Optional per-preset brightness overrides
- Auto brightness mode that restores the display's previous brightness
- A configurable two-point daily preset schedule
- Optional three-second water-ripple transition from the Lumen bar icon
- An Active Presets panel for showing or hiding presets without deleting them
- Right-click shortcut to return immediately to Standard

## Built-in presets

| Preset | Temperature | Saturation | Purpose |
| --- | ---: | ---: | --- |
| Standard | 6,500 K | 100% | Neutral daylight color |
| Red Light | 1,000 K | 100% | Deep warm light for dark environments |
| Candle | 1,800 K | 90% | Softer candlelight color |
| Black & White | 6,500 K | 0% | Neutral grayscale |
| Color Ink | 6,500 K | 40% | Muted, paper-like color |
| Vivid | 6,500 K | 160% | Rich, highly saturated color |

Each preset can be changed independently. Select the sliders icon that appears
when you hover over a preset to edit its temperature, saturation, and
brightness. **Restore Defaults** resets only the preset being edited.

## Requirements

- Omarchy 4 or newer
- Hyprland with screen-shader support
- A Nerd Font for the interface icons (included with a standard Omarchy setup)

## Installation

Install and enable Lumen directly from GitHub:

```bash
omarchy plugin add https://github.com/delay/lumen.git --enable
```

After installation, the Lumen candle icon appears in the right section of the
top bar. If it is not already visible, enable it manually:

```bash
omarchy plugin enable delay.lumen
```

To update an installed copy later:

```bash
omarchy plugin update delay.lumen
```

## Usage

Left-click the Lumen bar icon to open the preset panel, then select a preset to
apply it. Right-click the icon to return to Standard immediately.

Open the settings panel with the sliders button in the upper-right corner. From
there you can:

- Add a custom preset.
- Choose which presets appear in the main panel.
- Configure two daily schedule switch times and their target presets.
- Turn the ripple animation on or off.

Schedule times use 24-hour `HH:MM` format. Lumen checks the schedule every 30
seconds and remembers the last applied event, so restarting the shell catches
up with the current scheduled period without repeatedly overriding a manual
change.

Brightness uses **Auto** by default. Dragging the brightness slider turns Auto
off and saves an override for that preset. Turning Auto back on restores the
brightness that was active before Lumen applied an override.

## Command line

The bundled `lumen` helper can also be run directly from the plugin directory:

```bash
./lumen status
./lumen state
./lumen set standard
./lumen set red-light
./lumen set-temperature 1800
./lumen set-saturation 75
./lumen set-preset candle 1800 90 auto
./lumen schedule-state
```

Run `./lumen` without arguments to see the complete command synopsis.

## Local development

Clone the repository and install it through Omarchy:

```bash
git clone https://github.com/delay/lumen.git
cd lumen
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable
```

Plugin files installed under `~/.config/omarchy/plugins/` are watched by the
Omarchy shell. If a change does not reload automatically, run:

```bash
omarchy restart shell
```

## How it works

Lumen generates a Hyprland screen shader for the selected temperature and
saturation. Preset transitions temporarily install an animated ripple shader,
then replace it with the final static shader. Brightness overrides use
Omarchy's native display-brightness control. User settings are stored under
`$XDG_STATE_HOME/lumen`, or `~/.local/state/lumen` when `XDG_STATE_HOME` is not
set.

## License

[MIT](LICENSE) © 2026 delay
