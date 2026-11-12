#!/usr/bin/env python3
"""Read-only audit for an iOS IPA. Does not modify or re-sign the archive."""

from __future__ import annotations

import argparse
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

SYMBOL_RE = re.compile(
    r"(?:^|\s)_?(?:al_(?:pairing_[A-Za-z0-9_]+|exploit_[A-Za-z0-9_]+|"
    r"find_app_container|list_app_containers|get_app_icon_png|log_init|"
    r"string_free)|ALGetGrappaToken)(?:$|\s)"
)
STRING_RE = re.compile(
    r"(?:^|/)(?:Erosion/[^\s]+\.swift)|"
    r"(?:al_(?:pairing_[A-Za-z0-9_]+|exploit_[A-Za-z0-9_]+|"
    r"find_app_container|list_app_containers|get_app_icon_png|log_init|"
    r"string_free)|ALGetGrappaToken)|"
    r"(?:_remotepairing-pairable-host\._tcp|_erosionprobe\._tcp)|"
    r"(?:24A5355q|24A5370h|24A5380h|24A5390f)|"
    r"(?:LocalDevVPN|diagnostics_relay|NeoSpring|/var/mobile/Library/SpringBoard|"
    r"/var/mobile/Library/Preferences/com\.apple\.springboard\.plist)"
)


def run_text(args: list[str]) -> str | None:
    try:
        result = subprocess.run(args, check=False, capture_output=True, text=True)
    except OSError:
        return None
    return result.stdout if result.returncode == 0 else None


def safe_app_entries(zf: zipfile.ZipFile) -> tuple[str, dict[str, object], list[str]]:
    names = zf.namelist()
    plist_paths = [
        name for name in names
        if name.startswith("Payload/") and name.endswith(".app/Info.plist")
    ]
    if not plist_paths:
        raise ValueError("No Payload/*.app/Info.plist found in archive")
    if len(plist_paths) > 1:
        raise ValueError("Multiple app bundles found; this script expects one app")

    plist_path = plist_paths[0]
    info = plistlib.loads(zf.read(plist_path))
    app_root = plist_path.rsplit("/Info.plist", 1)[0]
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or not executable:
        raise ValueError("CFBundleExecutable is missing from Info.plist")
    executable_path = f"{app_root}/{executable}"
    if executable_path not in names:
        raise ValueError(f"Executable not found in IPA: {executable_path}")
    app_entries = [name for name in names if name.startswith(app_root + "/")]
    return executable_path, info, app_entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path, help="Path to the .ipa file")
    args = parser.parse_args()
    ipa = args.ipa.expanduser().resolve()
    if not ipa.is_file():
        parser.error(f"IPA does not exist: {ipa}")

    try:
        with zipfile.ZipFile(ipa) as zf:
            bad_member = zf.testzip()
            if bad_member:
                raise ValueError(f"ZIP CRC test failed for {bad_member}")
            executable_path, info, app_entries = safe_app_entries(zf)
            binary_data = zf.read(executable_path)
            has_codesign = any("/_CodeSignature/" in name for name in app_entries)
            has_profile = any(name.endswith("/embedded.mobileprovision") for name in app_entries)
            app_root = executable_path.rsplit("/", 1)[0]
            top_level = sorted({name[len(app_root) + 1:].split("/", 1)[0]
                                for name in app_entries
                                if name not in (executable_path, app_root + "/")})
    except (zipfile.BadZipFile, KeyError, ValueError, plistlib.InvalidFileException) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(f"IPA: {ipa.name} ({ipa.stat().st_size:,} bytes)")
    print(f"Display name: {info.get('CFBundleDisplayName', info.get('CFBundleName', '?'))}")
    print(f"Bundle ID: {info.get('CFBundleIdentifier', '?')}")
    print(f"Version: {info.get('CFBundleShortVersionString', '?')} ({info.get('CFBundleVersion', '?')})")
    print(f"Minimum iOS: {info.get('MinimumOSVersion', '?')}")
    print(f"SDK: {info.get('DTSDKName', '?')} | Xcode: {info.get('DTXcodeBuild', '?')}")
    print(f"Device family: {info.get('UIDeviceFamily', '?')}")
    print(f"Executable: {executable_path} ({len(binary_data):,} bytes)")
    print(f"Top-level app contents: {', '.join(top_level) if top_level else '(none)'}")
    print(f"_CodeSignature present: {'yes' if has_codesign else 'no'}")
    print(f"embedded.mobileprovision present: {'yes' if has_profile else 'no'}")

    strings_tool = shutil.which("strings")
    objdump_tool = shutil.which("llvm-objdump")
    with tempfile.TemporaryDirectory(prefix="ipa-audit-") as tmp:
        binary_path = Path(tmp) / "app-executable"
        binary_path.write_bytes(binary_data)

        if objdump_tool:
            output = run_text([objdump_tool, "--macho", "--syms", str(binary_path)])
            if output is not None:
                symbols = sorted({line.strip() for line in output.splitlines() if SYMBOL_RE.search(line)})
                print("\nAirlift / FFI symbols:")
                print("\n".join(symbols) if symbols else "(none found in symbol table)")
            else:
                print("\nllvm-objdump could not inspect the binary")
        else:
            print("\nllvm-objdump not found; install Xcode Command Line Tools or LLVM for symbol output")

        if strings_tool:
            output = run_text([strings_tool, "-a", str(binary_path)])
            matches = sorted({match.group(0) for line in (output or "").splitlines()
                              for match in STRING_RE.finditer(line)})
            print("\nSelected embedded strings:")
            print("\n".join(matches) if matches else "(no selected strings found)")
        else:
            print("\nstrings not found; install the system developer tools for embedded-string output")

    print("\nAudit only: this script does not prove exploit compatibility or device-side success.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
