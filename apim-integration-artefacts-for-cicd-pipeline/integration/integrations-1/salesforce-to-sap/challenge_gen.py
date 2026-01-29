import hashlib
import base64
import secrets

# Generate a random code verifier
code_verifier = secrets.token_urlsafe(64)

# Hash the code verifier using SHA-256
code_challenge_bytes = hashlib.sha256(code_verifier.encode()).digest()

# Encode the hashed value using base64 URL encoding
code_challenge = base64.urlsafe_b64encode(code_challenge_bytes).rstrip(b'=').decode()

print("Generated Code Verifier:", code_verifier)
print("Generated Code Challenge:", code_challenge)
