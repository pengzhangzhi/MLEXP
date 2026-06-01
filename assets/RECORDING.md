# Demo media

The four clips in the README — `demo-hero.gif`, `demo-monitor.gif`, `demo-debug.gif`,
and `demo-report.gif` — are rendered from HTML with
[HyperFrames](https://github.com/heygen-com/hyperframes) (a deterministic HTML→video
renderer) and converted to GIF with ffmpeg. No screen recording, no manual editing:
same input, same frames, same output.

## What each clip shows

| File | Shows | Length |
|---|---|---|
| `demo-hero.gif` | The whole arc — type a research question, the lifecycle runs (new → implement → submit → monitor → debug → report), then the results table and decision memo. | ~15 s |
| `demo-monitor.gif` | `/mlexp-monitor` catching a Slurm preemption and auto-resuming from checkpoint. | ~10 s |
| `demo-debug.gif` | `/mlexp-debug` turning a NaN divergence into a root cause and a one-line fix. | ~10 s |
| `demo-report.gif` | `/mlexp-report` emitting the results table and the confirmatory-vs-exploratory memo. | ~10 s |

## Regenerating or swapping a clip

Each clip is a self-contained HTML composition. With HyperFrames installed
(`npx hyperframes init`), render to MP4 and convert to a small GIF:

```bash
hyperframes render -o out.mp4              # HTML composition -> MP4
ffmpeg -i out.mp4 -vf "fps=13,scale=820:-1:flags=lanczos,palettegen=stats_mode=diff" pal.png
ffmpeg -i out.mp4 -i pal.png -lavfi \
  "fps=13,scale=820:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" demo-hero.gif
```

Keep clips small (12–13 fps, ≤ 900 px wide — the hero here is under 1 MB) and leave the
README `<img>` `src` pointing at the `.gif`. To use a real screen recording instead,
capture the Claude Code session ([asciinema](https://asciinema.org) +
[agg](https://github.com/asciinema/agg), or any recorder piped through ffmpeg) and drop
it in over the same filename.

## Bonus: the quickstart is scriptable

The install snippet is deterministic, so it can be auto-rendered with
[VHS](https://github.com/charmbracelet/vhs):

```bash
vhs quickstart.tape   # -> quickstart.gif
```

See [`quickstart.tape`](quickstart.tape).
