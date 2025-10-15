#!/usr/bin/env bash
set -euo pipefail

ONNX_CONFIG="${1:-model.required_operators_and_types.config}"
CMAKE_BUILD_TYPE=MinSizeRel

build_arch() {
  ONNX_CONFIG="$1"
  ARCH="$2"

  python onnxruntime/tools/ci_build/build.py \
  --build_dir "onnxruntime/build/macOS_${ARCH}" \
  --config=${CMAKE_BUILD_TYPE} \
  --parallel \
  --minimal_build \
  --apple_deploy_target="10.13" \
  --disable_ml_ops --disable_rtti \
  --include_ops_by_config "$ONNX_CONFIG" \
  --enable_reduced_operator_type_support \
  --cmake_extra_defines CMAKE_OSX_ARCHITECTURES="${ARCH}" \
  --skip_tests \
  --use_vcpkg #added for MacOS 15.x builds

  # Disable unit tests
  #--cmake_extra_defines onnxruntime_BUILD_UNIT_TESTS=OFF

  BUILD_DIR=./onnxruntime/build/macOS_${ARCH}/${CMAKE_BUILD_TYPE}

  if [[ "${ARCH}" == "arm64" ]]; then
    VCPKG_TRIPLET="arm64-osx"
  else
    VCPKG_TRIPLET="x64-osx"
  fi
  VCPKG_LIB_DIR="${BUILD_DIR}/vcpkg_installed/${VCPKG_TRIPLET}/lib"

  ABSEIL_LIBS=("${VCPKG_LIB_DIR}"/libabsl_*.a)
  UTF8_LIBS=("${VCPKG_LIB_DIR}"/libutf8_*.a)

  BUILD_LIBS=(
    "${BUILD_DIR}/libonnxruntime_graph.a"
    "${BUILD_DIR}/libonnxruntime_mlas.a"
    "${BUILD_DIR}/libonnx_test_data_proto.a"
    "${BUILD_DIR}/libonnxruntime_optimizer.a"
    "${BUILD_DIR}/libonnx_test_runner_common.a"
    "${BUILD_DIR}/libonnxruntime_common.a"
    "${BUILD_DIR}/libonnxruntime_providers.a"
    "${BUILD_DIR}/libonnxruntime_session.a"
    "${BUILD_DIR}/libonnxruntime_lora.a"
    "${BUILD_DIR}/libonnxruntime_flatbuffers.a"
    "${BUILD_DIR}/libonnxruntime_test_utils.a"
    "${BUILD_DIR}/libonnxruntime_framework.a"
    "${BUILD_DIR}/libonnxruntime_util.a"
    "${BUILD_DIR}/_deps/pytorch_cpuinfo-build/libcpuinfo.a"
  )

  VCPKG_LIBS=(
    "${VCPKG_LIB_DIR}/libonnx.a"
    "${VCPKG_LIB_DIR}/libonnx_proto.a"
    "${VCPKG_LIB_DIR}/libprotobuf-lite.a"
    "${VCPKG_LIB_DIR}/libprotobuf.a"
    "${VCPKG_LIB_DIR}/libflatbuffers.a"
    "${VCPKG_LIB_DIR}/libprotoc.a"
    "${VCPKG_LIB_DIR}/libre2.a"
  )

  libtool -static -o "onnxruntime-macOS_${ARCH}-static-combined.a" \
    "${BUILD_LIBS[@]}" \
    "${VCPKG_LIBS[@]}" \
    "${ABSEIL_LIBS[@]}" \
    "${UTF8_LIBS[@]}"
}

build_arch "$ONNX_CONFIG" x86_64
build_arch "$ONNX_CONFIG" arm64

mkdir -p libs/macos-arm64_x86_64
lipo -create onnxruntime-macos_x86_64-static-combined.a \
             onnxruntime-macos_arm64-static-combined.a \
     -output "libs/macos-arm64_x86_64/libonnxruntime.a"
rm onnxruntime-macos_x86_64-static-combined.a
rm onnxruntime-macos_arm64-static-combined.a
