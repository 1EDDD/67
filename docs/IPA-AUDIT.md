# Erosion mod 2.2: IPA audit

Audit date: 2026-11-12  
Input artifact: erosion.mod.v2.2.ipa

## Bundle metadata

| Field | Value |
|---|---|
| Display name | Erosion mod |
| Bundle identifier | com.jbdotparty.Erosion |
| App version / build | 2.2 / 1 |
| Minimum iOS | 26.0 |
| SDK / Xcode build metadata | iOS SDK 26.5, Xcode 17F113 |
| Device family | iPhone and iPad |
| Executable architecture | arm64 |

The supplied archive contains one main Mach-O executable, Assets.car, app icons, Info.plist, and the ZIPFoundation_ZIPFoundation.bundle privacy resources. It does not contain the app's Swift sources, a separate AirliftFFI.xcframework, or a dSYM. The extracted app bundle also has no _CodeSignature directory or embedded.mobileprovision file.

## Airlift functionality visible in the executable

The Mach-O symbol table includes these Airlift entry points:

- al_pairing_run_host
- al_exploit_run
- al_exploit_read_file
- al_exploit_read_folder
- al_exploit_write_dir
- al_exploit_write_file
- al_exploit_inject_folder
- al_exploit_remove_path
- al_find_app_container
- al_list_app_containers
- al_get_app_icon_png
- al_log_init
- al_string_free
- ALGetGrappaToken

The binary's strings also identify Erosion/AirliftBridge.swift and Erosion/PairingController.swift as compiled source paths. The app advertises the _remotepairing-pairable-host._tcp and _erosionprobe._tcp Bonjour services. Its own UI/log strings say that Airlift file operations require LocalDevVPN and a valid pairing file.

Strings surfaced by the app identify /var/mobile/Library/SpringBoard and /var/mobile/Library/Preferences/com.apple.springboard.plist as Airlift targets presented in its help text. This audit does not verify every possible target path or a successful read/write on a device.

## Respring distinction

The executable contains a WebView-based respring implementation and also contains diagnostics-relay restart messages. These are not interchangeable operations. The matching public Airlift reference implementation documents its al_device_respring function as a full device reboot, while the app's WebView compositor method is the userspace respring path. A future change must keep the labels and confirmation flow separate; a diagnostics-relay Restart request must never be presented as a quick SpringBoard-only respring.

References: [Airlift FFI reference header](https://github.com/Mak5er/AirCard-iOS/blob/main/rust-core/include/airlift.h) and [restart implementation](https://github.com/Mak5er/AirCard-iOS/blob/main/rust-core/src/exploit.rs).

## iOS 27 compatibility: what is and is not established

The artifact's strings contain the iOS 27 beta build identifiers 24A5355q, 24A5370h, 24A5380h, and 24A5390f. The presence of those strings is evidence that those build identifiers were considered by the compiled program; it is not proof that this exact IPA works on every public iOS 27.0 build.

The current upstream Erosion repository documents support for iOS/iPadOS 27.0–27.2.1 and 27.3 beta 1, but that current upstream line uses the worse_query sandbox escape. It is not the same source tree as this custom v2.2 IPA, whose executable contains the Airlift FFI entry points listed above. Do not copy upstream's compatibility claim onto this binary without a matching source diff and device test.

References:

- [Upstream Erosion README](https://github.com/jailbreakdotparty/Erosion)
- [Upstream Erosion v0.3.1 release, 2026-11-10](https://github.com/jailbreakdotparty/Erosion/releases/tag/0.3.1)

## Rebuild blocker and next required input

An IPA is a compiled application package, not a source project. The supplied v2.2 IPA is enough to inspect bundle metadata, source-file names embedded in the binary, strings, and exported symbols. It is not enough to safely make source-level Swift/Rust changes and produce a reproducible IPA.

To make a real v2.2 source build, this repository needs the matching source revision for the custom Erosion app and the exact Rust/C Airlift FFI source, including the implementations behind al_exploit_read_file, al_exploit_read_folder, and al_exploit_remove_path. The public upstream Erosion source is a different code line; substituting it would drop custom Airlift functionality from the supplied artifact.

Until those matching sources are available, only audit tooling and integration notes can be committed here. No claim is made that a rebuilt or modified IPA has been produced.
