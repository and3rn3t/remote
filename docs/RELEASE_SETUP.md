# Release Automation Setup

This document explains how to configure GitHub secrets for automated TestFlight releases.

## Required Secrets

Configure these secrets in your GitHub repository settings (`Settings` → `Secrets and variables` → `Actions`):

### 1. Apple Distribution Certificate

**`BUILD_CERTIFICATE_BASE64`**
- Your Apple Distribution certificate in base64 format
- Generate:
  ```bash
  # Export certificate from Keychain as .p12
  # Then encode it:
  base64 -i Certificates.p12 -o certificate.txt
  # Copy contents of certificate.txt to GitHub secret
  ```

**`P12_PASSWORD`**
- Password for the .p12 certificate file
- Set when exporting from Keychain

### 2. Provisioning Profile

**`PROVISIONING_PROFILE_BASE64`**
- Your App Store provisioning profile in base64 format
- Generate:
  ```bash
  # Download .mobileprovision from Apple Developer portal
  base64 -i YourProfile.mobileprovision -o profile.txt
  # Copy contents of profile.txt to GitHub secret
  ```

**`PROVISIONING_PROFILE_NAME`**
- The name of your provisioning profile (visible in Apple Developer portal)
- Example: `remote App Store`

### 3. App Store Connect API

**`APP_STORE_CONNECT_API_KEY_ID`**
- API Key ID from App Store Connect
- Get from: [App Store Connect](https://appstoreconnect.apple.com/access/api) → Keys → Your Key → Key ID

**`APP_STORE_CONNECT_ISSUER_ID`**
- Issuer ID for your team
- Get from: [App Store Connect](https://appstoreconnect.apple.com/access/api) → Keys → (top of page)

**`APP_STORE_CONNECT_API_KEY_BASE64`**
- Your .p8 API key file in base64 format
- Generate:
  ```bash
  # Download AuthKey_XXXXXXXXXX.p8 from App Store Connect
  base64 -i AuthKey_XXXXXXXXXX.p8 -o apikey.txt
  # Copy contents of apikey.txt to GitHub secret
  ```

### 4. Team and Keychain

**`TEAM_ID`**
- Your Apple Developer Team ID
- Find in: Apple Developer portal → Membership → Team ID
- Example: `AB1234CDEF`

**`KEYCHAIN_PASSWORD`**
- A secure password for the temporary keychain (can be any strong password)
- Example: Generate with `openssl rand -base64 32`

## Step-by-Step Setup

### 1. Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/access/api)
2. Click the **+** button to create a new key
3. Name it (e.g., "GitHub Actions CI")
4. Set access to **Admin** or **App Manager**
5. Download the `.p8` file (you can only download it once!)
6. Note the **Key ID** and **Issuer ID**

### 2. Export Apple Distribution Certificate

1. Open **Keychain Access** on your Mac
2. Find your **Apple Distribution** certificate
3. Right-click → **Export "Apple Distribution: Your Name (Team ID)"**
4. Save as `.p12` format
5. Set a strong password (you'll use this as `P12_PASSWORD`)

### 3. Download Provisioning Profile

1. Go to [Apple Developer](https://developer.apple.com/account/resources/profiles/list)
2. Find your **App Store** provisioning profile for `dev.andernet.remote`
3. Download the `.mobileprovision` file
4. Note the profile name (visible in the list)

### 4. Encode Secrets to Base64

```bash
# Certificate
base64 -i Certificates.p12 -o certificate_base64.txt

# Provisioning Profile
base64 -i YourProfile.mobileprovision -o profile_base64.txt

# API Key
base64 -i AuthKey_XXXXXXXXXX.p8 -o apikey_base64.txt
```

### 5. Add Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret from the list above

### 6. Test the Workflow

Create and push a version tag:

```bash
# Ensure your code is committed
git add .
git commit -m "Release version 1.0.0"

# Create and push tag
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will:
1. Build the app
2. Archive for App Store distribution
3. Export the IPA
4. Upload to TestFlight
5. Create a GitHub release with the IPA attached

## Troubleshooting

### Code Signing Issues

**Error: "No signing certificate"**
- Verify `BUILD_CERTIFICATE_BASE64` is correctly encoded
- Check that `P12_PASSWORD` is correct
- Ensure the certificate is an **Apple Distribution** certificate (not Development)

**Error: "No matching provisioning profile"**
- Verify `PROVISIONING_PROFILE_BASE64` is correctly encoded
- Check that `PROVISIONING_PROFILE_NAME` exactly matches the profile name in Apple Developer portal
- Ensure the profile is an **App Store** profile (not Ad Hoc or Development)
- Verify the profile includes the correct bundle ID (`dev.andernet.remote`)

### Upload Issues

**Error: "Invalid credentials"**
- Verify `APP_STORE_CONNECT_API_KEY_ID` is correct (format: `ABC123DEFG`)
- Check that `APP_STORE_CONNECT_ISSUER_ID` is correct (UUID format)
- Ensure `APP_STORE_CONNECT_API_KEY_BASE64` is correctly encoded

**Error: "App record not found"**
- Verify you've created the app in App Store Connect first
- Check that the bundle ID matches (`dev.andernet.remote`)

### Build Issues

**Error: "Build failed"**
- Check that the tag version matches the version in Xcode project
- Verify all tests pass (`git push` triggers CI, which must pass first)

## Security Best Practices

1. **Never commit secrets to git** — Always use GitHub Secrets
2. **Rotate API keys regularly** — Create new keys every 6-12 months
3. **Use least-privilege access** — API keys should have minimum required permissions
4. **Review workflow logs** — Ensure no secrets are printed (GitHub auto-redacts, but verify)
5. **Protect the main branch** — Require PR reviews and status checks before merge

## Manual Release (Fallback)

If automated release fails, you can release manually:

1. Open project in Xcode
2. Select **Product** → **Archive**
3. In Organizer, click **Distribute App**
4. Choose **App Store Connect**
5. Upload and wait for processing
6. TestFlight will send notification when ready

## Resources

- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Xcode Cloud vs GitHub Actions](https://developer.apple.com/xcode-cloud/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
