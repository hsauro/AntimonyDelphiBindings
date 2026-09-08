# Antimony Delphi Bindings

Delphi bindings to libAntimony, plus an OOP wrapper and a console example.

- `AntimonyAPI.pas` — low-level static (load-time) binding, a mechanical mirror
  of `antimony_api.h` (libAntimony 2.8). Changes here follow the C header;
  don't invent signatures. Ergonomics belong in the wrapper.
- `AntimonyWrapper.pas` — `TAntimony`, the high-level wrapper.
- `AntimonyExample.dpr` — usage example. `AntimonyBindingsGroup.groupproj` is
  the project group.

## Build

```
cmd /c '"C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild AntimonyExample.dproj /t:Build /p:Config=Debug /p:Platform=Win64'
```

Defaults are Debug / Win64; the exe lands in `Win64\Debug\`.

## Runtime dependency

The exe will not start without `libantimony.dll` and the MSVC 140 runtime DLLs
sitting beside it in the output folder. A build can succeed and the app still
fail to launch — check for those files first. They come from the
`antimony-windows-latest-release.zip` release at
https://github.com/sys-bio/antimony.

## Memory management

libAntimony returns malloc'd memory the caller owns. `TAntimony` copies every
result into Delphi-owned storage and calls `freeAll()` once in its destructor.
Never mix raw `AntimonyAPI` calls with the wrapper in the same program — if
anything frees an individual pointer, the destructor's `freeAll()` crashes.
Use one or the other, exclusively.
