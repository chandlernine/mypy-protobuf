#!/bin/bash -ex

PY_VERSION=`python -c 'import sys; print(sys.version.split()[0])'`
VENV=venv_$PY_VERSION
MYPY_VENV=venv_mypy

RED="\033[0;31m"
NC='\033[0m'

(
    # Create virtualenv + Install requirements for mypy-protobuf
    if [[ -z $SKIP_CLEAN ]] || [[ ! -e $VENV ]]; then
        python -m virtualenv $VENV
    fi
    source $VENV/bin/activate
    python -m pip install python/ -r requirements.txt

    # Generate protos
    protoc --version
    protoc --python_out=. --mypy_out=. --proto_path=proto/ `find proto/test -name "*.proto"`
)

(
    # Run mypy (always under python3)

    # Create virtualenv
    if [[ -z $SKIP_CLEAN ]] || [[ ! -e $MYPY_VENV ]]; then
        python3 --version
        python3 -m pip --version
        python3 -m virtualenv $MYPY_VENV
    fi
    source $MYPY_VENV/bin/activate
    if [[ -z $SKIP_CLEAN ]] || [[ ! -e $MYPY_VENV ]]; then
        python3 -m pip install setuptools
        python3 -m pip install git+https://github.com/python/mypy.git@v0.780
    fi

    # Run mypy
    for PY in 2.7 3.5; do
        mypy --custom-typeshed-dir=$CUSTOM_TYPESHED_DIR --python-version=$PY python/mypy_protobuf.py test/
        if ! diff <(mypy --custom-typeshed-dir=$CUSTOM_TYPESHED_DIR --python-version=$PY python/mypy_protobuf.py test_negative/) test_negative/output.expected.$PY; then
            echo -e "${RED}test_negative/output.expected.$PY didnt match. Copying over for you. Now rerun${NC}"
            for PY in 2.7 3.5; do
                mypy --custom-typeshed-dir=$CUSTOM_TYPESHED_DIR --python-version=$PY python/mypy_protobuf.py test_negative/ > test_negative/output.expected.$PY || true
            done
            exit 1
        fi
    done
)

(
    # Run unit tests. These tests generate .expected files
    source $VENV/bin/activate
    python --version
    py.test --version
    py.test --ignore=test/proto
)
