# SSL Certificate Debug Summary

## What Was Added

I've added comprehensive debugging to help identify the root cause of your SSL certificate issue.

## Changes Made

### 1. Enhanced `connections.bal` with Debug Logging

The file now includes:

- **Truststore file validation** - Checks if the file exists, is readable, and has content
- **Detailed error messages** - Shows specific SSL error types and causes
- **Troubleshooting steps** - Provides actionable commands to fix issues
- **Certificate chain detection** - Identifies if you need to import full chains
- **Initialization logging** - Shows exactly when and why the connection fails

### 2. What You'll See When Running `bal run`

```
=== SSL TRUSTSTORE DEBUG INFO ===
1. Checking truststore path: ./resources/truststore.jks
   ✓ Truststore file found
   - Absolute path: /full/path/to/resources/truststore.jks
   - File size: 2048 bytes
   - Readable: true
   - Writable: true

2. SSL Configuration:
   - Token URL: https://localhost:9444/oauth2/token
   - MCP URL: https://localhost:8245/bankCustomerMCP/1.0.0
   - Truststore password: wso2carbon

3. Expected certificates in truststore:
   - Certificate for localhost:9444 (Token Server)
   - Certificate for localhost:8245 (MCP Server)

4. To verify truststore contents, run:
   keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon

...

=== INITIALIZING MCP CLIENT ===
Attempting to connect to MCP server...
❌ MCP CLIENT INITIALIZATION FAILED!
Error: Failed to initialize MCP toolkit
Cause: Failed to send the request to the endpoint...

🔍 SSL CERTIFICATE VALIDATION FAILED
This means the truststore doesn't contain the correct certificate.

Possible reasons:
1. Certificate not imported into truststore
2. Wrong certificate imported (from different server/port)
3. Certificate expired
4. Intermediate certificates missing
5. Certificate alias mismatch

📋 TROUBLESHOOTING STEPS:

Step 1: Verify truststore contents
Run: keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon

Step 2: Check what certificate the server is presenting
Run: openssl s_client -connect localhost:9444 -showcerts
Run: openssl s_client -connect localhost:8245 -showcerts

Step 3: Export the FULL certificate chain
Run: openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > token-chain.pem
Run: openssl s_client -connect localhost:8245 -showcerts < /dev/null 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > mcp-chain.pem

Step 4: Delete and recreate truststore
Run: rm ./resources/truststore.jks
Run: keytool -import -noprompt -alias wso2-token -file token-chain.pem -keystore ./resources/truststore.jks -storepass wso2carbon
Run: keytool -import -noprompt -alias wso2-mcp -file mcp-chain.pem -keystore ./resources/truststore.jks -storepass wso2carbon

Step 5: Alternative - Use WSO2's default truststore
If you have WSO2 installed, copy its truststore:
cp <WSO2_HOME>/repository/resources/security/client-truststore.jks ./resources/truststore.jks
```

## Most Likely Causes

Based on the error "PKIX path building failed", here are the most common causes:

### 1. **Incomplete Certificate Chain** (Most Common)

**Problem:** You only imported the server certificate, but not the intermediate CA certificates.

**How to check:**
```bash
# See how many certificates the server presents
openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | grep -c "BEGIN CERTIFICATE"
```

If this shows more than 1, you have a certificate chain.

**Solution:**
```bash
# Export the FULL chain (all certificates)
openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > token-full-chain.pem

openssl s_client -connect localhost:8245 -showcerts < /dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > mcp-full-chain.pem

# Delete old truststore
rm ./resources/truststore.jks

# Import the full chains
keytool -import -noprompt -alias wso2-token \
  -file token-full-chain.pem \
  -keystore ./resources/truststore.jks \
  -storepass wso2carbon

keytool -import -noprompt -alias wso2-mcp \
  -file mcp-full-chain.pem \
  -keystore ./resources/truststore.jks \
  -storepass wso2carbon
```

### 2. **Wrong Certificate Imported**

**Problem:** You exported the certificate from a different server or port.

**How to check:**
```bash
# Get fingerprint from server
openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
  openssl x509 -noout -fingerprint -sha256

# Get fingerprint from truststore
keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon | \
  grep "SHA256:"
```

**These should match!**

**Solution:** Re-export from the correct server:port

### 3. **Certificate Expired**

**How to check:**
```bash
openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
  openssl x509 -noout -dates
```

**Solution:** Regenerate WSO2 certificates or use a valid certificate

### 4. **Using WSO2's Self-Signed Certificate**

