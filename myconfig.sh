#!/bin/bash

# Ensure the DEBIAN_FRONTEND environment variable is set for apt-get calls
APT_GET="env DEBIAN_FRONTEND=noninteractive $(command -v apt-get)"

ensure_prereqs() {
    export DEBIAN_FRONTEND=noninteractive

    if ! command -v sudo &> /dev/null; then
        echo "Installing sudo"
        $APT_GET update
        $APT_GET install -y -qq --no-install-recommends sudo
    else
        sudo $APT_GET update
    fi

    if ! command -v lsb_release &> /dev/null; then
        echo "Installing lsb_release"
        sudo $APT_GET install -y -qq --no-install-recommends lsb-release
    fi

    if ! command -v pkg-config &> /dev/null; then
        echo "Installing pkg-config"
        sudo $APT_GET install -y -qq --no-install-recommends pkg-config
    fi

    echo "Installing tzdata"
    sudo $APT_GET install -y -qq tzdata

    echo "Installing libxml2-dev"
    sudo $APT_GET install -y -qq --no-install-recommends libxml2-dev

    echo "Installing libgdal-dev"
    sudo $APT_GET install -y -qq --no-install-recommends libgdal-dev

    echo "Installing libxslt-dev"
    sudo $APT_GET install -y -qq --no-install-recommends libxslt-dev

    echo "Installing Python PIP"
    sudo $APT_GET install -y -qq --no-install-recommends \
        python3-pip \
        python3-setuptools
    sudo pip3 install -U pip
    sudo pip3 install -U shyaml
}


# Save all dependencies in snapcraft.yaml to maintain a single source of truth.
# Maintaining multiple lists will otherwise be painful.
installdepsfromsnapcraft() {
    section="$2"
    case "$1" in
        build) key=build-packages; ;;
        runtime) key=stage-packages; ;;
        *) key=build-packages; ;; # shouldn't be needed, but it's here just in case
    esac

    UBUNTU_VERSION=$(lsb_release -r)
    SNAPCRAFT_FILE="snapcraft.yaml"
    if [[ "$UBUNTU_VERSION" == *"21.04"* ]]; then
        SNAPCRAFT_FILE="snapcraft21.yaml"
    fi

    cat snap/$SNAPCRAFT_FILE | \
        shyaml get-values-0 parts.$section.$key | \
        xargs -0 sudo $APT_GET install -y -qq --no-install-recommends
}


installreqs() {
    cd /code
    
    ## Set up library paths
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$RUNPATH/SuperBuild/install/lib

	## Before installing
    echo "Updating the system"
    ensure_prereqs
    
    echo "Installing Required Requisites"
    installdepsfromsnapcraft build prereqs
    echo "Installing OpenCV Dependencies"
    installdepsfromsnapcraft build opencv
    echo "Installing OpenSfM Dependencies"
    installdepsfromsnapcraft build opensfm
    echo "Installing OpenMVS Dependencies"
    installdepsfromsnapcraft build openmvs
    
    set -e

    # edt requires numpy to build
    pip install --ignore-installed numpy==1.23.1
    pip install --ignore-installed -r requirements.txt
    #if [ ! -z "$GPU_INSTALL" ]; then
    #fi
    set +e
}



install_odm() {
    installreqs

    if [ ! -z "$PORTABLE_INSTALL" ]; then
        echo "Replacing g++ and gcc with our scripts for portability..."
        if [ ! -e /usr/bin/gcc_real ]; then
            sudo mv -v /usr/bin/gcc /usr/bin/gcc_real
            sudo cp -v ./docker/gcc /usr/bin/gcc
        fi
        if [ ! -e /usr/bin/g++_real ]; then
            sudo mv -v /usr/bin/g++ /usr/bin/g++_real
            sudo cp -v ./docker/g++ /usr/bin/g++
        fi
    fi

    set -eo pipefail
    
    echo "Compiling SuperBuild"
    cd ${RUNPATH}/SuperBuild
    mkdir -p build && cd build
    cmake .. && make -j$processes

    echo "Configuration Finished"
}



# Main Execution
RUNPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
install_odm

echo "Finished Install dependencies Prereqs"