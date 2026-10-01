<!-- opencv__opencv@e3e45c8 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings: none

I checked all three changed files against the conventions already used in `samples/`. None of the changes adds an invented API, a config key, a dependency or an extra abstraction.

- **`samples/opengl/opengl_interop.cpp:224,229,234`.** The Windows branch now calls `snprintf(buf, sizeof(buf), ...)` instead of the MSVC-only `sprintf_s`. Other Windows-only samples already use `snprintf` with `sizeof(buf)`, for example `samples/directx/d3d9_interop.cpp:260-275` and `samples/directx/d3d9ex_interop.cpp:261-276`, so the API is portable and established here. The Linux branch at line 242 uses `sizeof(buf)-1`, but that is the less common form: `git grep` finds it only there and in `samples/va_intel/va_intel_interop.cpp:53`. All the other `snprintf` calls in samples pass the full buffer size. Using full `sizeof(buf)` is correct because `snprintf` always null-terminates. Line 242 itself was not changed.
- **`samples/cpp/tutorial_code/ImgTrans/HoughLines_Demo.cpp:75`.** `snprintf(edge_thresh_label, sizeof(edge_thresh_label), "Edge Thres: input")` formats a literal with no arguments, so a `const char*` would be enough. The change didn't create that pattern: it's a one-to-one swap of the old `sprintf` line. The same literal-only form already exists at `samples/directx/d3d9_interop.cpp:265`, and it matches line 67 of the same file. Because the change only kept a pattern that was already there, I did not file it as over-engineering.
- **`samples/cpp/tutorial_code/objectDetection/aruco_samples_utility.hpp:35`.** `snprintf(buf, sizeof(buf), "flags: %s%s%s%s", ...)` uses the same form as the matching code in `samples/cpp/calibration.cpp:247`.

Two things I left alone because the change didn't introduce them. First, the `buf[0] = 0;` lines in `opengl_interop.cpp` were already unnecessary before the change. Second, `::TextOut` is given a `char` buffer, which would be the wrong type in a UNICODE build. Also, the commit subject names only `aruco_samples_utility.hpp` although three files changed. That is outside my concern.

## Files examined
examined: [samples/cpp/tutorial_code/ImgTrans/HoughLines_Demo.cpp, samples/cpp/tutorial_code/objectDetection/aruco_samples_utility.hpp, samples/opengl/opengl_interop.cpp]
not_examined: []
