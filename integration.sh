#!/bin/bash

#set -ex
#set -o pipefail

BUCKET=aws-s3-bucket
PREFIX=aws-s3-test/
MINIO=127.0.0.1:9000
#REDIRECT_BUCKET=aws-s3-test-eu

while [ -n "$1" ]; do
    case "$1" in
        "-b"|"--bucket")   BUCKET=$2; shift;;
        "-p"|"--prefix")   PREFIX=$2; shift;;
        "-m"|"--minio")    MINIO=$2; shift;;
        "-t"|"--type")     TYPES="$TYPES $2"; shift;;
        "-r"|"--redirect") REDIRECT_BUCKET=$2; shift;;
        *)
            echo "Unknown option: $1"
            exit 1
    esac
    shift
done

TEMP=/tmp/test_data.bin

LARGE_FILE=/tmp/rnd_big.bin
FILE=/tmp/rnd.bin
dd if=/dev/urandom of=$LARGE_FILE ibs=1k count=17k > /dev/null 2>&1
dd if=$LARGE_FILE  of=$FILE       ibs=1k count=129 > /dev/null 2>&1

FIRST_PART=1000
LAST_PART=68000
PART=/tmp/part.bin
dd if=${LARGE_FILE} of=${PART} ibs=1 skip=$(( FIRST_PART )) count=$(( LAST_PART - FIRST_PART + 1)) > /dev/null 2>&1

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

    OPTIONS="--minio=${MINIO} --https=${HTTPS} --retries=${RETRIES}"

    echo "TEST SIMPLE aws-s3-$TYPE ${OPTIONS}"
    test "upload" ${BIN} cp ${OPTIONS} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "head" ${BIN} head ${OPTIONS} "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $FILE ${TEMP}
}

function test_complete () {
    BIN=$1;shift
    RETRIES=$1;shift
    HTTPS=$1;shift

    OPTIONS="--minio=${MINIO} --https=${HTTPS} --retries=${RETRIES}"

    echo "TEST aws-s3-$TYPE ${OPTIONS}"

    #test "redirect upload expect" ${BIN} cp -e --retries=${RETRIES} $FILE s3://${REDIRECT_BUCKET}/${PREFIX}test
    #test "redirect head" ${BIN} head --retries=${RETRIES} s3://${REDIRECT_BUCKET}/${PREFIX}test
    #test "redirect download" ${BIN} cp --retries=${RETRIES} s3://${REDIRECT_BUCKET}/${PREFIX}test ${TEMP}
    #test "redirect data" diff -u $FILE ${TEMP}

    test "upload expect" ${BIN} cp -e ${OPTIONS} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "head" ${BIN} head ${OPTIONS} "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $FILE ${TEMP}

    test "download stream" ${BIN} cp -c 8209 ${OPTIONS} "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "data" diff -u $FILE ${TEMP}

    test "upload chunked expect" ${BIN} cp -e -c 8209 ${OPTIONS} $FILE "s3://${BUCKET}/${PREFIX}test"
    test "download stream" ${BIN} cp -c 8209 ${OPTIONS} "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "data" diff -u $FILE ${TEMP}

    test "multi_upload" ${BIN} cp ${OPTIONS} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "multi_upload chunked" ${BIN} cp -c 8209 ${OPTIONS} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "multi_upload chunked expect" ${BIN} cp -e -c 8209 ${OPTIONS} -m $LARGE_FILE "s3://${BUCKET}/${PREFIX}test"
    test "download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" ${TEMP}
    test "data" diff -u $LARGE_FILE ${TEMP}

    test "partial download" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test" --first=$FIRST_PART --last=$LAST_PART ${TEMP}
    test "partial data" diff -u ${PART} ${TEMP}

    test "partial download stream" ${BIN} cp ${OPTIONS} --first=$FIRST_PART --last=$LAST_PART "s3://${BUCKET}/${PREFIX}test ${TEMP}"
    test "partial data" diff -u ${PART} ${TEMP}

    test "rm" ${BIN} rm ${OPTIONS} ${BUCKET} "${PREFIX}test"
    test "upload" ${BIN} cp ${OPTIONS} $FILE "s3://${BUCKET}/${PREFIX}test1"
    test "s3 cp" ${BIN} cp ${OPTIONS} "s3://${BUCKET}/${PREFIX}test1" "s3://${BUCKET}/${PREFIX}test2"
    test "ls" ${BIN} ls --max-keys=1 ${OPTIONS} ${BUCKET} --prefix="$PREFIX"
    test "multi rm" ${BIN} rm ${OPTIONS} ${BUCKET} "${PREFIX}test1" "${PREFIX}test2"
}

for TYPE in ${TYPES:-lwt}; do
    opam exec -- dune build aws-s3-${TYPE}/bin/aws_cli_${TYPE}.exe
    BIN=_build/default/aws-s3-${TYPE}/bin/aws_cli_${TYPE}.exe

    if [ -z "${MINIO}" ]; then
        test_simple "$BIN" 0 true
    fi
    test_simple "$BIN" 0 false

    if [ -z "${MINIO}" ]; then
        test_complete "$BIN" 0 true
    fi
    test_complete "$BIN" 0 false
done
