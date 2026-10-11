FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY . .

ARG MAZEDUNEH_API_BASE_URL
ARG MAZEDUNEH_ADMIN_STORE_ID=default
RUN test -n "$MAZEDUNEH_API_BASE_URL"
RUN flutter config --enable-web \
  && flutter pub get \
  && flutter build web --release --target lib/secure_main.dart \
    --dart-define=MAZEDUNEH_API_BASE_URL=$MAZEDUNEH_API_BASE_URL \
    --dart-define=MAZEDUNEH_ADMIN_STORE_ID=$MAZEDUNEH_ADMIN_STORE_ID

FROM nginx:alpine AS runner
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
