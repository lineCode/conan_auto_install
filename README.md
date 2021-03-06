# About

Allows to auto install conan deps during cmake configure step.

Useful if you want to use IDE that auto-creates build and configure directories (like QT).

See QT instructions https://doc.qt.io/qtcreator/creator-build-settings.html#cmake-build-configuration

If you have really big deps like llvm - Prefer to install big deps (`conan install` in terminal) without IDE integration manually and always with same build settings (otherwise IDE may hang for long time without proper logging during llvm build!)

## Usage

Usage with `FetchContent` to auto-download and `include` file:

```cmake
# Note: FetchContent is available since CMake 3.11
# see https://cmake.org/cmake/help/git-master/module/FetchContent.html
# By default, everything is downloaded into your build directory
# Once CMake successfully downloads our external content, it sets two variables that can be used in CMakeLists.txt to locate the new data:
# 1 <resource_name>_SOURCE_DIR
#   specifies the location of the downloaded sources,
# 2 <resource_name>_BINARY_DIR
#   specifies where is the default build directory for the downloaded sources.
include(FetchContent)

set(FetchContent_conan_auto_install "conan_auto_install")
FetchContent_Declare(
  ${FetchContent_conan_auto_install}
  PREFIX external_dependencies/${FetchContent_conan_auto_install}
  GIT_REPOSITORY https://github.com/blockspacer/conan_auto_install.git
  GIT_TAG origin/master
  # Disable warning about detached HEAD https://stackoverflow.com/a/36794768
  GIT_CONFIG        advice.detachedHead=false
  SOURCE_DIR        "${CMAKE_BINARY_DIR}/${FetchContent_conan_auto_install}"
  BINARY_DIR        "${CMAKE_BINARY_DIR}/${FetchContent_conan_auto_install}-build"
  CMAKE_ARGS        "-Wno-dev"
  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
FetchContent_GetProperties(${FetchContent_conan_auto_install})
if (NOT ${FetchContent_conan_auto_install}_POPULATED)
  # Populate command can be used only once for every resource
  # during cmake configuration, which explains the conditional above.
  FetchContent_Populate(${FetchContent_conan_auto_install})
  # The second argument passed to add_subdirectory() is optional
  # and tells CMake, that we don’t want to build that directory in a
  # place basing on our repository structure (${CMAKE_CURRENT_BINARY_DIR})
  # but in a place specified by FetchContent.
  # This nicely separates out compilation products from the external ones.
  #add_subdirectory(
  #  ${${FetchContent_conan_auto_install}_SOURCE_DIR}
  #  ${${FetchContent_conan_auto_install}_BINARY_DIR})
endif()
message(STATUS "${FetchContent_conan_auto_install}_SOURCE_DIR = ${${FetchContent_conan_auto_install}_SOURCE_DIR}")
message(STATUS "${FetchContent_conan_auto_install}_BINARY_DIR = ${${FetchContent_conan_auto_install}_BINARY_DIR}")
include(${${FetchContent_conan_auto_install}_SOURCE_DIR}/conan-auto-install.cmake)
option(CONAN_AUTO_INSTALL "Let CMake call conan install automatically" 
  ON
)
if (CONAN_AUTO_INSTALL)
  set(CONAN_PROFILE
      "clang"
      CACHE STRING "Conan profile to use during installation")
  if (NOT CMAKE_BUILD_TYPE MATCHES "Debug" )
    set(conan_build_type "Release")
  else()
    set(conan_build_type "Debug")
  endif()
  conan_auto_install(
    CONAN_OPTIONS "--profile=${CONAN_PROFILE} -s build_type=${conan_build_type} --build=missing -o openssl:shared=True"
    #FORCE
  )
endif()
```

Note what you can change `CONAN_AUTO_INSTALL=ON`

## What to do after `conan_auto_install`?

After `conan_auto_install` you can use `conan_basic_setup` as usual:

```cmake
if(EXISTS "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake")
  list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_BINARY_DIR}/)
  include(${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake)
  include(${CMAKE_CURRENT_BINARY_DIR}/conan_paths.cmake OPTIONAL)
  conan_basic_setup(
    # prevent conan_basic_setup from resetting cmake variables
    TARGETS
    # NO_OUTPUT_DIRS to allow custom RUNTIME_OUTPUT_DIRECTORY
    # see https://github.com/conan-io/conan/issues/6012
    NO_OUTPUT_DIRS
  )
else()
  message (WARNING "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake not found!")
  message (FATAL_ERROR "must use conan")
endif()
```

