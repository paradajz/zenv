FROM ubuntu:24.04

ARG project_dir=project
ARG toolchains_path=/opt/toolchains
ARG zsdk_version=0.17.0
ARG dasel_version=1.27.3
ARG wget_args="-q --show-progress --progress=bar:force:noscroll"
ARG zephyr_ws=/home/ubuntu/zephyr_ws
ARG ccache_dir=${zephyr_ws}/${project_dir}/ccache

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=${toolchains_path}/zephyr-sdk-${zsdk_version}
ENV ZEPHYR_WS=${zephyr_ws}
ENV ZEPHYR_BASE=${zephyr_ws}/zephyr
ENV ZEPHYR_PROJECT=${zephyr_ws}/${project_dir}
ENV CCACHE_DIR=${ccache_dir}

RUN \
apt-get update && \
apt-get install --no-install-recommends -y \
locales

RUN locale-gen en_US.UTF-8

RUN \
apt-get update && \
apt-get install --no-install-recommends -y \
bsdmainutils \
ca-certificates \
ccache \
clang-format \
clang-tidy \
clangd \
cmake \
device-tree-compiler \
dfu-util \
file \
g++ \
gcc \
gdb \
git \
git-lfs \
gnupg \
libgmock-dev \
libgtest-dev \
libusb-1.0-0 \
make \
nano \
ninja-build \
openssh-client \
pkg-config \
python3-dev \
python3-pip \
python3-venv \
software-properties-common \
srecord \
sudo \
valgrind \
wget \
xxd \
xz-utils \
zip \
&& \
rm -rf /var/lib/apt/lists/*

# Needed for CodeChecker so that the detection of other clang tools works
RUN ln -s /usr/bin/clang-18 /usr/bin/clang

RUN locale-gen en_US.UTF-8

RUN \
mkdir -p ${toolchains_path} && \
cd ${toolchains_path} && \
ARCH=$(uname -m); \
wget ${wget_args} https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${zsdk_version}/zephyr-sdk-${zsdk_version}_linux-${ARCH}_minimal.tar.xz && \
tar xvf zephyr-sdk-${zsdk_version}_linux-${ARCH}_minimal.tar.xz && \
zephyr-sdk-${zsdk_version}/setup.sh -t arm-zephyr-eabi -t ${ARCH}-zephyr-elf -h -c && \
rm zephyr-sdk-${zsdk_version}_linux-${ARCH}_minimal.tar.xz

# Dasel - YAML/JSON parsing tool
RUN \
wget ${wget_args} https://github.com/TomWright/dasel/releases/download/v${dasel_version}/dasel_linux_$(dpkg --print-architecture) -O dasel && \
chmod +x dasel && \
mv ./dasel /usr/local/bin/dasel

# Disable password prompt for sudo commands
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Don't run as root
USER ubuntu
WORKDIR ${zephyr_ws}

# Initialize the base projects/modules specified in west.yml from this repository
# when building the image not to do it every time the container is created.
# This is done with west init using -l flag which tells it to initialize
# workspace from local west.yml instead of from remote repository.
# Do this inside temporary ${zephyr_ws}/${project_dir} directory to make sure
# that west update works once the repository is mounted to the container.
# Finally, add importing of west.yml located in the project directory.

ADD west.yml ${zephyr_ws}/west.yml

RUN \
python3 -m venv ${zephyr_ws}/.venv && \
. ${zephyr_ws}/.venv/bin/activate && \
pip install west codechecker && \
mkdir -p ${zephyr_ws}/${project_dir} && \
cd ${zephyr_ws}/${project_dir} && \
west init --mf ../west.yml -l . && \
west update && \
west zephyr-export && \
pip3 install -r ../zephyr/scripts/requirements.txt && \
cd ${zephyr_ws} && \
rm -rf ${zephyr_ws}/${project_dir} && \
sudo tee -a west.yml <<EOF
  self:
    import: west.yml
EOF

ADD ./ ${zephyr_ws}/zenv

RUN \
tee -a /home/ubuntu/.bashrc <<EOF
alias mkc='make clean'
source ${zephyr_ws}/zenv/scripts/git_branch_bash.sh
source /usr/share/bash-completion/completions/git
source ${zephyr_ws}/.venv/bin/activate
EOF