**Problem:** WSO2 uses self-signed certificates by default, and you need to trust the CA.

**Best Solution:** Use WSO2's pre-configured truststore:
```bash
# Find WSO2's truststore
find /opt -name "client-truststore.jks" 2>/dev/null
# or
find ~ -name "client-truststore.jks" 2>/dev/null

# Copy it to your project
cp <WSO2_HOME>/repository/resources/security/client-truststore.jks ./resources/truststore.jks
```

This truststore already contains all the necessary certificates and CAs.

## Diagnostic Tools Provided

### 1. **Automatic Debug Output** (Already in code)
- Run `bal run` to see detailed diagnostic information
- Shows file checks, configuration, and specific error causes

### 2. **Certificate Checker Script** (See `CERTIFICATE_CHECKER.md`)
- Comprehensive diagnostic script
- Checks truststore, server connectivity, certificate validity
- Compares server certificates with truststore contents
- Provides specific fix commands

### 3. **Diagnostic Guide** (See `SSL_DIAGNOSTIC_GUIDE.md`)
- Step-by-step troubleshooting process
- Common issues and solutions
- Advanced debugging techniques

## Quick Fix Steps

### Step 1: Run Your Application
```bash
bal run
```

Read the debug output carefully. It will tell you exactly what's wrong.

### Step 2: Verify Truststore Contents
```bash
keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon
```

Look for:
- Number of entries (should be at least 2)
- Certificate validity dates
- Certificate subjects (should include localhost)

### Step 3: Check Server Certificates
```bash
# Token server
openssl s_client -connect localhost:9444 -showcerts 2>/dev/null | \
  openssl x509 -text -noout | head -20

# MCP server
openssl s_client -connect localhost:8245 -showcerts 2>/dev/null | \
  openssl x509 -text -noout | head -20
```

### Step 4: Compare Fingerprints
```bash
# Server fingerprint
openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
  openssl x509 -noout -fingerprint -sha256

# Truststore fingerprint
keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon | \
  grep "SHA256:" | head -1
```

If they don't match, you have the wrong certificate!

### Step 5: Import Full Certificate Chain
```bash
# This is the most reliable method
rm ./resources/truststore.jks

openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > token-chain.pem

openssl s_client -connect localhost:8245 -showcerts < /dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > mcp-chain.pem

keytool -import -noprompt -alias wso2-token \
  -file token-chain.pem \
  -keystore ./resources/truststore.jks \
  -storepass wso2carbon

keytool -import -noprompt -alias wso2-mcp \
  -file mcp-chain.pem \
  -keystore ./resources/truststore.jks \
  -storepass wso2carbon

# Verify
keytool -list -keystore ./resources/truststore.jks -storepass wso2carbon

# Test
bal run
```

## Alternative Solutions

### Option 1: Use WSO2's Default Truststore (Recommended)

```bash
# Find WSO2 installation
WSO2_HOME="/path/to/wso2"  # Update this path

# Copy truststore
cp $WSO2_HOME/repository/resources/security/client-truststore.jks \
   ./resources/truststore.jks

# Run
bal run
```

### Option 2: Disable SSL Validation (Development Only)

Edit `connections.bal`:
```ballerina
secureSocket = {
    enable: false
}
```

**⚠️ WARNING:** Only use this for development/testing!

## What to Share for Further Help

If you still have issues after trying the above, share:

1. **Debug output from `bal run`** (the full output)
2. **Truststore contents:**
   ```bash
   keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon
   ```
3. **Server certificate info:**
   ```bash
   openssl s_client -connect localhost:9444 -showcerts 2>/dev/null | \
     openssl x509 -text -noout
   ```
4. **Certificate chain length:**
   ```bash
   openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
     grep -c "BEGIN CERTIFICATE"
   ```
5. **Fingerprint comparison:**
   ```bash
   # Server
   openssl s_client -connect localhost:9444 -showcerts < /dev/null 2>/dev/null | \
     openssl x509 -noout -fingerprint -sha256
   
   # Truststore
   keytool -list -v -keystore ./resources/truststore.jks -storepass wso2carbon | \
     grep "SHA256:"
   ```

## Summary

✅ **Added comprehensive debugging** to `connections.bal`  
✅ **Created diagnostic guides** with step-by-step instructions  
✅ **Provided certificate checker script** for automated diagnosis  
✅ **Identified most likely causes** of your specific error  
✅ **Provided multiple solutions** including quick fixes  

**Next step:** Run `bal run` and carefully read the debug output. It will guide you to the exact problem and solution.
