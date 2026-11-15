# Original Blue Horizon audio

All WAV files here were composed/synthesised for this project through Codex-authored code. No commercial
music, sampled melodies, NASA recordings, voice clones or third-party sound libraries are included.
These are original project assets, with AI assistance disclosed in the repository's AI_USAGE.md.

- `horizon.wav`: original 48-second stereo ambient cycle, soft E-minor/C/G/D harmony, sparse bell motif.
- `scan`, `scanner`, `drill`: stylised instrument feedback.
- `confirm`, `checkpoint`, `warning`, `click`: visual events reinforced with short tones.
- `rover`, `engine`, `impact`: abstract vehicle/operator feedback, not external sounds recorded on the Moon.
- `mars_wind`: deterministic filtered-noise ambience; only used for Mars storms.

Regenerate with Python's standard library:

```sh
python godot/tools/generate_audio.py
```

The source is 22,050 Hz / 16-bit PCM, with stereo for music and mono for effects. The generator checks its
peaks before encoding to avoid clipping. Godot imports the WAVs; the director configures forward loops,
uses separate music/feedback buses and provides persistent levels and mute. The score intentionally sits
quietly below action tones. Playback references are stopped and released on shutdown.

Do not label these as NASA audio or measured acoustic simulations. Mars does support sound in its thin
atmosphere; our wind is illustrative. The Moon has no atmospheric wind layer in this game. All alerts,
tool states and objectives are also shown visually.
