#!/bin/bash
set -e

# copy source and geometry files to install dir
cp -r src "${PREFIX}"
cp -rv data "${PREFIX}"

# set graphics library to link
if [ "$(uname)" == "Linux" ]; then
    export CXXFLAGS="${CXXFLAGS}"
else
    CMAKE_ARGS+=" -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT} -DCMAKE_FIND_FRAMEWORK=LAST -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15"

    # Remove -std=c++14 from build ${CXXFLAGS} and use cmake to set std flags
    CXXFLAGS=$(echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
    export CXXFLAGS
fi

export BLDDIR=${PWD}/build-dir
mkdir -p ${BLDDIR}
cd ${BLDDIR}

cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMakeTools_DIR="../cmaketools" \
    -DCMSMD5ROOT="${PREFIX}" \
    -DTBB_ROOT_DIR="${PREFIX}" \
    -DTBB_INCLUDE_DIR="${PREFIX}/include" \
    -DPYBIND11_INCLUDE_DIR="${PREFIX}/include" \
    -DEIGEN_INCLUDE_DIR="${PREFIX}/include" \
    -DSIGCPP_LIB_INCLUDE_DIR="${PREFIX}/lib/sigc++-2.0/include" \
    -DSIGCPP_INCLUDE_DIR="${PREFIX}/include/sigc++-2.0" \
    -DGSL_INCLUDE_DIR="${PREFIX}/include" \
    -DPython_ROOT_DIR="${PREFIX}" \
    -DPython_FIND_STRATEGY=LOCATION \
    -DPython_FIND_VIRTUALENV=STANDARD \
    --trace \
    ../src

make -j${CPU_COUNT}

make install

if [ "$(uname)" == "Darwin" ]; then
    cd ${BLDDIR}/lib
    perl -i -pe "s|\.so|${SHLIB_EXT}|;" *.rootmap
fi

cd ${PREFIX}/lib
../bin/edmPluginRefresh plugin*${SHLIB_EXT}

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
