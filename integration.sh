#!/bin/bash

#set -ex
#set -o pipefail

# Simple tests using the awscli

BUCKET=${BUCKET:-aws-s3-test}
PREFIX=${PREFIX:-aws-s3-test/}

#REDIRECT_BUCKET=aws-s3-test-eu
TEMP=/tmp/test_data.bin

LARGE_FILE=/tmp/rnd_big.bin
FILE=/tmp/rnd.bin
dd if=/dev/urandom of=$LARGE_FILE ibs=1k count=17k
dd if=$LARGE_FILE  of=$FILE       ibs=1k count=129

FIRST_PART=1000
LAST_PART=68000
PART=/tmp/part.bin
dd if=${LARGE_FILE} of=${PART} ibs=1 skip=$(( FIRST_PART )) count=$(( LAST_PART - FIRST_PART + 1))

TEST=0
function test {
    TEST=$(( TEST + 1))
    echo -n "$TEST. $1: "
    shift
    $@
    if [ $? -eq 0 ]; then
        echo "ok"
    else
        echo "fail"
        echo "Command: $@"
        exit 1
    fi
}

function cleanup {
    rm -f ${TEMP}
    rm -f ${PART}
    rm -f ${FILE}
}

#trap cleanup EXIT
function test_simple () {
    BIN=$1;shift
    RETRIES=$1;shift
    HTTPS=$1;shift

    echo "TEST SIMPLE $(basename $BIN) HTTPS=${HTTPS}"
    test "upload" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "head" ${BIN} head --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $FILE ${TEMP}
}

function test_complete () {
    BIN=$1;shift
    RETRIES=$1;shift
    HTTPS=$1;shift

    echo "TEST $(basename $BIN) https:${HTTPS}"

    #test "redirect upload expect" ${BIN} cp -e --retries=${RETRIES} $FILE s3://${REDIRECT_BUCKET}/${PREFIX}test
    #test "redirect head" ${BIN} head --retries=${RETRIES} s3://${REDIRECT_BUCKET}/${PREFIX}test
    #test "redirect download" ${BIN} cp --retries=${RETRIES} s3://${REDIRECT_BUCKET}/${PREFIX}test ${TEMP}
    #test "redirect data" diff -u $FILE ${TEMP}

    test "upload expect" ${BIN} cp -e --https=${HTTPS} --retries=${RETRIES} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "head" ${BIN} head --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $FILE ${TEMP}

    test "download stream" ${BIN} cp -c 8209 --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "data" diff -u $FILE ${TEMP}

    test "upload chunked expect" ${BIN} cp -e -c 8209 --https=${HTTPS} --retries=${RETRIES} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "download stream" ${BIN} cp -c 8209 --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "data" diff -u $FILE ${TEMP}

    test "multi_upload" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "multi_upload chunked" ${BIN} cp -c 8209 --https=${HTTPS} --retries=${RETRIES} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "multi_upload chunked expect" ${BIN} cp -e -c 8209 --https=${HTTPS} --retries=${RETRIES} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "partial download" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test" --first=$FIRST_PART --last=$LAST_PART ${TEMP}
    test "partial data" diff -u ${PART} ${TEMP}

    test "partial download stream" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} --first=$FIRST_PART --last=$LAST_PART "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "partial data" diff -u ${PART} ${TEMP}

    test "rm" ${BIN} rm --https=${HTTPS} --retries=${RETRIES} ${BUCKET} "${PREFIX}test"
    test "upload" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} $FILE "s3://${BUCKET}/${PREFIX}test1"
    test "s3 cp" ${BIN} cp --https=${HTTPS} --retries=${RETRIES} "s3://${BUCKET}/${PREFIX}test1" "s3://${BUCKET}/${PREFIX}test2"
    test "ls" ${BIN} ls --max-keys=1 --https=${HTTPS} --retries=${RETRIES} ${BUCKET} --prefix="$PREFIX"
    test "multi rm" ${BIN} rm --https=${HTTPS} --retries=${RETRIES} ${BUCKET} "${PREFIX}test1" "${PREFIX}test2"
}

# Test complete functionality for both lwt and async
for b in async lwt; do
    BIN=_build/install/default/bin/aws-cli-$b
    dune build $BIN || exit
    test_simple $BIN 0 true
    test_simple $BIN 0 false
    test_complete $BIN 0 true
    test_complete $BIN 0 false
done
