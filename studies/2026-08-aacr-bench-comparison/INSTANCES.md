# Sampled instances — phase 1

Drawn by the framework's own reproducible sampler with the pre-registered
parameters `--limit 30 --seed 42`, committed to the registration before anyone
looked at which instances the seed selects. Published verbatim, in the exact
order the review stage processes them — a partial or resumed run truncates this
list from the top, never re-samples.

**30 instances, 23 repositories, 190 reference comments.** No instance lacks ground truth.

Composition is reported as drawn; per the registration the seed is not re-rolled
if the sample looks skewed.

| # | instance_id | repo | refs |
|---:|---|---|---:|
| 1 | `vllm-project__vllm@6217b0c` | vllm-project/vllm | 1 |
| 2 | `lvgl__lvgl@4a57db3` | lvgl/lvgl | 5 |
| 3 | `FreeCAD__FreeCAD@82fef4a` | FreeCAD/FreeCAD | 3 |
| 4 | `elastic__elasticsearch@a6a4623` | elastic/elasticsearch | 5 |
| 5 | `astral-sh__uv@ed57db2` | astral-sh/uv | 6 |
| 6 | `microsoft__typescript-go@b970689` | microsoft/typescript-go | 15 |
| 7 | `valkey-io__valkey@866fa4a` | valkey-io/valkey | 1 |
| 8 | `microsoft__typescript-go@892b4a3` | microsoft/typescript-go | 13 |
| 9 | `wavetermdev__waveterm@90a57d5` | wavetermdev/waveterm | 5 |
| 10 | `google-gemini__gemini-cli@c6e6248` | google-gemini/gemini-cli | 7 |
| 11 | `FreeCAD__FreeCAD@ec3da2e` | FreeCAD/FreeCAD | 3 |
| 12 | `linera-io__linera-protocol@024925d` | linera-io/linera-protocol | 4 |
| 13 | `comfyanonymous__ComfyUI@cfc3122` | comfyanonymous/ComfyUI | 6 |
| 14 | `ollama__ollama@b6002f6` | ollama/ollama | 12 |
| 15 | `mpv-player__mpv@dbd327d` | mpv-player/mpv | 7 |
| 16 | `microsoft__typescript-go@45c0de9` | microsoft/typescript-go | 1 |
| 17 | `elastic__elasticsearch@e38d20c` | elastic/elasticsearch | 5 |
| 18 | `CherryHQ__cherry-studio@5644b00` | CherryHQ/cherry-studio | 23 |
| 19 | `ClickHouse__ClickHouse@5fb6ee3` | ClickHouse/ClickHouse | 11 |
| 20 | `lvgl__lvgl@a0067e3` | lvgl/lvgl | 2 |
| 21 | `FreeCAD__FreeCAD@f8cd643` | FreeCAD/FreeCAD | 6 |
| 22 | `browser-use__browser-use@aab7b3b` | browser-use/browser-use | 2 |
| 23 | `facebook__react@b045f18` | facebook/react | 16 |
| 24 | `valkey-io__valkey@36f37c0` | valkey-io/valkey | 2 |
| 25 | `alibaba__spring-ai-alibaba@4bc7305` | alibaba/spring-ai-alibaba | 10 |
| 26 | `infiniflow__ragflow@a63caa1` | infiniflow/ragflow | 6 |
| 27 | `opencv__opencv@e3e45c8` | opencv/opencv | 4 |
| 28 | `dotnet__aspnetcore@8ac940f` | dotnet/aspnetcore | 5 |
| 29 | `filamentphp__filament@d47632c` | filamentphp/filament | 2 |
| 30 | `laravel__framework@180c25f` | laravel/framework | 2 |

## Repository distribution

| n | repo |
|---:|---|
| 3 | FreeCAD/FreeCAD |
| 3 | microsoft/typescript-go |
| 2 | lvgl/lvgl |
| 2 | elastic/elasticsearch |
| 2 | valkey-io/valkey |
| 1 | vllm-project/vllm |
| 1 | astral-sh/uv |
| 1 | wavetermdev/waveterm |
| 1 | google-gemini/gemini-cli |
| 1 | linera-io/linera-protocol |
| 1 | comfyanonymous/ComfyUI |
| 1 | ollama/ollama |
| 1 | mpv-player/mpv |
| 1 | CherryHQ/cherry-studio |
| 1 | ClickHouse/ClickHouse |
| 1 | browser-use/browser-use |
| 1 | facebook/react |
| 1 | alibaba/spring-ai-alibaba |
| 1 | infiniflow/ragflow |
| 1 | opencv/opencv |
| 1 | dotnet/aspnetcore |
| 1 | filamentphp/filament |
| 1 | laravel/framework |

## Provenance

- Dataset: AACR-Bench v1.0 `positive_samples.json`, sha256
  `d8683cb240249bc4e0aff6428802bdffa7b7573ace600552cab1cd0cb7e905c9` — verified by
  the framework on download.
- Converter: `python -m converters.aacr_bench --limit 30 --seed 42 --validate`,
  run in the pinned fork. Schema validation passed for all 30.
