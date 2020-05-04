# ORDER MATTERS FOR CACHING
FROM debian
ADD . /app
RUN apt-get update
RUN apt-get -y install openjdk-8-jdk ssh vim

ADD . /app
CMD ["java", "-jar", "/app/target/app.jar"]


# caching is based on the previous steps, so if something changes
# in the content every command after the copy will be run again


# MORE SPECIFIC COPY TO LIMIT CACHE BUST
FROM debian
RUN apt-get update
RUN apt-get -y install openjdk-8-jdk ssh vim

ADD . /app
ADD target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# coping only the necessarie will be yout image smaller and take
# less time to build, also coping less files reduce the chances of
# invalidate your caching in changings

# USE COPY INSTEAD ADD
FROM debian
RUN apt-get update
RUN apt-get -y install openjdk-8-jdk ssh vim

#ADD target/app.jar /app 
COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# add as more functions that only copy instruction, so if you don't
# want to use this funcions avoid unwanted behaviour and go simple
# use copy

# CONTROL WHAT YOU ARE CACHING
FROM debian
# RUN apt-get update
RUN apt-get update && apt-get -y install \
    openjdk-8-jdk ssh vim mvn

COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# in the previous way the apt is never updated what can cause problems when
# you add a new package to be installed

# REMOVE UNNECESSARY DEPENDENCIES
FROM debian
# RUN apt-get update && apt-get -y install \
#     openjdk-8-jdk ssh vim mvn htop

RUN apt-get update && apt-get -y install openjdk-8-jdk

COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# in this example we don't need ssh and vim cause they are debug tools and
# your image should be immutable and you don't want that someone has remote
# access in your image

# USE --NO-INSTALL-RECCOMMENDS
FROM debian
RUN apt-get update && apt-get -y install --no-install-recommends \
    openjdk-8-jdk

COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# using --no-install-reccommends make sure that unnecessary dependencies wil
# be installed keeping your image small

