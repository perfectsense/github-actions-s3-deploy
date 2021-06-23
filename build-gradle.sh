#!/bin/bash

set -e

# Set a default JAVA_TOOL_OPTIONS if it hasn't already been specified in .travis.yml
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx4096m}"

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

if [ -z "$GITHUB_RUN_NUMBER" ]; then
  if [[ "$DISABLE_BUILD_SCAN" == "true" ]]; then
      ./gradlew $GRADLE_PARAMS
   else
      ./gradlew $GRADLE_PARAMS --scan
   fi
else
    version=""
    echo "GITHUB_ACTIONS_TAG ${GITHUB_ACTIONS_TAG}"
    if [[ -z "$GITHUB_ACTIONS_PULL_REQUEST" && "$GITHUB_ACTIONS_PULL_REQUEST" != "" ]]; then
        echo "GITHUB_ACTIONS_PULL_REQUEST ${GITHUB_ACTIONS_PULL_REQUEST}"
        version="PR$GITHUB_ACTIONS_PULL_REQUEST"

    elif [[ "$GITHUB_ACTIONS_TAG" =~ ^v[0-9]+\. ]]; then
        echo "GITHUB_ACTIONS_TAG ${GITHUB_ACTIONS_TAG}"
        version=${GITHUB_ACTIONS_TAG/v/}

    else
        COMMIT_COUNT=$(git rev-list --count HEAD)
        COMMIT_SHA=$(git rev-parse --short=6 HEAD)

        version=$(git describe --tags --match "v[0-9]*" --abbrev=6 HEAD || echo v0-$COMMIT_COUNT-g$COMMIT_SHA)
        version=${version/v/}

        BUILD_NUM=${GITHUB_RUN_NUMBER}
        if ! [[ -z "${BUILD_NUM_OFFSET}" ]]
        then
            BUILD_NUM=$((GITHUB_RUN_NUMBER+BUILD_NUM_OFFSET))
        fi

        version+=+$BUILD_NUM

        export TRAVIS_BUILD_NUMBER=${BUILD_NUM}

    fi

    echo "======================================"
    echo "Building version ${version}"
    echo "======================================"

    if [[ "$DISABLE_BUILD_SCAN" == "true" ]]; then
        ./gradlew $GRADLE_PARAMS -Prelease="${version}"
     else
        ./gradlew $GRADLE_PARAMS -Prelease="${version}" --scan
     fi
fi
