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
        rsync && \
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

# Put the Android SDK Tools on the PATH
ENV PATH=${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

# Stop sdkmanager from complaining
RUN mkdir ~/.android && touch ~/.android/repositories.cfg

# Define the download URL and SHA-256 checksum of the Android SDK Tools;
# both can be found at https://developer.android.com/studio/index.html#command-tools
ARG ANDROID_SDK_URL=https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip
ARG ANDROID_SDK_CHECKSUM=444e22ce8ca0f67353bda4b85175ed3731cae3ffa695ca18119cbacef1c1bea0

# Download the Android SDK Tools, verify the checksum, extract to ANDROID_HOME, then
# remove everything but sdkmanager and its dependencies to keep the layer size small
RUN curl --silent --show-error --fail --retry 1 --output /tmp/sdk.zip --location ${ANDROID_SDK_URL} && \
    echo "${ANDROID_SDK_CHECKSUM}  /tmp/sdk.zip" > /tmp/checksum && \
    sha256sum -c /tmp/checksum > /dev/null && \
    unzip -q /tmp/sdk.zip -d ${ANDROID_HOME} && \
    jars=$(grep CLASSPATH ${ANDROID_HOME}/tools/bin/sdkmanager \
      | egrep -i -o '([^/:]+\.jar)' | paste -s -d\| -) && \
    find ${ANDROID_HOME}/tools -type f -regextype posix-egrep \
      -not -name sdkmanager -not -regex ".*($jars)" -print0 \
        | xargs -0 rm && \
    rm /tmp/checksum /tmp/sdk.zip

# Accept all SDK licences, update the Android SDK Tools to the latest, and install the basics
RUN sdkmanager --verbose --update && \
    yes | sdkmanager --licenses && \
    sdkmanager --verbose \
      tools \
      platform-tools \
      emulator

# Install the desired platform version and Build Tools
RUN sdkmanager --verbose --update && \
    sdkmanager --verbose --install \
    'platforms;android-27' \
    'build-tools;26.0.2'
