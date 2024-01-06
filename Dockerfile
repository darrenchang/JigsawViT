FROM nvidia/cuda:11.8.0-devel-ubuntu20.04 AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG CUDA_VERSION=11.8

# Install cudnn
ARG CUDNN_VERSION=8.6.0.163
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub && \
    apt-get update && \
    apt install -y \
    libcudnn8=${CUDNN_VERSION}-1+cuda${CUDA_VERSION} \
    libcudnn8-dev=${CUDNN_VERSION}-1+cuda${CUDA_VERSION} && \
    rm -rf /var/lib/apt/lists/*

# Install Utils
RUN apt-get update && \
    apt-get install -y \
    wget \
    zip \
    rsync \
    git \
    tmux \
    cifs-utils \
    libibverbs-dev && \
    # Install build tools and build dependencies
    apt-get install -y \
    build-essential \
    checkinstall \
    libc6-dev \
    gdb \
    lcov \
    pkg-config \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    liblzma-dev \
    libncursesw5-dev \
    libncurses5-dev \
    libreadline6-dev \
    libsqlite3-dev \
    libssl-dev \
    lzma \
    lzma-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Pillow build tools
RUN apt-get update && \
    apt-get install -y \
    libjpeg-dev \
    libtiff-dev \
    libfreetype-dev \
    libwebp-dev \
    tk-dev \
    tcl-dev \
    libopenjp2-7-dev \
    libimagequant-dev \
    libraqm-dev \
    liblcms2-dev \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Install python
WORKDIR /tmp
ARG PYTHON_VERSION=3.10.11
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar xzf Python-${PYTHON_VERSION}.tgz && \
    (cd Python-${PYTHON_VERSION} && \
    ./configure \
    --prefix=/python \
    --enable-optimizations \
    --with-lto \
    --with-computed-gotos \
    --with-system-ffi && \
    make -j $(nproc) && \
    make -j $(nproc) altinstall) && \
    update-alternatives --install /usr/bin/python3 python3 /python/bin/python${PYTHON_VERSION%.*} 0 && \
    python3 -m pip install cmake

ENV PATH=/python/bin/:$PATH

SHELL ["/bin/sh", "-c"]

# Install python modules
RUN python3 -m pip install \
    pyyaml==6.0 \
    typing-extensions==4.2.0 \
    wheel==0.37.1 \
    ImageHash==4.2.1 && \
    python3 -m pip install --no-dependencies \
    pytorch-lightning==1.6.3

# Install build tools
RUN apt-get update && \
    # pytorch
    apt-get install -y \
    libmkl-dev \
    libgmp-dev \
    libmpfr-dev \
    libfftw3-dev \
    libopenblas-dev \
    ccache \
    libnuma-dev && \
    # openCV
    apt-get install -y \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libgtk2.0-dev \
    libgtk2.0-cil-dev \
    libgtk3.0-cil-dev \
    libeigen3-dev \
    libogre-1.9-dev \
    libgoogle-glog-dev \
    libgflags-dev && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install mkl-devel

# Download OpenCV source
WORKDIR /opencv
ARG OPENCV_VERSION=4.7.0
RUN wget https://github.com/opencv/opencv/archive/$OPENCV_VERSION.zip && \
    unzip $OPENCV_VERSION.zip && \
    rm $OPENCV_VERSION.zip && \
    wget https://github.com/opencv/opencv_contrib/archive/$OPENCV_VERSION.zip && \
    unzip ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip

# Compile OpenCV with GPU support
RUN mkdir "$(pwd)/opencv-${OPENCV_VERSION}/build" && \
    cd "$(pwd)/opencv-${OPENCV_VERSION}/build" && \
    # Cmake configure
    /python/bin/cmake \
        -DOPENCV_EXTRA_MODULES_PATH=/opencv/opencv_contrib-${OPENCV_VERSION}/modules \
        -DWITH_CUDA=ON \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DOPENCV_ENABLE_NONFREE=ON \
        -DBUILD_NEW_PYTHON_SUPPORT=ON \
        -DBUILD_opencv_python3=ON \
        -DHAVE_opencv_python3=ON \
        -DOPENCV_PYTHON3_INSTALL_PATH=/python/lib/python${PYTHON_VERSION%.*}/site-packages \
        -DPYTHON_EXECUTABLE=/python/bin/python${PYTHON_VERSION%.*} \
        -DCMAKE_LIBRARY_PATH=/python/bin \
        -DCMAKE_INSTALL_PREFIX=/python \
        .. && \
    # Make
    make -j "$(nproc)" && \
    make -j $(nproc) install && \
    ldconfig

# Install pytorch
WORKDIR /pytorch
ARG PYTORCH_BUILD_VERSION=1.11.0+cu115
ARG TORCHVISION_VERSION=0.12.0+cu115
ARG FORCE_CUDA=1
ARG TORCH_CUDA_ARCH_LIST="6.0+PTX;7.0+PTX;8.0+PTX"
RUN python3 -m pip install \
    torch==${PYTORCH_BUILD_VERSION} \
    torchvision==${TORCHVISION_VERSION} \
    -f https://download.pytorch.org/whl/torch_stable.html

# Install requirements
WORKDIR /tmp
COPY requirements.txt ./
RUN python3 -m pip install -r requirements.txt;

WORKDIR /vit
COPY ./entrypoint.sh entrypoint.sh
CMD ["/bin/sh", "/vit/entrypoint.sh"]
