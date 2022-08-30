#!/bin/bash

USERID=$(id -u)

if [ $USERID -ne 0 ]; then
  echo "You need use this script with \"sudo\"."
  exit 1
fi

echo "I'm going to build clang & LLVM in $HOME."
echo "please ensure there is no \"build\" folder in $HOME."
echo "You can stop this script by press ctrl-c any time."
sleep 5s

# 参考AFLGo的脚本来build clang & LLVM
LLVM_DEP_PACKAGES="build-essential make ninja-build git binutils-gold binutils-dev curl wget"
apt-get install -y $LLVM_DEP_PACKAGES

# 安装g++-10
add-apt-repository ppa:ubuntu-toolchain-r/test
apt install g++-10

# 版本管理, 将gcc-10, g++-10设为高优先级
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 1
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 2
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 1
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 2

# 安装cmake 3.13.4
apt purge cmake
wget https://github.com/Kitware/CMake/releases/download/v3.13.4/cmake-3.13.4.tar.gz
tar zxvf cmake-3.13.4.tar.gz
cd cmake-3.13.4
./bootstrap
make
make install

# build clang & LLVM (version 11.0.0)
export CXX=g++
export CC=gcc
unset CFLAGS
unset CXXFLAGS

# rm -rf ~/build
mkdir ~/build; cd ~/build
mkdir llvm_tools; cd llvm_tools
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-11.0.0.src.tar.xz
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/clang-11.0.0.src.tar.xz
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/compiler-rt-11.0.0.src.tar.xz
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/libcxx-11.0.0.src.tar.xz
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/libcxxabi-11.0.0.src.tar.xz
tar xf llvm-11.0.0.src.tar.xz
tar xf clang-11.0.0.src.tar.xz
tar xf compiler-rt-11.0.0.src.tar.xz
tar xf libcxx-11.0.0.src.tar.xz
tar xf libcxxabi-11.0.0.src.tar.xz
mv clang-11.0.0.src ~/build/llvm_tools/llvm-11.0.0.src/tools/clang
mv compiler-rt-11.0.0.src ~/build/llvm_tools/llvm-11.0.0.src/projects/compiler-rt
mv libcxx-11.0.0.src ~/build/llvm_tools/llvm-11.0.0.src/projects/libcxx
mv libcxxabi-11.0.0.src ~/build/llvm_tools/llvm-11.0.0.src/projects/libcxxabi

mkdir -p build-llvm/llvm; cd build-llvm/llvm
cmake -G "Ninja" \
      -DLLVM_PARALLEL_LINK_JOBS=1 \
      -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
      -DCMAKE_BUILD_TYPE=Debug -DLLVM_TARGETS_TO_BUILD="X86" \
      -DLLVM_BINUTILS_INCDIR=/usr/include ~/build/llvm_tools/llvm-11.0.0.src
ninja; ninja install

cd ~/build/llvm_tools
mkdir -p build-llvm/msan; cd build-llvm/msan
cmake -G "Ninja" \
      -DLLVM_PARALLEL_LINK_JOBS=1 \
      -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
      -DLLVM_USE_SANITIZER=Memory -DCMAKE_INSTALL_PREFIX=/usr/msan/ \
      -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
      -DCMAKE_BUILD_TYPE=Debug -DLLVM_TARGETS_TO_BUILD="X86" \
       ~/build/llvm_tools/llvm-11.0.0.src
ninja cxx; ninja install-cxx

# Install LLVMgold in bfd-plugins
mkdir -p /usr/lib/bfd-plugins
cp /usr/local/lib/libLTO.so /usr/lib/bfd-plugins
cp /usr/local/lib/LLVMgold.so /usr/lib/bfd-plugins