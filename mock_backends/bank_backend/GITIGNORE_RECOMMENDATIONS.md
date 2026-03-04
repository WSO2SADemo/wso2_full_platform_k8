# .gitignore Recommendations

## Security: Protect Your Certificates and Credentials

Add these entries to your `.gitignore` file to prevent committing sensitive files:

```gitignore
# SSL Certificates and Keystores
resources/*.jks
resources/*.p12
resources/*.pem
resources/*.crt
resources/*.key
resources/*.pfx
truststore.jks
keystore.jks
*.jks
*.p12

# Temporary certificate files
*.pem
*.crt
*.cer

# Configuration files with credentials
Config.toml
*-config.toml
.env
.env.local
.env.*.local

# Ballerina build artifacts
target/
build/

# IDE files
.idea/
.vscode/
*.iml
.DS_Store

# Logs
*.log
logs/

# Backup files
*.bak
*~
```

## Why This Matters

### 🔒 Security Risks of Committing Certificates

1. **Exposed Private Keys**: Anyone with repository access can decrypt your communications
2. **Certificate Theft**: Attackers can impersonate your services
3. **Credential Leakage**: OAuth secrets and passwords become public
4. **Compliance Violations**: Many regulations prohibit storing certificates in version control

### ✅ Best Practices

1. **Never commit certificates** - Use `.gitignore` to prevent accidents
2. **Use environment variables** - Store sensitive data outside code
3. **Document setup process** - Provide clear instructions (like our guides)
4. **Use different certificates per environment** - Dev, staging, and production should have separate certificates
5. **Rotate regularly** - Update certificates before expiry

## Alternative: Environment-Based Configuration

Instead of hardcoding paths and passwords, use environment variables:

### Update `connections.bal`

```ballerina
import ballerina/ai;
import ballerina/os;

// Get configuration from environment variables
string truststorePath = os:getEnv("TRUSTSTORE_PATH") != "" ? 
    os:getEnv("TRUSTSTORE_PATH") : "./resources/truststore.jks";
string truststorePassword = os:getEnv("TRUSTSTORE_PASSWORD") != "" ? 
    os:getEnv("TRUSTSTORE_PASSWORD") : "ballerina";

final ai:Wso2ModelProvider bankAgentModel = check ai:getDefaultModelProvider();
final ai:Wso2ModelProvider aiWso2modelprovider = check ai:getDefaultModelProvider();
final AiBankCustomerMcpToolkit aiBankCustomerMcp = check new (
    "https://localhost:8245/bankCustomerMCP/1.0.0", 
    auth = {
        tokenUrl: "https://localhost:9444/oauth2/token",
        clientId: os:getEnv("OAUTH_CLIENT_ID"),
        clientSecret: os:getEnv("OAUTH_CLIENT_SECRET")
    }, 
    validation = false, 
    laxDataBinding = false, 
    secureSocket = {
        cert: {
            path: truststorePath,
            password: truststorePassword
        }
    }
);
```

### Set Environment Variables

**Linux/Mac:**
```bash
export TRUSTSTORE_PATH="./resources/truststore.jks"
export TRUSTSTORE_PASSWORD="ballerina"
export OAUTH_CLIENT_ID="FtKsoWz0cw88j3E5c0vhLMS1Y8sa"
export OAUTH_CLIENT_SECRET="Ofum4SUGt8gTRmxEHREfCo8FCW0V5F1dISUcfTtTCtUa"

bal run
```

**Windows (PowerShell):**
```powershell
$env:TRUSTSTORE_PATH="./resources/truststore.jks"
$env:TRUSTSTORE_PASSWORD="ballerina"
$env:OAUTH_CLIENT_ID="FtKsoWz0cw88j3E5c0vhLMS1Y8sa"
$env:OAUTH_CLIENT_SECRET="Ofum4SUGt8gTRmxEHREfCo8FCW0V5F1dISUcfTtTCtUa"

bal run
```

### Create `.env` File (Don't Commit!)

Create a `.env` file in your project root:

