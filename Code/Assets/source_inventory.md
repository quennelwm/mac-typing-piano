# Original synthetic probe provenance

- Role/task: internal code helper, C-001; separate from A-001 sound design.
- Source: `../Scripts/generate_placeholder.py`, original mathematical synthesis, no external audio and no network downloads.
- Authoring date: 2026-10-28.
- Declaration: `PLACEHOLDER-LICENSE.txt`, CC0-1.0 for the generated probe bank.
- Build: `python3 Code/Scripts/generate_placeholder.py` from repository root; Python standard library only.
- Output: genuine RIFF `sfbk` / SF2 2.1, six mono 16-bit 22,050 Hz sample zones covering MIDI 33–96.
- Processing: 440 Hz A4 equal temperament; sine fundamental plus 0.22 second harmonic and 0.08 third harmonic; 3 ms attack, exponential natural decay, final 20 ms fade; peak scale 0.35; no recorded material and no sample looping.
- Roots/zones and actual bank SHA-256/byte size are emitted into `placeholder.manifest.json`. The generator contains no timestamps/randomness; reproducibility is checked by running it twice on the recorded environment.
- SF2 volume-envelope release is encoded as rounded timecents for 450 ms. Actual Apple sampler output is assessed separately by offline tests.
- Bank preset 0, bank 0; Apple sampler loading uses program 0, melodic MSB 121 and LSB 0.
- Sound is an intentionally simple synthetic engine fixture. It is not a claim of piano realism, final sound design, loudness safety, 64 physical/internal voices, or hardware acceptance. No listening has occurred.
- No formal `Resources/Audio` registration and no modification to the frozen audio manifest contract.
