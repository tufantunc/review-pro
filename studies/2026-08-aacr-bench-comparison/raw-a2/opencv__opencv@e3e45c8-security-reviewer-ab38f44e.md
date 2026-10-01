<!-- opencv__opencv@e3e45c8 security-reviewer; verbatim final answer -->
## Security findings: none

This change adds no security defects. It is a hardening change.

- **`sizeof(buf)` is correct everywhere.** Every target buffer is a local `char` array, not a pointer, so `sizeof(buf)` gives the real capacity: `char edge_thresh_label[50]`, `char buf[1024]` at `aruco_samples_utility.hpp:25`, and `char buf[256+1]` at `opengl_interop.cpp:220`. The format strings are all literals, so there is no format-string injection.
- **`HoughLines_Demo.cpp`:** the copied text is a fixed 17-character literal. It could never overflow the 50-byte buffer.
- **`aruco_samples_utility.hpp`:** the longest possible output is fixed and well under 1024 bytes. It is made only of literals chosen by the `flags` bits.
- **`opengl_interop.cpp` (Windows only):** `snprintf(buf, sizeof(buf), ...)` stops at 256 characters plus the terminating NUL, so it stays inside the buffer. The old MSVC `sprintf_s(buf, sizeof(buf)-1, ...)` would call the invalid-parameter handler on an over-long `oclDevName`, which by default ends the process. `snprintf` cuts the text short and still ends it with a NUL, so the `strlen` that `TextOut` relies on stays inside the buffer. `oclDevName` comes from the local OpenCL driver, not from a lower-trust actor. Even so, the new behaviour is strictly safer than the old one.

## Files examined
examined: [samples/cpp/tutorial_code/ImgTrans/HoughLines_Demo.cpp, samples/cpp/tutorial_code/objectDetection/aruco_samples_utility.hpp, samples/opengl/opengl_interop.cpp]
not_examined: []