```bash
# .env (add this to .gitignore!)
TRUSTSTORE_PATH=./resources/truststore.jks
TRUSTSTORE_PASSWORD=ballerina
OAUTH_CLIENT_ID=FtKsoWz0cw88j3E5c0vhLMS1Y8sa
OAUTH_CLIENT_SECRET=Ofum4SUGt8gTRmxEHREfCo8FCW0V5F1dISUcfTtTCtUa
```

Then load it before running:
```bash
# Linux/Mac
export $(cat .env | xargs) && bal run

# Or use a tool like direnv
```

## Sample `.env.template` File

Create this file to document required environment variables (safe to commit):

```bash
# .env.template
# Copy this file to .env and fill in your values
# DO NOT commit .env file!

# SSL Configuration
TRUSTSTORE_PATH=./resources/truststore.jks
TRUSTSTORE_PASSWORD=your_truststore_password_here

# OAuth Configuration
OAUTH_CLIENT_ID=your_client_id_here
OAUTH_CLIENT_SECRET=your_client_secret_here

# WSO2 Endpoints
TOKEN_ENDPOINT=https://localhost:9444/oauth2/token
MCP_ENDPOINT=https://localhost:8245/bankCustomerMCP/1.0.0
```

## Checking for Exposed Secrets

### Before Committing

```bash
# Check what files will be committed
git status

# Verify .gitignore is working
git check-ignore resources/truststore.jks
# Should output: resources/truststore.jks

# Search for potential secrets in staged files
git diff --cached | grep -i "password\|secret\|key"
```

### If You Accidentally Committed Secrets

```bash
# Remove file from Git history (use with caution!)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch resources/truststore.jks" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (only if you're sure!)
git push origin --force --all

# Rotate the compromised credentials immediately!
```

## Security Checklist

Before committing code:

- [ ] `.gitignore` includes certificate patterns
- [ ] No `.jks`, `.p12`, or `.pem` files in staging area
- [ ] No hardcoded passwords or secrets in code
- [ ] Environment variables documented in `.env.template`
- [ ] Actual `.env` file is in `.gitignore`
- [ ] OAuth credentials not hardcoded
- [ ] Certificate paths use environment variables
- [ ] README includes setup instructions
- [ ] No sensitive data in commit history

## Recommended Repository Structure

```
bank_backend/
├── .gitignore                          ← Include certificate patterns
├── .env.template                       ← Safe to commit (no real values)
├── .env                                ← In .gitignore (real values)
│
├── resources/                          ← Entire directory in .gitignore
│   └── truststore.jks                  ← Never committed
│
├── docs/                               ← Documentation (safe to commit)
│   ├── SSL_SETUP_GUIDE.md
│   ├── QUICK_START.md
│   └── ...
│
├── main.bal                            ← Code (safe to commit)
├── connections.bal                     ← Use env vars for secrets
├── types.bal
└── ...
```

## Additional Security Tools

### 1. Git Secrets Scanner

```bash
# Install git-secrets
brew install git-secrets  # macOS
# or
sudo apt-get install git-secrets  # Linux

# Initialize in your repo
git secrets --install
git secrets --register-aws

# Add custom patterns
git secrets --add 'password\s*=\s*["\'][^"\']+["\']'
git secrets --add 'secret\s*=\s*["\'][^"\']+["\']'
```

### 2. Pre-commit Hooks

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

# Check for certificate files
if git diff --cached --name-only | grep -E '\.(jks|p12|pem|key)$'; then
    echo "Error: Attempting to commit certificate files!"
    echo "Please remove them from staging area."
    exit 1
fi

# Check for hardcoded secrets
if git diff --cached | grep -iE 'password\s*=\s*["\'][^"\']+["\']'; then
    echo "Warning: Possible hardcoded password detected!"
    echo "Please use environment variables instead."
    exit 1
fi

exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Summary

✅ **Add to `.gitignore`**: All certificate files and keystores  
✅ **Use environment variables**: For passwords and secrets  
✅ **Document setup**: Provide `.env.template` for team members  
✅ **Scan before commit**: Check for exposed secrets  
✅ **Rotate if exposed**: Immediately change compromised credentials  

**Remember: Once committed to Git, secrets are very hard to fully remove!**
