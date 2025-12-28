
build:
  cmake --build profiler/build --config Release --parallel

config:
  cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE=Release
