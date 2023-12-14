FROM golang:1.21-alpine as builder

# install zip in container
RUN apk update
RUN apk add zip

WORKDIR /usr/src
COPY go.mod go.sum main.go ./
RUN CGO_ENABLED=0 go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o main
RUN zip -r lambda.zip main
FROM localstack/localstack
# Copy lambdas.zip into the localstack directory
COPY --from=builder /usr/src/lambda.zip  ./lambda.zip