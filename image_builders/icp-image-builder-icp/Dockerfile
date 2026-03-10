# Copyright (c) 2026, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ── Stage 1: Frontend build ───────────────────────────────────────────────────
# Use official Node 22 Alpine image (Vite 7 requires Node 20.19+ or 22.12+).
# Kept separate from the Ballerina builder to avoid Node/OpenSSL compatibility
# issues that arise when mixing Alpine edge packages with older Alpine base images.
FROM node:22-alpine AS frontend-builder

RUN npm install -g pnpm@latest

WORKDIR /app/frontend

COPY frontend/ .

# --no-frozen-lockfile: pnpm-lock.yaml was generated on macOS arm64 and does not
# include linux/x64 native optional packages (e.g. @rollup/rollup-linux-x64-gnu).
RUN pnpm install --no-frozen-lockfile && pnpm build

# ── Stage 2: Backend + packaging build ───────────────────────────────────────
# Ballerina image provides: Ballerina runtime + Java (required for Gradle + icp_server)
FROM ballerina/ballerina:2201.13.1 AS builder

USER root

RUN apk add --no-cache wget unzip zip bash

WORKDIR /app

# Copy Gradle wrapper and build files first for better layer caching
COPY gradlew ./
COPY gradlew.bat ./
COPY gradle/ ./gradle/
COPY build.gradle ./
COPY settings.gradle ./
COPY gradle.properties ./
RUN chmod +x ./gradlew

# Copy source directories
COPY icp_server/ ./icp_server/
COPY www/ ./www/
COPY conf/ ./conf/
COPY distribution/ ./distribution/

# Copy the pre-built frontend dist from stage 1 into the expected location
# so Gradle's buildFrontend task output is already satisfied
COPY frontend/ ./frontend/
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Build Ballerina backend + package distribution, skipping the frontend build
# since frontend/dist is already present from stage 1
RUN ./gradlew clean build -x buildFrontend

# ── Stage 3: Runtime ──────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk

# ICP_VERSION must match project.version in gradle.properties (2.0.0-SNAPSHOT)
ARG ICP_VERSION=2.0.0-SNAPSHOT

RUN apt-get update && \
    apt-get install -y --no-install-recommends unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/wso2

COPY --from=builder /app/build/distribution/wso2-integrator-icp-${ICP_VERSION}.zip ./

RUN unzip wso2-integrator-icp-${ICP_VERSION}.zip && \
    rm wso2-integrator-icp-${ICP_VERSION}.zip

WORKDIR /home/wso2/wso2-integrator-icp-${ICP_VERSION}

# Ports: 9445 Web/Auth, 9446 GraphQL, 9448 Observability, 9449 OpenSearch
EXPOSE 9445 9446 9448 9449

RUN chmod +x bin/icp.sh

ENTRYPOINT ["bin/icp.sh"]
