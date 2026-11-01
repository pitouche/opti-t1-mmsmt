#!/bin/bash
# build_t1.sh — T1 mmsmt ISOLE : base prod (objects_h2.rsp) + ggml-cuda.cu recompile (hook mmsmt) + mmsmt.cu
set -e
H2LIB=/home/guile/llama-experiments/h2/cupti129-test/e2/h2lib
T1=/home/guile/llama-experiments/h2/cupti129-test/e2/t1port/ggml-cuda
BD="$H2LIB/build-clean/_deps/llama_cpp-build/ggml/src/ggml-cuda"
cd "$BD"

REF=$(grep nvcc "$H2LIB/compile_h2.sh" | sed 's/ -x cu -c .*//')
compile_one() { eval "$REF -x cu -c \"$1\" -o \"$2\""; }

# 1) ggml-cuda.cu avec le hook mmsmt (depuis t1port)
compile_one "$T1/ggml-cuda.cu" "$H2LIB/ggml-cuda.t1.o"
echo "ggml-cuda.t1.o OK"

# 2) mmsmt.cu
compile_one "$T1/mmsmt.cu" "$H2LIB/mmsmt.t1.o"
echo "mmsmt.t1.o OK"

# 3) rsp : ggml-cuda.cu.o -> ggml-cuda.t1.o + ajouter mmsmt.t1.o
python3 - << "PYEOF"
H2LIB = "/home/guile/llama-experiments/h2/cupti129-test/e2/h2lib"
rsp = open(H2LIB + "/objects_h2.rsp").read()
old = "CMakeFiles/ggml-cuda.dir/ggml-cuda.cu.o"
assert old in rsp
rsp = rsp.replace(old, H2LIB + "/ggml-cuda.t1.o")
rsp = rsp.rstrip()
assert rsp.endswith('"')
rsp = rsp + ' "%s/mmsmt.t1.o"' % H2LIB
open(H2LIB + "/objects_t1.rsp", "w").write(rsp)
print("objects_t1.rsp OK")
PYEOF

# 4) link
/home/guile/llama-experiments/tools/gcc-13-bin/g++ -fPIC -shared -o "$H2LIB/lib/libggml-cuda-t1.so" \
  @"$H2LIB/objects_t1.rsp" @CMakeFiles/ggml-cuda.dir/linkLibs.rsp \
  -L"/home/guile/llama-experiments/tools/cuda-12.6/usr/local/cuda-12.6/targets/x86_64-linux/lib/stubs" \
  -L"/home/guile/llama-experiments/tools/cuda-12.6/usr/local/cuda-12.6/targets/x86_64-linux/lib"
echo "BUILD T1 OK"
ls -la "$H2LIB/lib/libggml-cuda-t1.so"
sha256sum "$H2LIB/lib/libggml-cuda-t1.so"
