#!/bin/sh
# Railway startup script: applies DB schema and seeds on first run, then starts API.
set -e

echo "🚀 DoctorBooking API starting..."
echo "   NODE_ENV: $NODE_ENV"
echo "   PORT: $PORT"

# Run schema migration (idempotent — uses IF NOT EXISTS throughout)
echo "📦 Applying database schema..."
node dist/scripts/migrate.js

echo "✅ Schema ready. Starting API..."
exec node dist/index.js
