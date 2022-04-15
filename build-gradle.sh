#!/bin/bash

set -eu

# Set a default JAVA_TOOL_OPTIONS if it hasn't already been specified
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx4096m}"

GRADLE_PARAMS=${GRADLE_PARAMS:-}
GRADLE_CACHE_USERNAME=${GRADLE_CACHE_USERNAME:-}
GRADLE_CACHE_PASSWORD=${GRADLE_CACHE_PASSWORD:-}
DISABLE_BUILD_SCAN=${DISABLE_BUILD_SCAN:-false}

if [[ $(git rev-parse --is-shallow-repository) == "true" ]]
then
    git fetch --unshallow
fi

if [[ -z "$GRADLE_CACHE_USERNAME" || -z "$GRADLE_CACHE_PASSWORD" ]]; then
    echo "============================================================"
    echo "Set GRADLE_CACHE_USERNAME and GRADLE_CACHE_PASSWORD"
    echo "environment variables to take advantage of the build cache!"
    echo "============================================================"
fi

if [ -z ${GITHUB_RUN_NUMBER+x} ]; then
  if [[ "$DISABLE_BUILD_SCAN" == "true" ]]; then
      ./gradlew $GRADLE_PARAMS
   else
      ./gradlew $GRADLE_PARAMS --scan
   fi
else

    BUILD_NUM=${GITHUB_RUN_NUMBER}
    if ! [[ -z "${BUILD_NUM_OFFSET:-}" ]]
    then
        BUILD_NUM=$((GITHUB_RUN_NUMBER+BUILD_NUM_OFFSET))
    fi

    export TRAVIS_BUILD_NUMBER=${BUILD_NUM}

    version=""
    snapshot=true
    echo "GITHUB_ACTIONS_TAG ${GITHUB_ACTIONS_TAG}"
    echo "GITHUB_ACTIONS_PULL_REQUEST ${GITHUB_ACTIONS_PULL_REQUEST}"
    if [[ ! -z "$GITHUB_ACTIONS_PULL_REQUEST" ]]; then
        version="PR$GITHUB_ACTIONS_PULL_REQUEST"

    elif [[ "$GITHUB_ACTIONS_TAG" =~ ^v[0-9]+\. ]]; then
        version=${GITHUB_ACTIONS_TAG/v/}
        snapshot=false

    else
        COMMIT_COUNT=$(git rev-list --count HEAD)
        COMMIT_SHA=$(git rev-parse --short=6 HEAD)

        version=$(git describe --tags --match "v[0-9]*" --abbrev=6 HEAD || echo v0-$COMMIT_COUNT-g$COMMIT_SHA)
        version=${version/v/}

        version+=+$BUILD_NUM
    fi

    echo "======================================"
    echo "Building version ${version}"
    echo "======================================"

    if [[ "$DISABLE_BUILD_SCAN" == "true" ]]; then
        ./gradlew $GRADLE_PARAMS -Prelease="${version}" -Psnapshot="${snapshot}"
     else
        ./gradlew $GRADLE_PARAMS -Prelease="${version}" -Psnapshot="${snapshot}" --scan
     fi
fi
