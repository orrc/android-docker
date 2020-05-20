FROM openjdk:8-jdk-slim

# Install required packages:
# - curl:            to download the Android SDK Tools
# - git:             fetching sources occurs inside the container
# - libgl1-mesa-glx: for Android emulator
# - libpulse0:       for Android emulator
# - openssh-client:  for Git-related operations
# - procps:          for `ps`, required by Jenkins Docker Pipeline Plugin
# - rsync:           to help sync Gradle caches
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --no-install-recommends \
        curl \
        git \
        libgl1-mesa-glx \
        libpulse0 \
        openssh-client \
        procps \
        rsync \
        unzip && \
    rm -rf /var/lib/apt/lists/*

# Create an android user/group, with Jenkins-compatible UID
RUN groupadd --gid 1000 android && \
    useradd --uid 1000 --gid 1000 --create-home android

# Export ANDROID_HOME, so that other tools can find the SDK
ENV ANDROID_HOME /opt/android/sdk

# Create the ANDROID_HOME directory for the android user
RUN mkdir -p ${ANDROID_HOME} && \
    chown -R android:android ${ANDROID_HOME}

# Switch to the android user
USER android
ENV HOME /home/android

# Enable Java options for Docker
ENV JAVA_TOOL_OPTIONS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap

# Put the Android SDK Tools on the PATH
ENV PATH=${ANDROID_HOME}/tools:${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

# Stop sdkmanager from complaining
RUN mkdir ~/.android && touch ~/.android/repositories.cfg

# Define the download URL and SHA-256 checksum of the Android SDK Tools;
# both can be found at https://developer.android.com/studio/index.html#command-tools
ARG ANDROID_SDK_URL=https://dl.google.com/android/repository/commandlinetools-linux-6200805_latest.zip
ARG ANDROID_SDK_CHECKSUM=f10f9d5bca53cc27e2d210be2cbc7c0f1ee906ad9b868748d74d62e10f2c8275

# Download the Android SDK Tools, verify the checksum, extract to ANDROID_HOME, then
# remove everything but sdkmanager and its dependencies to keep the layer size small
RUN curl --silent --show-error --fail --retry 1 --output /tmp/sdk.zip --location ${ANDROID_SDK_URL} && \
    echo "${ANDROID_SDK_CHECKSUM}  /tmp/sdk.zip" > /tmp/checksum && \
    sha256sum -c /tmp/checksum > /dev/null && \
    unzip -q /tmp/sdk.zip -d ${ANDROID_HOME}/cmdline-tools && \
    rm /tmp/checksum /tmp/sdk.zip

# Accept all SDK licences
RUN sdkmanager --verbose --update && \
    yes | sdkmanager --licenses

# Update the Android SDK Tools to the latest, and install the basics
RUN sdkmanager --verbose \
      tools \
      platform-tools \
      emulator

# Install the desired platform version and Build Tools
RUN sdkmanager --verbose --update && \
    sdkmanager --verbose --install \
    'platforms;android-29' \
    'build-tools;29.0.3'
