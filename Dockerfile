ARG SWIFT_VERSION="6.0.3"
FROM swift:${SWIFT_VERSION}
WORKDIR /app
COPY ./Package.* ./
RUN swift package resolve
COPY . .
RUN swift build
CMD ["swift", "test"]
