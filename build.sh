#!/bin/bash

#     Version Reference
# LLVM_VERSION  CMAKE_VERSION
#   11.0.0        3.13.4
#   13.0.0        3.21.3

USERID=$(id -u)
BUILD_MODE=$1
UBUNTU_VERSION=$(lsb_release -sr | cut -d. -f1) # Useless?
LLVM_VERSION=13.0.0
CMAKE_VERSION=3.21.3
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d. -f-2)

if [ $USERID -ne 0 ]; then
  echo "You need use this script with \"sudo\"."
  exit 1
fi

if [ -z $BUILD_MODE ]; then
  echo "You need specify build mode of LLVM and clang, e.g. "
  echo "\"sudo ./build.sh Debug\" or \"sudo ./build.sh Release\""
  exit 1
elif [[ $BUILD_MODE != "Debug" && $BUILD_MODE != "Release" ]]; then
  echo "Invalid arg: $BUILD_MODE."
  echo "Valid arg: Debug, Release."
  exit 1
fi

echo "Machine Information:"
echo "Ubuntu version : $UBUNTU_VERSION"
echo "Build mode     : $BUILD_MODE"
echo "Python version : $PYTHON_VERSION"

echo ""
echo "Installation:"
echo "LLVM version   : $LLVM_VERSION"
echo "CMake version  : $CMAKE_VERSION"

echo ""
echo "I'm going to build clang & LLVM in $BUILD_MODE mode."
echo "please ensure there is no \"build\" folder in $PWD."
echo "You can stop this script by press ctrl-c any time."
for i in {5..1}; do
  echo -n -e "\rStart in $i seconds."
  sleep 1
done
echo ""

# 参考AFLGo的脚本来build clang & LLVM
LLVM_DEP_PACKAGES="build-essential make ninja-build git binutils-gold binutils-dev curl wget libssl-dev python$PYTHON_VERSION-distutils"
apt-get install -y $LLVM_DEP_PACKAGES

# 如果Ubuntu版本小于等于20, 则安装gcc-10和g++-10
if [ $UBUNTU_VERSION -le 20 ]; then
  install_gcc10
fi

# 安装cmake
install_cmake

# 安装LLVM
install_LLVM

###################################################
#################### Functions ####################
###################################################

# 安装gcc-10和g++-10
install_gcc10() {
  add-apt-repository -y ppa:ubuntu-toolchain-r/test
  apt install -y gcc-10 g++-10

  # 版本管理, 将gcc-10, g++-10设为高优先级
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 1
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 1
}

# 安装cmake
install_cmake() {
  apt purge cmake
  wget https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION.tar.gz
  tar zxvf cmake-$CMAKE_VERSION.tar.gz
  cd cmake-$CMAKE_VERSION
  ./bootstrap
  make
  make install
}

# 安装LLVM
install_LLVM() {
  # build clang & LLVM
  export CXX=g++
  export CC=gcc
  unset CFLAGS
  unset CXXFLAGS

  root_dir=$PWD
  mkdir $root_dir/build
  cd $root_dir/build
  mkdir llvm_tools
  cd llvm_tools
  wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/llvm-$LLVM_VERSION.src.tar.xz
  wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/clang-$LLVM_VERSION.src.tar.xz
  wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/compiler-rt-$LLVM_VERSION.src.tar.xz
  wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/libcxx-$LLVM_VERSION.src.tar.xz
  wget https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/libcxxabi-$LLVM_VERSION.src.tar.xz
  tar xf llvm-$LLVM_VERSION.src.tar.xz
  tar xf clang-$LLVM_VERSION.src.tar.xz
  tar xf compiler-rt-$LLVM_VERSION.src.tar.xz
  tar xf libcxx-$LLVM_VERSION.src.tar.xz
  tar xf libcxxabi-$LLVM_VERSION.src.tar.xz
  mv clang-$LLVM_VERSION.src $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src/tools/clang
  mv compiler-rt-$LLVM_VERSION.src $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src/projects/compiler-rt
  mv libcxx-$LLVM_VERSION.src $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src/projects/libcxx
  mv libcxxabi-$LLVM_VERSION.src $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src/projects/libcxxabi

  mkdir -p build-llvm/llvm
  cd build-llvm/llvm
  cmake -G "Ninja" \
    -DLLVM_PARALLEL_LINK_JOBS=1 \
    -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
    -DCMAKE_BUILD_TYPE=$BUILD_MODE -DLLVM_TARGETS_TO_BUILD="X86" \
    -DLLVM_BINUTILS_INCDIR=/usr/include $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src
  ninja
  ninja install

  cd $root_dir/build/llvm_tools
  mkdir -p build-llvm/msan
  cd build-llvm/msan
  cmake -G "Ninja" \
    -DLLVM_PARALLEL_LINK_JOBS=1 \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DLLVM_USE_SANITIZER=Memory -DCMAKE_INSTALL_PREFIX=/usr/msan/ \
    -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
    -DCMAKE_BUILD_TYPE=$BUILD_MODE -DLLVM_TARGETS_TO_BUILD="X86" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    $root_dir/build/llvm_tools/llvm-$LLVM_VERSION.src
  ninja cxx
  ninja install-cxx

  # Install LLVMgold in bfd-plugins
  mkdir -p /usr/lib/bfd-plugins
  cp /usr/local/lib/libLTO.so /usr/lib/bfd-plugins
  cp /usr/local/lib/LLVMgold.so /usr/lib/bfd-plugins
}