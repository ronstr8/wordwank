# Build stage
FROM node:20-alpine AS build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Declared late so a new commit doesn't invalidate the npm install layer.
ARG GIT_SHA=dev
RUN npm run build

# Production stage
FROM nginx:stable-alpine AS production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY brand-hosts.conf /etc/nginx/brand-hosts.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
