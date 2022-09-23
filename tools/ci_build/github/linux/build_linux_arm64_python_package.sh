#!/bin/bash
set -e -x
mkdir /build/dist
CFLAGS="-Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -O3 -pipe -Wl,--strip-all"
CXXFLAGS="-Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -O3 -pipe -Wl,--strip-all"


BUILD_DEVICE="CPU"
BUILD_CONFIG="Release"
while getopts "d:" parameter_Option
do case "${parameter_Option}"
in
#GPU or CPU. 
d) BUILD_DEVICE=${OPTARG};;
esac
done

GCC_VERSION=$(gcc -dumpversion)
#-fstack-clash-protection prevents attacks based on an overlapping heap and stack.
if [ "$GCC_VERSION" -ge 8 ]; then
    CFLAGS="$CFLAGS -fstack-clash-protection"
    CXXFLAGS="$CXXFLAGS -fstack-clash-protection"
fi

ARCH=$(uname -i)

if [ $ARCH == "x86_64" ] && [ "$GCC_VERSION" -ge 9 ]; then
    CFLAGS="$CFLAGS -fcf-protection"
    CXXFLAGS="$CXXFLAGS -fcf-protection"
fi


BUILD_ARGS="--build_dir /build --config $BUILD_CONFIG --update --build --skip_submodule_sync --parallel --enable_lto --build_wheel"

if [ $ARCH == "x86_64" ]; then
    #ARM build machines do not have the test data yet.
    BUILD_ARGS="$BUILD_ARGS --enable_onnx_tests"
fi
if [ $BUILD_DEVICE == "GPU" ]; then
    BUILD_ARGS="$BUILD_ARGS --use_cuda --use_tensorrt --cuda_version=11.6 --tensorrt_home=/usr --cuda_home=/usr/local/cuda-11.6 --cudnn_home=/usr/local/cuda-11.6"
fi
export CFLAGS
export CXXFLAGS
PYTHON_EXES=("/opt/python/cp37-cp37m/bin/python3.7" "/opt/python/cp38-cp38/bin/python3.8" "/opt/python/cp39-cp39/bin/python3.9" "/opt/python/cp310-cp310/bin/python3.10")
for PYTHON_EXE in "${PYTHON_EXES[@]}"
do
  rm -rf /build/$BUILD_CONFIG
  ${PYTHON_EXE} /onnxruntime_src/tools/ci_build/build.py $BUILD_ARGS
                  
  cp /build/$BUILD_CONFIG/dist/*.whl /build/dist
done