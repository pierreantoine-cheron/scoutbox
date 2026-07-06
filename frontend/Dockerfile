# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:stable AS deps
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY lib/ lib/
COPY android/ android/
RUN dart run build_runner build --delete-conflicting-outputs
COPY . .
RUN chmod +x tool/compute-version.sh tool/build-apk-manifest.sh

FROM deps AS web-builder
RUN flutter build web --release

FROM deps AS apk-builder
ARG APP_FLAVOR=production
ENV APP_FLAVOR=${APP_FLAVOR}
RUN --mount=type=cache,target=/root/.gradle \
    bash -c '. tool/compute-version.sh && \
    flutter build apk --release \
      --flavor ${FLAVOR} \
      --build-name=${VERSION_NAME} \
      --build-number=${VERSION_CODE} && \
    tool/build-apk-manifest.sh \
      "build/app/outputs/flutter-apk" \
      "${VERSION_NAME}" "${VERSION_CODE}" \
      /tmp/artifacts "${SHORT_SHA}"'

FROM nginx:alpine AS web
COPY nginx/web.conf /etc/nginx/conf.d/default.conf
COPY --from=web-builder /app/build/web /usr/share/nginx/html
EXPOSE 80

FROM nginx:alpine AS apk
RUN rm -f /usr/share/nginx/html/index.html
COPY nginx/apk.conf /etc/nginx/conf.d/default.conf
COPY --from=apk-builder /tmp/artifacts/ /usr/share/nginx/html/
EXPOSE 80
