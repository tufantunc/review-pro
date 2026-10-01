<!-- opencv__opencv@e3e45c8 correctness-reviewer; verbatim final answer -->
## Correctness findings: none

I found no correctness defects in this change.

- **`samples/opengl/opengl_interop.cpp:224,229,234` (Windows branch).**
  - **MSVC support:** this branch is not new ground for `snprintf`. The Windows-only sample `samples/directx/d3d9_interop.cpp:259-274` already uses `snprintf(buf, sizeof(buf), ...)` the same way, followed by `::TextOut(hDC, 0, y, buf, (int)strlen(buf))`. The change adds no toolchain requirement beyond what the Windows samples already build with.
  - **Buffer size:** the old `sprintf_s(buf, sizeof(buf)-1, ...)` called MSVC's invalid-parameter handler when output overflowed, which aborts by default. The new `snprintf(buf, sizeof(buf), ...)` truncates instead and always null-terminates within the 257-byte buffer. That is the same or safer.
  - **UNICODE/TextOut:** the `char*`/`TextOut` pairing is unchanged by this diff, so any behaviour under `UNICODE` was there before.
  - **Linux branch:** line 242 still uses `sizeof(buf)-1`. That line is untouched, and the only effect is one unused byte.
- **`samples/cpp/tutorial_code/objectDetection/aruco_samples_utility.hpp:35`.**
  - **Buffer size:** the longest possible output is `"flags: "` plus all four suffixes, about 81 characters. That fits easily in `char buf[1024]`.
  - **Is `buf` used?** No. The text written by `snprintf` is never read: line 41 writes the integer `flags` (`fs << "flags" << flags;`), not `buf`. This dead write existed before the change, so I'm not filing it as a defect introduced here.
- **`samples/cpp/tutorial_code/ImgTrans/HoughLines_Demo.cpp:75`.** The format is a fixed literal with no format specifiers, 17 characters into a 50-byte buffer. The output is the same as before.

## Files examined
examined: [samples/cpp/tutorial_code/ImgTrans/HoughLines_Demo.cpp, samples/cpp/tutorial_code/objectDetection/aruco_samples_utility.hpp, samples/opengl/opengl_interop.cpp]
not_examined: []
