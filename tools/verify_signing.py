"""Compare a built APK to the pinned PUBLIC certificate digest."""
import pathlib, subprocess, sys, re
apk, verifier = sys.argv[1:]
result = subprocess.run([verifier,'verify','--print-certs',apk],capture_output=True,text=True,check=True)
output = result.stdout + '\n' + result.stderr
match = re.search(r'Signer\s*#\s*1\s+certificate\s+SHA-256\s+digest:\s*([0-9a-fA-F:]+)',output,re.IGNORECASE)
expected = pathlib.Path('android-signing.sha256').read_text().strip().lower()
actual = match.group(1).replace(':','').lower() if match else None
if actual != expected:
    details=' | '.join(output.splitlines()[-8:])
    raise SystemExit('APK signature certificate mismatch; actual='+str(actual)+' expected='+expected+' apksigner='+details)
print('Verified APK against pinned permanent certificate: '+expected)
