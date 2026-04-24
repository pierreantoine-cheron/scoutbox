FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY . .

RUN flutter pub get
RUN flutter build web --release --dart-define=SCOUTBOX_CHANNEL=beta

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
