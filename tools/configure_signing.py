"""Configure permanent Android signing; never silently switch release identities."""
import base64, hashlib, json, os, pathlib, re, subprocess


def configure(root, bundle, expected):
    gradle = root / 'android/app/build.gradle.kts'
    source = gradle.read_text()
    previous = 'signingConfig = signingConfigs.getByName("debug")'
    if source.count(previous) != 1:
        raise RuntimeError('Unexpected Android template signing configuration')
    if not bundle:
        # CI can validate compilation without a secret. This APK is NOT published.
        gradle.write_text(source.replace(previous, 'signingConfig = null'))
        return False
    data = json.loads(bundle)
    for key in ('keystore', 'storePassword', 'keyPassword', 'alias'):
        if not isinstance(data.get(key), str) or not data[key]:
            raise ValueError('Invalid signing bundle structure')
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', data['alias']):
        raise ValueError('Invalid key alias')
    private = pathlib.Path(os.environ.get('RUNNER_TEMP', str(root.parent))) / 'junior-signing'
    private.mkdir(mode=0o700, exist_ok=True)
    keystore = private / 'release.p12'
    keystore.write_bytes(base64.b64decode(data['keystore'], validate=True))
    keystore.chmod(0o600)
    env = dict(os.environ, JUNIOR_SIGN_STORE_PASS=data['storePassword'])
    certificate = subprocess.run(['keytool','-exportcert','-keystore',str(keystore),'-storetype','PKCS12',
        '-storepass:env','JUNIOR_SIGN_STORE_PASS','-alias',data['alias']],env=env,capture_output=True,check=True).stdout
    if hashlib.sha256(certificate).hexdigest().lower() != expected.strip().lower():
        raise ValueError('Signing certificate mismatch; release blocked')
    # All values are passed as Kotlin string literals with escaping; no shell expansion.
    def literal(value):
        return json.dumps(value).replace('$', r'\$')
    config = '\n    signingConfigs {\n        create("permanentRelease") {\n' + '\n'.join([
        '            storeFile = file(' + literal(str(keystore)) + ')',
        '            storePassword = ' + literal(data['storePassword']),
        '            keyAlias = ' + literal(data['alias']),
        '            keyPassword = ' + literal(data['keyPassword']),
    ]) + '\n        }\n    }\n'
    source = source.replace('android {', 'android {' + config, 1)
    source = source.replace(previous, 'signingConfig = signingConfigs.getByName("permanentRelease")')
    gradle.write_text(source)
    gradle.chmod(0o600)
    return True


if __name__ == '__main__':
    root = pathlib.Path.cwd()
    try:
        ready = configure(root, os.environ.get('ANDROID_SIGNING_BUNDLE', ''), (root/'android-signing.sha256').read_text())
    except Exception:
        # Do not let errors from subprocess or JSON parsing expose secret values.
        raise SystemExit('Signing configuration failed. Check bundle and pinned certificate. No APK will be released.') from None
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write('ready=' + str(ready).lower() + '\n')
    print('Permanent signing configured.' if ready else 'Signing secret missing: compile-only unsigned APK; publication disabled.')
