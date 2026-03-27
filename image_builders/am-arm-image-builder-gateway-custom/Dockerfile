# ------------------------------------------------------------------------
#
# Copyright 2025 WSO2, LLC. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
#
# ------------------------------------------------------------------------

FROM docker.wso2.com/wso2am-universal-gw:latest

ARG WSO2_SERVER_NAME=wso2am-universal-gw
ARG WSO2_SERVER_VERSION=4.6.0
ARG USER_HOME=/home/wso2carbon
ARG WSO2_SERVER_HOME=${USER_HOME}/${WSO2_SERVER_NAME}-${WSO2_SERVER_VERSION}

USER root

# Replace tracing plugin JAR
COPY org.wso2.carbon.apimgt.tracing_9.32.147.jar \
    ${WSO2_SERVER_HOME}/repository/components/plugins/org.wso2.carbon.apimgt.tracing_9.32.147.jar

# Replace opentelemetry JAR (remove old version, copy new version)
RUN rm -f ${WSO2_SERVER_HOME}/repository/components/plugins/opentelemetry-all_1.11.0.wso2v6.jar
COPY opentelemetry-all_1.57.0.wso2v2.jar \
    ${WSO2_SERVER_HOME}/repository/components/plugins/opentelemetry-all_1.57.0.wso2v2.jar

# Update bundles.info to reference the new opentelemetry-all version
RUN sed -i 's|^opentelemetry-all,.*|opentelemetry-all,1.57.0.wso2v2,../plugins/opentelemetry-all_1.57.0.wso2v2.jar,4,true|' \
    ${WSO2_SERVER_HOME}/repository/components/default/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info

# Fix ownership
RUN chown wso2carbon:wso2 \
    ${WSO2_SERVER_HOME}/repository/components/plugins/org.wso2.carbon.apimgt.tracing_9.32.147.jar \
    ${WSO2_SERVER_HOME}/repository/components/plugins/opentelemetry-all_1.57.0.wso2v2.jar \
    ${WSO2_SERVER_HOME}/repository/components/default/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info

USER 10001
