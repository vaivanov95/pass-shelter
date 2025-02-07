# PassShelter Manual Testing Guide

This document provides step-by-step instructions to manually verify the core functionalities of PassShelter.

## Prerequisites
1. **Ubuntu/Debian-based host system** (or WSL2 on Windows)
2. **Docker installed** and running (`sudo systemctl status docker`)
3. **Git installed**: `sudo apt install git -y`
4. Terminal access with `bash` or `zsh`

---

## 1. Setup Test Environment

### 1.1 Clone Repository
```bash
git clone https://github.com/vaivanov95/pass-shelter.git
cd pass-shelter
```

### 1.2 Create Test Directories
```bash
export TEST_AUTH_DIR="/tmp/pass-shelter-test/auth"
export TEST_BACKUP_DIR="/tmp/pass-shelter-test/backup"

mkdir -p "$TEST_AUTH_DIR/.gnupg"
mkdir -p "$TEST_AUTH_DIR/.password-store"
mkdir -p "$TEST_BACKUP_DIR"

chmod 700 "$TEST_AUTH_DIR/.gnupg"
```

### 1.3 Build Docker Image
```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t pass-shelter-test .
```

---

## 2. GPG Key & Password Store Tests

### 2.1 Generate Test GPG Key
```bash
docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  gpg --batch --pinentry-mode loopback --passphrase "testpass" --quick-generate-key "Test User <test@example.com>" default default 0
```

**Verification:**
```bash
docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  pass-shelter-test \
  gpg --list-secret-keys
```
→ Should show "Test User <test@example.com>"

---

### 2.2 Initialize Password Store
```bash
export KEY_ID=$(docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  pass-shelter-test \
  gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5}' | head -n1)

docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  pass init "$KEY_ID"
```

**Verification:**
```bash
ls -la "$TEST_AUTH_DIR/.password-store/.gpg-id"
```
→ File should contain the GPG key ID

---

## 3. Password Management Tests

### 3.1 Insert and Retrieve Password
```bash
echo -e "test_password123\ntest_password123" | \
docker run -i --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  pass insert --force example.com/login
```

**Retrieve Password:**
```bash
docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  pass show example.com/login
```
It will require a passphrase, provide "testpass"
→ Should display "test_password123"

---

## 4. TOTP Functionality Test

### 4.1 Store TOTP Secret
```bash
echo -e "JBSWY3DPEHPK3PXP\nJBSWY3DPEHPK3PXP" | \
docker run -i --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  pass insert --force service/totp/secret
```

### 4.2 Generate TOTP Code
```bash
docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  otp service/totp
```
→ Should output a 6-digit numeric code

---

## 5. Backup & Restore Tests

### 5.1 Derive Backup Password
```bash
export BACKUP_PASSWORD=$(echo "testpass" | docker run -i --rm pass-shelter-test derive_password "PASS_SHELTER_BACKUP_PASSWORD"  | tr -d '\n')
echo "Backup Password: $BACKUP_PASSWORD"
```
→ Should output a 64-character hex string

### 5.2 Create Backup
```bash
docker run -it --rm \
  -e "BACKUP_PASSWORD=$BACKUP_PASSWORD" \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  -v "$TEST_BACKUP_DIR:/backup" \
  pass-shelter-test \
  backup_secrets
```

**Verification:**
```bash
ls -l "$TEST_BACKUP_DIR"
```
→ Should show a `secrets.gpg` file

---

### 5.3 Restore Backup
1. **Delete existing data:**
```bash
rm -rf "$TEST_AUTH_DIR/.gnupg"/*
rm -rf "$TEST_AUTH_DIR/.password-store"/*
```

2. **Restore:**
```bash
docker run -it --rm \
  -e "BACKUP_PASSWORD=$BACKUP_PASSWORD" \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  -v "$TEST_BACKUP_DIR:/backup" \
  pass-shelter-test \
  restore_secrets
```

3. **Verify Restoration:**
```bash
docker run -it --rm \
  -v "$TEST_AUTH_DIR/.gnupg:/home/user/.gnupg" \
  -v "$TEST_AUTH_DIR/.password-store:/home/user/.password-store" \
  pass-shelter-test \
  pass show example.com/login
```
→ Should display original password "test_password123"

---

## 6. Cleanup
```bash
rm -rf /tmp/pass-shelter-test
docker rm pass-shelter-test
docker rmi pass-shelter-test
```

---

## Expected Results
- All commands should execute without errors
- Password store persists between container runs
- Backup/restore maintains data integrity
- TOTP codes validate successfully in 2FA apps

**Note:** Use dummy credentials for testing. Never use real secrets in test environments.
