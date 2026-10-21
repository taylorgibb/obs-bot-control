# OBS Bot Control

A macOS menu bar app with a camera icon that controls an OBSBOT Tiny 2 or Tiny 2 Lite without the vendor's application.

- Tracking: Normal, Upper Body, Close-Up, Headless, Lower Body, Group, Hand, Whiteboard, Disable
- Gestures: Target Select, Zoom, Dynamic Zoom, Zoom Direction, Disable All
- Launch at Login toggle

Requires macOS 14 or newer. The app makes no network calls. It opens the camera only when the menu opens or an item is chosen and releases it straight after, because the camera allows one open handle at a time.

## Install

Download `OBS-Bot-Control.zip` from the latest release, unzip it and move `OBS Bot Control.app` to Applications. The build is ad hoc signed and not notarised, so the first launch needs right click, Open (or `xattr -dr com.apple.quarantine "OBS Bot Control.app"`).

## Develop

| Command | Effect |
|---|---|
| `make test` | Checks the protocol frames against the frames proven on hardware |
| `make build` | Builds a universal app into `build/` |
| `make package` | Zips the app and writes its checksum |

CI builds and tests on every push and pull request. Pushing a tag such as `v0.1.0` publishes a GitHub release with the zip and checksum.

## Wire protocol

The camera is a UVC device (vendor `0x3564`, product `0xFEF8` Tiny 2, `0xFEF9` Tiny 2 Lite) with a vendor extension unit, unit 2. Requests are USB class control transfers on the video control interface: `SET_CUR` (`0x21`, `0x01`) and `GET_CUR` (`0xA1`, `0x81`) with `wValue` the selector in the high byte and `wIndex` `0x0200`, always 60 bytes.

Selector 6 is the status block. Reading it returns the tracking mode at byte `0x18` and submode at `0x1C`. Writing `16 02 <mode> <submode>` sets tracking:

| Mode | (mode, submode) |
|---|---|
| Disable | (0, 0) |
| Normal | (2, 0) |
| Upper Body | (2, 1) |
| Close-Up | (2, 2) |
| Headless | (2, 3) |
| Lower Body | (2, 4) |
| Group | (1, 0) |
| Hand | (3, 0) |
| Whiteboard | (4, 0) |

Selector 2 carries frames: `AA`, flags, sequence (u16), header span `0C 00`, header CRC, sender `0A`, receiver `04`, command (u16) and, with a payload, payload length (u16), payload CRC and the payload. CRCs are CRC-16/USB (polynomial `0xA001`, initial and final XOR `0xFFFF`). Writes use flags `0x25`, reads `0x01`, and the reply comes back with `0x29` and the same sequence and command.

| Gesture | Set command | Payload | Reply payload byte |
|---|---|---|---|
| Target Select | `0x30C4` | `01` on, `00` off | 3 |
| Zoom | `0x3144` | same | 4 |
| Dynamic Zoom | `0x3344` | same | 5 |
| Zoom Direction | `0x33C4` | same | 6 |

Gesture state is read by sending command `0x0104` with no payload and reading the reply from selector 2.

## Provenance

The tracking commands and frame layout come from [cgevans/tiny2](https://github.com/cgevans/tiny2) and [mitchelloharawild/obsbot-tiny-2-control](https://github.com/mitchelloharawild/obsbot-tiny-2-control). The gesture commands were derived for interoperability with the owner's own camera. No vendor code or binary is in this repository.

Verified on an OBSBOT Tiny 2 Lite: every tracking mode above and each gesture was set and read back. Desk mode was refused and is left out. A Tiny 2 is expected to behave the same and has not been tested. The app sends only the commands listed here, since stray commands to the camera's upgrade or factory subsystems can drop it off the bus.
