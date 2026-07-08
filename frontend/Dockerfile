# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:stable AS deps
WORKDIR /app

# ── Android SDK pre-install (cached until base image changes, saves ~2 min) ──
RUN SDKMANAGER=$(which sdkmanager 2>/dev/null || echo "") && \
    if [ -z "$SDKMANAGER" ] && [ -n "${ANDROID_HOME:-}" ]; then \
      SDKMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"; \
    fi && \
    if [ -x "$SDKMANAGER" ]; then \
      yes | "$SDKMANAGER" --licenses > /dev/null 2>&1; \
      "$SDKMANAGER" --install \
        "ndk;28.2.13676358" \
        "platforms;android-35" \
        "build-tools;35.0.0" \
        "cmake;3.22.1"; \
    else \
      echo "sdkmanager not found, skipping pre-install"; \
    fi

# ── Dependencies ──
COPY pubspec.* ./
RUN flutter pub get

# ── Source ──
COPY lib/ lib/
COPY assets/ assets/
COPY analysis_options.yaml build.yaml* l10n.yaml* ./
COPY web/ web/

# ── Code generation ──
RUN dart run build_runner build

# ── Android build files ──
COPY android/ android/
COPY tool/ tool/
RUN chmod +x tool/compute-version.sh tool/build-apk-manifest.sh

# ── Web builder ──
FROM deps AS web-builder
RUN flutter build web --release

# ── APK builder ──
FROM deps AS apk-builder
ARG APP_FLAVOR=production
ENV APP_FLAVOR=${APP_FLAVOR}
RUN bash -c '. tool/compute-version.sh && \
    flutter build apk --release \
      --flavor ${FLAVOR} \
      --build-name=${VERSION_NAME} \
      --build-number=${VERSION_CODE} && \
    APK_DIR="build/app/outputs/flutter-apk" && \
    APK_FILE=$(ls "$APK_DIR"/app-*.apk 2>/dev/null | head -1) && \
    mv "$APK_FILE" "$APK_DIR/scoutbox-v${VERSION_NAME}-${VERSION_CODE}.apk" && \
    tool/build-apk-manifest.sh \
      "$APK_DIR" \
      "${VERSION_NAME}" "${VERSION_CODE}" \
      /tmp/artifacts "${SHORT_SHA}"'

# ── Runtime images ──
FROM nginx:alpine AS web
COPY nginx/web.conf /etc/nginx/conf.d/default.conf
COPY --from=web-builder /app/build/web /usr/share/nginx/html
EXPOSE 80

FROM nginx:alpine AS apk
RUN rm -f /usr/share/nginx/html/index.html
COPY nginx/apk.conf /etc/nginx/conf.d/default.conf
COPY --from=apk-builder /tmp/artifacts/ /usr/share/nginx/html/
EXPOSE 80
