# Build from the repository root (the image needs templates/ for the seed script):
#   docker build -f apps/api/Dockerfile -t surprise-api .
#
# The repo layout is kept inside the image (/app/apps/api, /app/templates) so the scripts'
# relative paths work unchanged.

FROM node:26-bookworm-slim AS base
# Prisma's engines need OpenSSL; slim images do not ship it.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app/apps/api

FROM base AS build
COPY apps/api/package.json apps/api/package-lock.json ./
RUN npm ci
COPY apps/api/ ./
# The Prisma client is generated code and must exist before TypeScript compiles. Generated again
# after pruning dev dependencies so the client in the final node_modules is guaranteed present.
RUN npx prisma generate \
  && npx nest build \
  && npm prune --omit=dev \
  && npx prisma generate

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=build --chown=node:node /app/apps/api/node_modules ./node_modules
COPY --from=build --chown=node:node /app/apps/api/dist ./dist
COPY --from=build --chown=node:node /app/apps/api/prisma ./prisma
COPY --from=build --chown=node:node /app/apps/api/scripts ./scripts
COPY --from=build --chown=node:node /app/apps/api/package.json ./package.json
COPY --chown=node:node templates /app/templates

USER node
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4000)+'/api/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# One-off tasks use the same image with a different command, e.g.:
#   npx prisma migrate deploy        (release step, before starting new versions)
#   npm run templates:seed
#   npm run maintenance              (scheduled)
CMD ["node", "dist/main.js"]
