FROM node:20-alpine
WORKDIR /app

# Install dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --ignore-scripts

# Copy full source
COPY . .

# Expose port (Railway injects $PORT)
EXPOSE 3000

# Run schema migration then start API via tsx (no compile step needed)
CMD ["sh", "-c", "npx tsx src/scripts/migrate.ts && npx tsx src/index.ts"]
