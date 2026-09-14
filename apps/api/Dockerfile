FROM node:20-alpine
WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --ignore-scripts

COPY prisma-shim/default.js ./node_modules/.prisma/client/default.js

COPY . .

EXPOSE 3000

CMD ["sh", "-c", "npx tsx src/scripts/migrate.ts && npx tsx src/index.ts"]
