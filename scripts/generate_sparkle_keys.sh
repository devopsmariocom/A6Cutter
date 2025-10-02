#!/bin/bash

# Generate Sparkle keys for auto-updater
# This script generates the private and public keys needed for Sparkle

echo "🔑 Generating Sparkle keys for A6Cutter..."

# Create keys directory if it doesn't exist
mkdir -p keys

# Generate private key
echo "Generating private key..."
./bin/ed25519_sign_util generate keys/ed25519_private_key.pem

# Generate public key
echo "Generating public key..."
./bin/ed25519_sign_util public-key keys/ed25519_private_key.pem > keys/ed25519_public_key.pem

# Extract the public key content (remove header/footer)
PUBLIC_KEY=$(grep -v "BEGIN\|END" keys/ed25519_public_key.pem | tr -d '\n')
echo "Public key: $PUBLIC_KEY"

# Update Info.plist with the public key
if [ -f "A6Cutter/Info.plist" ]; then
    echo "Updating Info.plist with public key..."
    plutil -replace SUPublicEDSAKey -string "$PUBLIC_KEY" A6Cutter/Info.plist
    echo "✅ Info.plist updated with public key"
else
    echo "❌ Info.plist not found"
fi

echo "🔑 Sparkle keys generated successfully!"
echo "📁 Private key: keys/ed25519_private_key.pem"
echo "📁 Public key: keys/ed25519_public_key.pem"
echo "⚠️  Keep the private key secure and never commit it to version control!"
