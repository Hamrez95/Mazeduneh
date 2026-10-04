FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY . .

ARG MAZEDUNEH_API_BASE_URL
RUN test -n "$MAZEDUNEH_API_BASE_URL"
RUN flutter config --enable-web \
  && flutter pub get \
  && flutter build web --release --target lib/main.dart \
    --dart-define=MAZEDUNEH_API_BASE_URL=$MAZEDUNEH_API_BASE_URL

FROM nginx:alpine AS runner
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
