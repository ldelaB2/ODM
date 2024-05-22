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

    UBUNTU_VERSION=$(lsb_release -r)
    if [[ "$UBUNTU_VERSION" == *"20.04"* ]]; then
        echo "Enabling PPA for Ubuntu GIS"
        sudo $APT_GET install -y -qq --no-install-recommends software-properties-common
        sudo add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
        sudo $APT_GET update
    fi

    echo "Installing Python PIP"
    sudo $APT_GET install -y -qq --no-install-recommends \
        python3-pip \
        python3-setuptools
    sudo pip3 install -U pip
    sudo pip3 install -U shyaml
}

ensure_prereqs

echo "Finished Checking Prereqs"