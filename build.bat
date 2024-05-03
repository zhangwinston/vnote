mkdir build
cd build
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DQT_DEFAULT_MAJOR_VERSION=5 ..
cmake --build .
cmake --build . --target=deploy
cmake --build . --target=pack
7z x VNote*.zip -o*
