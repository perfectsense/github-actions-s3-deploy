# Git Hub Actions S3 Deploy Script

This script is used by [Git Hub Actions](https://github.com/features/actions) to continuously deploy artifacts to an S3 bucket.

When Git Hub Actions builds a push to your project (not a pull request), any files matching `build/*.{war,jar,zip}` will be uploaded to your S3 bucket with the prefix `builds/$DEPLOY_BUCKET_PREFIX/deploy/$BRANCH/$BUILD_NUMBER/`. Pull requests will upload the same files with a prefix of `builds/$DEPLOY_BUCKET_PREFIX/pull-request/$PULL_REQUEST_NUMBER/`.

For example, the 36th push to the `main` branch will result in the following files being created in your `exampleco-ops` bucket:

```
builds/exampleco/deploy/master/36/exampleco-1.0-SNAPSHOT.war
builds/exampleco/deploy/master/36/exampleco-1.0-SNAPSHOT.zip
```

When the 15th pull request is created, the following files will be uploaded into your bucket:
```
builds/exampleco/pull-request/15/exampleco-1.0-SNAPSHOT.war
builds/exampleco/pull-request/15/exampleco-1.0-SNAPSHOT.zip
```

## Usage

Your .github/workflows/gradle.yml should look something like this:

```
# This workflow will build a Java project with Gradle
# For more information see: https://help.github.com/actions/language-and-framework-guides/building-and-testing-java-with-gradle

name: Java CI with Gradle

on:
  push:
    branches: 
      - develop
      - release/*
    tags: v*

  pull_request:
    branches: 
      - develop
      - release/*

env:
  AWS_EC2_METADATA_DISABLED: true
  GITHUB_ACTIONS_PULL_REQUEST: ${{ github.event.pull_request.number }}
  DEPLOY_SOURCE_DIR: site/build/libs

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - name: Set up JDK 8
      uses: actions/setup-java@v2
      with:
        java-version: '8'
        distribution: 'adopt'
    - name: Get Tag Version
      run: echo "GITHUB_ACTIONS_TAG=${GITHUB_REF#refs/*/}" >> $GITHUB_ENV
    - name: Grant execute permission for gradlew
      run: chmod +x gradlew
    - name: Clone Github Actions S3 Deploy
      run: git clone https://github.com/perfectsense/github-actions-s3-deploy.git
    - name: Build with Gradle
      run: ./github-actions-s3-deploy/build-gradle.sh
    - name: Deploy to S3
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        AWS_SESSION_TOKEN: ${{ secrets.AWS_SESSION_TOKEN }}
        DEPLOY_BUCKET: ${{ secrets.DEPLOY_BUCKET }}
      run: ./github-actions-s3-deploy/deploy.sh

```

Note that any of the above environment variables can be set in Git Hub Actions Secrets, and do not need to be included in your gradle.yml. `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` should always be set to your S3 bucket credentials as Git Hub Actions Secrets, not this file.

## Setting the initial build number.
If you're moving from another build system, you might want to start from some specific number. Add an additional env var `BUILD_NUM_OFFSET` and set it to your inital offset. Ex: `BUILD_NUM_OFFSET: 100`
