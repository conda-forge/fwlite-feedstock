#!/bin/bash
set -e

# copy source and geometry files to install dir
cp -r src "${PREFIX}"
cp -rv data "${PREFIX}"

PYDOTVER=$(python${PY_VER}-config --libs | sed -E 's@-l@@g'| awk '{print $1}')
echo $PYDOTVER
# set graphics library to link
if [ "$(uname)" == "Linux" ]; then
    CMAKE_ARGS+=" -DPYDOTVER=${PYDOTVER} -DPYVER=${CONDA_PY}"
    export CXXFLAGS="${CXXFLAGS}"
else
    CMAKE_ARGS+=" -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT} -DPYDOTVER=${PYDOTVER} -DPYVER=${CONDA_PY}"

    # Remove -std=c++14 from build ${CXXFLAGS} and use cmake to set std flags
    CXXFLAGS=$(echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
    export CXXFLAGS
fi

export BLDDIR=${PWD}/build-dir
mkdir -p ${BLDDIR}
cd ${BLDDIR}

env TBB_ROOT="${BUILD_PREFIX}" cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_MODULE_PATH=$CMAKE_MODULE_PATH;${BUILD_PREFIX}/lib/cmake \
    -DCMakeTools_DIR="../cmaketools" \
    -DCMSMD5ROOT="${PREFIX}" \
    -DTBB_ROOT_DIR="${BUILD_PREFIX}" \
    -DTBB_INCLUDE_DIR="${BUILD_PREFIX}/include" \
    -DTBB_LIBRARY=TBB_LIBRARIES \
    -DPYBIND11_INCLUDE_DIR="${BUILD_PREFIX}/include" \
    -DEIGEN_INCLUDE_DIR="${BUILD_PREFIX}/include" \
    -DSIGCPP_INCLUDE_DIR="${PREFIX}/lib/sigc++-2.0/include" \
    -DGSL_INCLUDE_DIR="${PREFIX}/include/sigc++-2.0" \
    ../src

make -j${CPU_COUNT}

make install

if [ "$(uname)" == "Darwin" ]; then
    cd ${BLDDIR}/lib
    perl -i -pe "s|\.so|${SHLIB_EXT}|;" *.rootmap
fi

cd ${PREFIX}/lib
../bin/edmPluginRefresh plugin*${SHLIB_EXT}

cd ${BLDDIR}
cp -v lib/*.pcm "${PREFIX}"/lib
cp -v lib/*.rootmap "${PREFIX}"/lib

export CMSSW_VERSION="CMSSW_${PKG_VERSION//./_}"

# Create version.txt expected by cmsShow.exe
echo "${CMSSW_VERSION}" > "${PREFIX}/src/Fireworks/Core/data/version.txt"

# Add the post activate/deactivate scripts
mkdir -p "${PREFIX}/etc/conda/activate.d"
sed  "s/CMSSW_XX_YY_ZZ/${CMSSW_VERSION}/g" "${RECIPE_DIR}/activate.sh" > "${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.sh"
sed  "s/CMSSW_XX_YY_ZZ/${CMSSW_VERSION}/g" "${RECIPE_DIR}/activate.csh" > "${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.csh"
sed  "s/CMSSW_XX_YY_ZZ/${CMSSW_VERSION}/g" "${RECIPE_DIR}/activate.fish" > "${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.fish"

mkdir -p "${PREFIX}/etc/conda/deactivate.d"
cp "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/deactivate-${PKG_NAME}.sh"
cp "${RECIPE_DIR}/deactivate.csh" "${PREFIX}/etc/conda/deactivate.d/deactivate-${PKG_NAME}.csh"
cp "${RECIPE_DIR}/deactivate.fish" "${PREFIX}/etc/conda/deactivate.d/deactivate-${PKG_NAME}.fish"
