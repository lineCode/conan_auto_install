# ARGUMENTS:
# FORCE - run `conan install` even if options has not changed from last `conan install`
# CONAN_OPTIONS - arguments that will be passed to `conan install`
#
# USAGE:
# conan_auto_install(
#   CONAN_OPTIONS "--profile=${CONAN_PROFILE} -s build_type=${conan_build_type} --build=missing -o openssl:shared=True"
#   #FORCE
# )
function(conan_auto_install)
  set(options FORCE)
  set(multiValueArgs CONAN_OPTIONS)
  cmake_parse_arguments(ARGUMENTS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  set(CONAN_FILE ${CMAKE_SOURCE_DIR}/conanfile.py)
  foreach (option ${ARGUMENTS_CONAN_OPTIONS})
    set(CONAN_OPTIONS "${ARGUMENTS_CONAN_OPTIONS} ${option}")
  endforeach ()

  set(CONAN_OPTIONS_HAVE_CHANGED FALSE)

  # Call `conan install` only if conanbuildinfo.cmake doesn't exist or it's older
  # than Conan file This avoids reinstalling the conan packages every single time
  # CMake reconfigures
  if(ARGUMENTS_FORCE)
    set(CONAN_OPTIONS_HAVE_CHANGED TRUE)
  else(ARGUMENTS_FORCE)
    if (EXISTS ".conan_options")
      file(READ "${CMAKE_CURRENT_BINARY_DIR}/.conan_options" FILE_CONAN_OPTIONS)
      string(COMPARE NOTEQUAL
          "${FILE_CONAN_OPTIONS}"
          "${ARGUMENTS_CONAN_OPTIONS}"
          CONAN_OPTIONS_HAVE_CHANGED)
    endif ()
  endif(ARGUMENTS_FORCE)

  find_program(CONAN_PATH conan
               HINTS ${CONAN_DIR}
                     /usr/bin
                     /usr/local/bin
                     $PATH
                     CMAKE_SYSTEM_PROGRAM_PATH)

  if(NOT CONAN_PATH)
    message(FATAL_ERROR "conan not found! Aborting...")
  endif() # NOT CONAN_PATH

  # To avoid unnecessarily copying binaries and libraries from the Conan packges
  # `imports` rules when the project is being built, the flag --no-imports is
  # used. Additionally, a custom install rule is added so when the project is
  # installed, then the Conan `imports` rule is explicitly executed and the files
  # are copied to the actual CMake installation folder.
  if (CONAN_OPTIONS_HAVE_CHANGED
      OR NOT EXISTS "conanbuildinfo.cmake"
      OR ${CONAN_FILE} IS_NEWER_THAN "conanbuildinfo.cmake")
    message(STATUS "Installing Conan dependencies with options ${ARGUMENTS_CONAN_OPTIONS} into ${CMAKE_CURRENT_BINARY_DIR}")
    execute_process(
        COMMAND
        script
        -e
        -q
        -f
        -c
        "CONAN_REVISIONS_ENABLED=1 \
         CONAN_VERBOSE_TRACEBACK=1 \
         CONAN_PRINT_RUN_COMMANDS=1 \
         CONAN_LOGGING_LEVEL=10 \
         GIT_SSL_NO_VERIFY=true \
         ${CONAN_PATH} install ${CMAKE_SOURCE_DIR} \
         --no-imports \
         --install-folder ${CMAKE_CURRENT_BINARY_DIR} \
         ${ARGUMENTS_CONAN_OPTIONS}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        TIMEOUT 7200 # sec
        OUTPUT_VARIABLE stdout
        ERROR_VARIABLE stderr
        RESULT_VARIABLE CONAN_INSTALL_ERROR)
    if(NOT "${retcode}" STREQUAL "" AND NOT "${retcode}" STREQUAL "0")
      message( FATAL_ERROR "Bad exit status, retcode=${retcode}, stdout=${stdout} ${stderr}")
    endif()
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.conan_options" ${ARGUMENTS_CONAN_OPTIONS})
  endif ()

  if (CONAN_INSTALL_ERROR)
    message(FATAL_ERROR "Conan installation failed, retcode=${retcode}, stdout=${stdout} ${stderr}")
  endif ()

  # This causes CMake to reconfiure when Conan file changes, and it lets IDEs
  # index the file as well
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CONAN_FILE})

  # Execute the imports() rules defined in the conanfile.py, but install to the
  # project specific install folder
  if (COPY_CONAN_ARTIFACTS_TO_INSTALL_FOLDER)
    install(
        CODE
        "execute_process(COMMAND conan imports ${CMAKE_SOURCE_DIR} --import-folder ${CMAKE_INSTALL_PREFIX})"
    )
  endif ()
endfunction()

function(conan_option_from_boolean option boolean)
  if (${boolean})
    set(${option} "True" PARENT_SCOPE)
  else ()
    set(${option} "False" PARENT_SCOPE)
  endif ()
endfunction()
