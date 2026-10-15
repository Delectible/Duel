# The referee for Cloud Run. Build from the repo root (it needs the shared
# engine in packages/duel_engine):
#   docker build -f server/Dockerfile .
FROM dart:stable AS build
WORKDIR /src
COPY packages/duel_engine/ packages/duel_engine/
COPY server/pubspec.yaml server/pubspec.lock server/
WORKDIR /src/server
RUN dart pub get
COPY server/bin/ bin/
COPY server/lib/ lib/
RUN dart pub get --offline && dart compile exe bin/server.dart -o /referee

# Just the compiled server and the bits of Linux it needs.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /referee /referee
EXPOSE 8080
CMD ["/referee"]
