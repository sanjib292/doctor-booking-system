FROM node:20-alpine
WORKDIR /app

# Install dependencies (build context is repo root, so prefix with apps/api/)
COPY apps/api/package.json apps/api/yarn.lock ./
RUN yarn install --frozen-lockfile --ignore-scripts

# Copy API source
COPY apps/api/ .

# Expose port (Railway injects $PORT)
EXPOSE 3000

# Run schema migration then start API via tsx (no compile step needed)
CMD ["sh", "-c", "npx tsx src/scripts/migrate.ts && npx tsx src/index.ts"]
