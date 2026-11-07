"""Compare a built APK to the pinned PUBLIC certificate digest."""
import pathlib, subprocess, sys, re
apk, verifier = sys.argv[1:]
result = subprocess.run([verifier,'verify','--print-certs',apk],capture_output=True,text=True,check=True)
match = re.search(r'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)',result.stdout)
expected = pathlib.Path('android-signing.sha256').read_text().strip().lower()
actual = match.group(1).replace(':','').lower() if match else None
if actual != expected:
    raise SystemExit('APK signature certificate mismatch; actual='+str(actual)+' expected='+expected)
print('Verified APK against pinned permanent certificate: '+expected)
