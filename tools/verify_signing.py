"""Compare a built APK to the pinned PUBLIC certificate digest."""
import pathlib, subprocess, sys, re
apk, verifier = sys.argv[1:]
result = subprocess.run([verifier,'verify','--print-certs',apk],capture_output=True,text=True,check=True)
match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)',result.stdout)
expected = pathlib.Path('android-signing.sha256').read_text().strip().lower()
if not match or match.group(1).lower() != expected:
    raise SystemExit('APK signature does not match the permanent certificate')
print('Verified APK against pinned permanent certificate: '+expected)
