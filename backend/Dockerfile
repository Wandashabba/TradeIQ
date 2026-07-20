# Node 24 to match .github/workflows/backend-ci.yml — a runtime that differs
# from the one CI proves green is a bug waiting to surface in production only.
FROM node:24-slim AS base
# Prisma's query engine links against OpenSSL, which the slim image omits.
RUN apt-get update && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# ---- deps: install once, cached until the lockfile changes -------------------
FROM base AS deps
COPY package.json package-lock.json ./
COPY prisma ./prisma
# `npm ci` triggers the postinstall `prisma generate`, so the schema must be
# copied first. Without it the build fails with "Could not find schema.prisma".
RUN npm ci

# ---- build: compile TypeScript ----------------------------------------------
FROM deps AS build
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# ---- runtime: production deps + compiled output only -------------------------
FROM base AS runtime
ENV NODE_ENV=production

# Reinstalling with --omit=dev drops devDependencies (TypeScript, jest, eslint)
# from the shipped image. It reruns prisma generate, so the client here is
# generated against this exact image's OpenSSL.
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist

# Run as a non-root user. node:24-slim ships an unprivileged `node` user; it
# owns nothing here, which is the point — the app cannot rewrite its own code.
USER node

EXPOSE 4000
CMD ["node", "dist/server.js"]
