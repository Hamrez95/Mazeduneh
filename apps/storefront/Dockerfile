FROM node:22-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_MAZEDUNEH_API_URL
ARG NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false
ARG NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL
ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_MAZEDUNEH_API_URL=${NEXT_PUBLIC_MAZEDUNEH_API_URL}
ENV NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=${NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE}
ENV NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL=${NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL}
ENV NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
ENV MAZEDUNEH_DOCKER_STANDALONE=true

RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=8080
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 8080
CMD ["node", "server.js"]