# REMOVE PACKAGE MANAGER CACHE
FROM debian
RUN apt-get update && apt-get -y install --no-install-recommends \
    openjdk-8-jdk \
    && rm -rf /var/lib/apt/lists/*

COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# after install the dependencies we no longer need the cache of packager manager in
# runtime, so you can remove it and keed your image small

# REUSE OFFICIAL IMAGES WHEN POSSIBLE
#FROM debian
FROM openjdk
# RUN apt-get update && apt-get -y install --no-install-recommends \
#    openjdk-8-jdk \
#    && rm -rf /var/lib/apt/lists/*

COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# reduce time spent on maintenance
# reduce size (shared layers between images)
# pre-configured for container use
# built by smart people
# bonus: scanned for vulnerabilities on Docker Hub

# USE SPECIFIC TAGS
#FROM openjdk
#FROM openjdk:8
#FROM openjdk:8-jre
#FROM openjdk:8-jre-slim
FROM openjdk:8-jre-alpine
COPY target/app.jar /app 
CMD ["java", "-jar", "/app/app.jar"]

# if you don't specify a tag the latest tag will be used
# always check the description in docker hub to choose the
# best tag for you, in this case we could use the openjdk:8
# but the openjdk:8-jre has all we wanted in runtime and is smaller.
# And we can do better and choose the openjdk:8-jre-slim version that
# use headless jre and don't bring UI features that we don't need.
# Better then that we can use the alpine version that is based in Alpine Linux
# witch is very minimal linux - there are some expections in running some
# applications into so always check if it works for your use case

# BUILD FROM SOURCE AS PART OF THE PROCESS - the 'source of truth' is the source code
# not the build artifact
#FROM openjdk:8-jre-alpine
FROM maven:3.6-jdk-8-alpine
#COPY target/app.jar /app 
COPY pom.xml /app/
COPY src /app/src
RUN cd /app && mvn -e -B package
CMD ["java", "-jar", "/app/app.jar"]

# SIMPLIFY WITH WORKDIR
FROM maven:3.6-jdk-8-alpine
WORKDIR /app
#COPY pom.xml /app/
COPY pom.xml .
#COPY src /app/src
COPY src ./src
#RUN cd /app && mvn -e -B package
RUN mvn -e -B package
CMD ["java", "-jar", "/app/app.jar"]

# CACHE DEPENDENCIES
FROM maven:3.6-jdk-8-alpine
WORKDIR /app
COPY pom.xml .
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package
CMD ["java", "-jar", "/app/app.jar"]

# by moving the mvn whe secure the cache will not be invalidated if the src changes

# MULTI-STAGE BUILDS TO REMOVE BUILDS DEPS
# FROM maven:3.6-jdk-8-alpine
FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package
#CMD ["java", "-jar", "/app/app.jar"]

FROM openjdk:8-jre-alpine
COPY --from=builder /app/target/app.jar /
CMD ["java", "-jar", "/app.jar"]

# your final image has to be minimal so we can do a multi-stage builds and secure that
# your runtime will be only the necessary

# MULTI-STAGES USECASES
# Separate build from runtime environment
# Slight variations on images
# DRY (Don't Repeat Yourself)
# Build/dev/test/lint environments
# Concurrent stages
# Platform-specific stages

# DOCKER BUILD --TARGET X
FROM maven:3.6-jdk-8-alpine AS builder
...

FROM openjdk:8-jre-alpine AS release-alpine
COPY --from=builder /app/target/app.jar /
CMD ["java", "-jar", "/app.jar"]

FROM openjdk:8-jre-jessie AS release-jessie
COPY --from=builder /app/target/app.jar /
CMD ["java", "-jar", "/app.jar"]

# you can have multiply targets so you can choose whatever you want to use in each scenario

# GLOBAL ARG: DOCKER BUILD --BUILD-arg K=V
ARG flavor=alpine
FROM maven:3.6-jdk-8-alpine AS builder
...

FROM openjdk:8-jre-$flavor AS release
COPY --from=builder /app/target/app.jar /
CMD ["java", "-jar", "/app.jar"]

# with global arg we reduce some repetitions
# a good practice is to always put some default value

# MULTI-STAGE: BUILD CONCURRENTLY
FROM maven:3.6-jdk-8-alpine AS builder
...

FROM tiborvass/whalesay AS assets
RUN whalesay "!Hola DockerCon!" > /out/assets.html

FROM openjdk:8-jre-$flavor AS release
COPY --from=builder /app/target/app.jar /
COPY --from=assets /out /assets
CMD ["java", "-jar", "/app.jar"]

# generate this assets don't is related with the build process and take some time
# we can do it concurrently with the application build

# DON'T LET SENSIBLE INFO IN DOCKERFILE
FROM baseimage
ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=

# just... don't do that ok?

# DON'T DO THAT EITHER
FROM baseimage
ENV AWS_ACCESS_KEY_ID
ENV AWS_SECRET_ACCESS_KEY

$ docker build --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID

# by passing the value has build environment it will be accessible by all RUN commands
# in all stages
# the best practice is pass some credentials file that can be used only for runtime stage

# LEAST PRIVILEGED USER
FROM openjdk:8-jre-$flavor AS release
RUN mkdir /app
RUN groupadd -r lirantal && useradd -r -s /bin/false -g lirantal lirantal
WORKDIR /app
RUN chown -R lirantal:lirantal /app
COPY --from=builder /app/target/app.jar /
COPY --from=assets /out /assets
USER lirantal
CMD ["java", "-jar", "/app.jar"]

# USE .dockerignore TO PREVENT SENSITIVE FILES TO BE COPIED TO A DOCKER IMAGE

# USE A LINTER

# you can use a linter to avoid commom mistakes and establish best practices
# one good linter is handolint and can be used like this
$ docker run --rm -i hadolint/hadolint < Dockerfile-test
