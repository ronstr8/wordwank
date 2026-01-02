FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o gatewayd main.go

FROM alpine:latest
WORKDIR /app
COPY --from=build /app/gatewayd .
EXPOSE 8081
CMD ["./gatewayd"]
