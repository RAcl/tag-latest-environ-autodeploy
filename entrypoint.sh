#!/bin/sh
#
# author: racl@gulix.cl
# license: gpl3
#

branchTag() {
    case $2 in
    'develop')
        echo "dev-${1}"
        ;;
    'staging')
        echo "stg-${1}"
        ;;
    'release')
        echo "rc-${1}"
        ;;
    'production')
        echo "ver-${1}"
        ;;
    *)
        echo "${2}-${1}"
    esac
}


toGH () {
    echo "Add '$1' in \$GITHUB_OUTPUT"
    echo $1 >> $GITHUB_OUTPUT
}


response () {
    CI=$1
    CD=$2
    TAG=$3
    LATEST=$4
    ENV=$5
    toGH "TAG=${TAG}"
    toGH "LATEST=${LATEST}"
    toGH "ENVIRON=${ENV}"
    toGH "RUN_CI=${CI}"
    toGH "RUN_CD=${CD}"
}


main () {
    REF=$1
    SHA=$2
    validPush=$3
    BRANCH_NAME="${REF#heads/}"
    TAG_NAME="${REF#tags/}"
    BRANCH='false'
    if [ "${TAG_NAME}" = "${REF}" ]; then
        BRANCH='true'
    fi
    for elem in $validPush; do
        KIND=$(echo "${elem}" | awk -F'/' '{print $1}' | awk -F'-' '{print $1}')
        NAME=$(echo "${elem}" | awk -F'/' '{print $1}' | awk -F'-' '{print $2}')
        ENVR=$(echo "${elem}" | awk -F'/' '{print $2}')
        CD=$(echo "${elem}" | awk -F'/' '{print $3}')
        if [ "$KIND" = "branch" ]; then
            if [ "$BRANCH" = 'true' -a "${BRANCH_NAME}" = "${NAME}" ]; then
            TAG_NAME=$(branchTag "$SHA" "${BRANCH_NAME}")
            [ "$CD" = "auto" ]&&CD="true"||CD="false"
            [ "$ENVR" = "production" ]&&LATEST='latest'||LATEST="latest-${NAME}"
            response "true" "${CD}" "${TAG_NAME}" "${LATEST}" "${ENVR}"
            exit 0
            fi
        elif [ "$KIND" = "tag" ]; then
            ThisTag=$(echo ${TAG_NAME} | egrep ^"${NAME}-[0-9]+\.[0-9]+\.[0-9]+")
            if [ "$BRANCH" = 'false' ] && [ -n "${ThisTag}" ]; then
            [ "$CD" = "auto" ]&&CD="true"||CD="false"
            [ "$ENVR" = "production" ]&&LATEST='latest'||LATEST="latest-${NAME}"
            response "true" "${CD}" "${TAG_NAME}" "${LATEST}" "${ENVR}"
            exit 0
            fi
        else
            echo "Error Branch or Tag ID in: ${elem}"
            response "false" "false" "" "" ""
            exit 1
        fi
    done
    response "false" "false" "" "" ""
    echo "This Puch was not expected"
    exit 1
}


REF="${1#refs/}"
SHA=$(echo $2 | cut -c 1-7)
[ -n "$valid_push" ]&&validPush=$valid_push||validPush=$3

main "$REF" "$SHA" "$validPush"
