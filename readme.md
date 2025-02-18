# PassShelter

PassShelter – a protective place for personal and professional secrets.

A lightweight Docker-based "vault" container for managing secrets via GnuPG and pass.

## Key Features

- Master Passphrase is the only thing that must be remembered.
- Passwords and other secrets are stored in `pass` store, protected by your GPG key.
- The GPG key is protected by the master passphrase.
- All key material (`~/.gnupg`) and password-store data (`~/.password-store`) are backed up using GPG with AES-256 encryption.
  - The encrypted backup can be safely stored in a cloud drive or other remote location.
- The backup password is derivable from the passphrase using Argon2 KDF with a unique salt.
- Security operations minimize master passphrase input, reducing exposure to keyloggers.
- Built-in support for Two-Factor Authentication (TOTP) code generation.

## 0. Prerequisites

- Ubuntu OS is used on the host
- Access to sudo/root for permission management
- Docker installed and running

## 1. Initial Setup

### 1.1. Clone the Repository

```bash
git clone https://github.com/vaivanov95/pass-shelter.git
cd pass-shelter
```

### 1.2. Define a Storage Location

Create a persistent storage location for GPG keys and passwords:

```bash
export AUTH_PATH="${HOME}/pass-shelter/auth"
mkdir -p "${AUTH_PATH}/.gnupg"
mkdir -p "${AUTH_PATH}/.password-store"

# GnuPG requires strict permissions
chmod 700 "${AUTH_PATH}/.gnupg"
```

### 1.3. Configure Service User

The container runs with a configurable service user to avoid UID/GID conflicts:

```bash
# Check for existing users with these IDs first
export SERVICE_USER_UID=$(id -u)
export SERVICE_USER_GID=$(id -g)

# Override if needed:
# export SERVICE_USER_UID=$(id -u)
# export SERVICE_USER_GID=$(id -g)

sudo chown -R ${SERVICE_USER_UID}:${SERVICE_USER_GID} ${AUTH_PATH}
```

## 2. Build and Run

Build the Docker image:

```bash
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) -t pass-shelter .
```

Run the container:

```bash
docker run --rm -it \
    -v ${AUTH_PATH}/.gnupg:/home/user/.gnupg \
    -v ${AUTH_PATH}/.password-store:/home/user/.password-store \
    --name pass-shelter \
    pass-shelter \
    bash
```

## 3. GPG Key Management

### 3.1. Generate or Import GPG Key

Generate a new key:

```bash
gpg --full-generate-key
```

Or import existing key:

```bash
gpg --import /path/to/key.asc
```

### 3.2. Initialize Password Store

```bash
gpg --list-keys
pass init <GPG_KEY_ID_OR_EMAIL>
```

Multiple GPG keys can be used by specifying them in `.password-store/.gpg-id`.

### 3.3. Key Rotation

To rotate your GPG key:

1. Generate new key
2. Re-encrypt store: `pass init <NEW_KEY_ID> <OLD_KEY_ID>`
3. Create backup
4. Revoke old key: `gpg --gen-revoke <OLD_KEY_ID>`

## 4. Password and TOTP Management

Store passwords:

```bash
pass insert example.com/login
pass show example.com/login
```

For TOTP setup:

1. Store TOTP secret using the format: `service-name/totp/secret`
   ```bash
   pass insert github.com/totp/secret
   # Enter the Base32 secret (e.g., JBSWY3DPEHPK3PXP)
   ```

2. Generate codes:
   ```bash
   otp github.com/totp
   ```

## 5. Backup and Restore

### 5.1. Backup Configuration
Generate backup password (if not yet stored):

```bash
export BACKUP_PASSWORD=$(docker run -it pass-shelter derive_password "PASS_SHELTER_BACKUP_PASSWORD")
```

Store the password to a local file
```bash
echo $BACKUP_PASSWORD > ~/.backup_password
```

After the password is stored, read to an environment variable with:
```bash
export BACKUP_PASSWORD=$(< ~/.backup_password)
```

### 5.2. Create Backup

```bash
export BACKUP_PATH="${HOME}/pass-shelter/backup"
mkdir -p "$BACKUP_PATH"

docker run -it --rm \
  -e "BACKUP_PASSWORD=${BACKUP_PASSWORD}" \
  -v ${AUTH_PATH}/.gnupg:/home/user/.gnupg \
  -v ${AUTH_PATH}/.password-store:/home/user/.password-store \
  -v ${BACKUP_PATH}:/backup \
  pass-shelter \
  backup_secrets
```

The backup script uses GPG with AES-256 encryption.

### 5.3. Restore from Backup

```bash
docker run -it --rm \
  -e "BACKUP_PASSWORD=${BACKUP_PASSWORD}" \
  -v ${AUTH_PATH}/.gnupg:/home/user/.gnupg \
  -v ${AUTH_PATH}/.password-store:/home/user/.password-store \
  -v ${BACKUP_PATH}:/backup \
  pass-shelter \
  restore_secrets
```

### 5.4. Backup Verification

Regularly verify backups:

1. Create a test directory
2. Attempt restore to test location
3. Verify contents match current store
4. Run integrity check: `pass git check`




## 6. Automation
### 6.1 .bashrc entries
Using an example path `/mnt/s/auth/`,
```bash
export AUTH_PATH=/mnt/s/auth/
alias psh='docker run --rm -it     -v ${AUTH_PATH}/.gnupg:/home/user/.gnupg     -v ${AUTH_PATH}/.password-store:/home/u>
```
