#!/bin/bash

set -eu

# Set a default JAVA_TOOL_OPTIONS if it hasn't already been specified
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx8192m}"
DISABLE_CHECKSTYLE=${DISABLE_CHECKSTYLE:-false}

if [[ $(git rev-parse --is-shallow-repository) == "true" ]]
then
    git fetch --unshallow
fi

if [ -z ${GITHUB_RUN_NUMBER+x} ]; then
    if [[ "$DISABLE_CHECKSTYLE" == "true" ]]; then
        mvn package
    else
        mvn -Plibrary verify
    fi
else
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

        BUILD_NUM=${GITHUB_RUN_NUMBER}
        if ! [[ -z "${BUILD_NUM_OFFSET:-}" ]]
        then
            BUILD_NUM=$((GITHUB_RUN_NUMBER+BUILD_NUM_OFFSET))
        fi

        version+=+$BUILD_NUM

        export TRAVIS_BUILD_NUMBER=${BUILD_NUM}

    fi

    echo "======================================"
    echo "Building version ${version}"
    echo "======================================"

    mvn -B versions:set -DnewVersion="${version}"
    
    if [[ "$DISABLE_CHECKSTYLE" == "true" ]]; then
        mvn -B package
    else
        mvn -B -Plibrary verify
    fi
fi
