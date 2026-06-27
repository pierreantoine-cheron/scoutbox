FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter build apk --release --dart-define=SCOUTBOX_CHANNEL=beta
RUN chmod +x apk-release/inject.sh && apk-release/inject.sh

FROM nginx:alpine
COPY --from=build /app/build/app/outputs/apk/release/scoutbox-*-release.apk /usr/share/nginx/html/
COPY --from=build /tmp/apk-download/ /usr/share/nginx/html/
COPY apk-release/register.html /usr/share/nginx/html/register.html
COPY apk-release/nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
