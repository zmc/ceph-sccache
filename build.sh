#!/bin/bash
set -ex
if [ ! -d /ceph/build ]; then
  ./do_cmake.sh $CMAKE_ARGS
fi
cd /ceph/build
ninja $NINJA_ARGS
sccache -s
