# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
ARG PUBLIC_APK_MANIFEST_URL
ARG PUBLIC_WEB_APP_URL
ENV PUBLIC_APK_MANIFEST_URL=${PUBLIC_APK_MANIFEST_URL}
ENV PUBLIC_WEB_APP_URL=${PUBLIC_WEB_APP_URL}
RUN npm run build

FROM nginx:alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
