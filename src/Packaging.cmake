# from: https://github.com/miurahr/cmake-qt-packaging-example
find_package(Qt${QT_DEFAULT_MAJOR_VERSION} REQUIRED COMPONENTS Core)

get_target_property(QMAKE_EXECUTABLE Qt::qmake IMPORTED_LOCATION)
get_filename_component(QT_BIN_DIR "${QMAKE_EXECUTABLE}" DIRECTORY)
execute_process(COMMAND ${QMAKE_EXECUTABLE} -query QT_VERSION
    OUTPUT_VARIABLE QT_VERSION OUTPUT_STRIP_TRAILING_WHITESPACE)

set(QT_TOOLS_DIR "${QT_BIN_DIR}/../../../Tools")
cmake_path(NORMAL_PATH QT_TOOLS_DIR OUTPUT_VARIABLE QT_TOOLS_DIR)

set(QT_PLUGINS_DIR "${QT_BIN_DIR}/../plugins")
cmake_path(NORMAL_PATH QT_PLUGINS_DIR OUTPUT_VARIABLE QT_PLUGINS_DIR)

# To use the specific version of Qt
set(WINDEPLOYQT_EXECUTABLE "${QT_BIN_DIR}/windeployqt.exe")

find_program(LINUXDEPLOY_EXECUTABLE linuxdeploy linuxdeploy-x86_64.AppImage HINTS "${QT_BIN_DIR}")
find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${QT_BIN_DIR}")
find_program(MACDEPLOYQTFIX_EXECUTABLE macdeployqtfix.py HINTS "${QT_BIN_DIR}")
find_package(Python)

# Attribution is a deployment prerequisite, not a configure or application-startup operation.
# The native Typst backend (and its Qt PDF attribution) only exists when the
# Typst editor is built; the Qt 5.15 / Windows 7 variant ships neither.
if(VTEXTEDIT_ENABLE_TYPST)
    get_filename_component(VX_TYPST_QT_PREFIX "${QT_BIN_DIR}/.." ABSOLUTE)
    set(VX_TYPST_NOTICES_DIR "${CMAKE_CURRENT_BINARY_DIR}/typst-notices")
    add_custom_target(prepare_typst_notices
        COMMAND "${Python_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/package/prepare-typst-notices.py"
            --manifest "${PROJECT_SOURCE_DIR}/libs/vtextedit/tools/typst-backend/Cargo.toml"
            --qt-prefix "${VX_TYPST_QT_PREFIX}"
            --qt-version "${QT_VERSION}"
            --output-dir "${VX_TYPST_NOTICES_DIR}"
        BYPRODUCTS "${VX_TYPST_NOTICES_DIR}/LICENSE.typst-dependencies"
                   "${VX_TYPST_NOTICES_DIR}/LICENSE.vtextedit-typst"
                   "${VX_TYPST_NOTICES_DIR}/qtpdf-${QT_VERSION}.spdx.json"
                   "${VX_TYPST_NOTICES_DIR}/qtwebengine-chromium-pdf-${QT_VERSION}.spdx.json"
        COMMENT "Preparing Typst and Qt PDF runtime attribution"
        VERBATIM
    )
endif()

function(windeployqt target)
    # Bundle Library Files
    string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UPPER)

    if ((QT_DEFAULT_MAJOR_VERSION GREATER 5))
        if(CMAKE_BUILD_TYPE_UPPER STREQUAL "DEBUG")
            set(WINDEPLOYQT_ARGS --debug)
        else()
            set(WINDEPLOYQT_ARGS --release)
        endif()
    endif()

    set(UPDATER_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/win-updater")
    add_custom_target(prepare_win_updater
        COMMAND "${CMAKE_COMMAND}"
            "-DUPDATER_OUTPUT_DIR=${UPDATER_OUTPUT_DIR}"
            -P "${PROJECT_SOURCE_DIR}/package/prepare-win-updater.cmake"
        BYPRODUCTS "${UPDATER_OUTPUT_DIR}/minisign.exe"
                   "${UPDATER_OUTPUT_DIR}/LICENSE.minisign"
        COMMENT "Preparing Windows updater..."
        VERBATIM
    )

    add_custom_target(deploy
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/winqt/"
        COMMAND "${CMAKE_COMMAND}" -E
            env PATH="${QT_BIN_DIR}" "${WINDEPLOYQT_EXECUTABLE}"
            ${WINDEPLOYQT_ARGS}
            --no-quick-import
            --no-opengl-sw
            --no-compiler-runtime
            --translations zh_CN,ja,ko
            --dir "${CMAKE_CURRENT_BINARY_DIR}/winqt/"
            "$<TARGET_FILE:${target}>" "$<TARGET_FILE:VTextEdit>"
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/winqt/generic/"
        # Keep winqt/styles/: it holds qwindows11style.dll, without which Qt 6
        # falls back to the legacy windowsvista style on Windows 11 (beveled
        # QFrame::StyledPanel borders instead of the modern rounded panels).
        COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/winqt/qmltooling/"
        # Typst needs Qt6Pdf, but not the PDF image-format plugin.
        # Unused NMEA backend needs SerialPort; Qt 6.10.3 ignores --exclude-plugins here.
        COMMAND "${CMAKE_COMMAND}" -E rm -f
            "${CMAKE_CURRENT_BINARY_DIR}/winqt/imageformats/qpdf.dll"
            "${CMAKE_CURRENT_BINARY_DIR}/winqt/imageformats/qpdfd.dll"
            "${CMAKE_CURRENT_BINARY_DIR}/winqt/position/qtposition_nmea.dll"
            "${CMAKE_CURRENT_BINARY_DIR}/winqt/position/qtposition_nmead.dll"
        COMMENT "Deploying Qt..."
        DEPENDS vnote lrelease
    )

    add_dependencies(deploy prepare_win_updater)
    if(VTEXTEDIT_ENABLE_TYPST)
        add_dependencies(deploy vnote_typst_runtime prepare_typst_notices)
    endif()
    add_dependencies(pack deploy)

    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/winqt/" DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)
    install(FILES
        "${PROJECT_SOURCE_DIR}/scripts/update-vnote.ps1"
        "${UPDATER_OUTPUT_DIR}/minisign.exe"
        "${UPDATER_OUTPUT_DIR}/LICENSE.minisign"
        DESTINATION "${CMAKE_INSTALL_BINDIR}/updater"
    )
    if(VTEXTEDIT_ENABLE_TYPST)
        install(DIRECTORY "${VX_TYPST_NOTICES_DIR}/"
            DESTINATION "${CMAKE_INSTALL_BINDIR}/licenses/typst")
    endif()

    # Qt's own tools_openssl_x64 package (OpenSSL 1.1.1, installing to
    # Tools/OpenSSL/Win_x64/bin -- exactly what this globs for) has been DELISTED
    # from download.qt.io; the desktop repo now offers only tools_opensslv3_x64 /
    # tools_opensslv3_src. This glob therefore resolves to nothing on BOTH matrix
    # rows today. Do NOT repoint it at Tools/OpenSSLv3: the pinned Qt 5.15.2
    # open-source Windows build dlopens the literal names libssl-1_1-x64 /
    # libcrypto-1_1-x64 and cannot load OpenSSL 3, and Qt 6 does not need OpenSSL
    # at all (it falls back to its Schannel TLS backend by design). The Qt 5
    # DLLs come from OPENSSL_EXTRA_LIB_DIR instead -- see .github/workflows/ci-win.yml,
    # which builds OpenSSL 1.1.1w from source for that variant.
    set(OPENSSL_ROOT_DIR "${QT_TOOLS_DIR}/OpenSSL/Win_x64" CACHE STRING "OpenSSL dir")
    file(GLOB OPENSSL_LIBS_FILES "${OPENSSL_ROOT_DIR}/bin/lib*.dll")
    cmake_path(NORMAL_PATH OPENSSL_LIBS_FILES OUTPUT_VARIABLE OPENSSL_LIBS_FILES)
    install(FILES ${OPENSSL_LIBS_FILES} DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)

    message(STATUS "OpenSSLExtraLIBDIR:${OPENSSL_EXTRA_LIB_DIR}")
    file(GLOB OPENSSL_EXTRA_LIB_FILES "${OPENSSL_EXTRA_LIB_DIR}/lib*.dll")
    cmake_path(NORMAL_PATH OPENSSL_EXTRA_LIB_FILES OUTPUT_VARIABLE OPENSSL_EXTRA_LIB_FILES)
    message(STATUS "OpenSSLExtraLibFiles:${OPENSSL_EXTRA_LIB_FILES}")
    install(FILES ${OPENSSL_EXTRA_LIB_FILES} DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)

    # Both install() calls above are OPTIONAL, so an empty or broken glob is a
    # SILENT no-op: the build stays green and the package ships with no working
    # TLS. That is exactly how 4.4.2's Windows 7 variant shipped.
    #
    # Collect what those two globs will actually install, so the checks below key
    # off the real install list rather than re-deriving it.
    set(_vx_found_ssl "")
    foreach(_f IN LISTS OPENSSL_LIBS_FILES OPENSSL_EXTRA_LIB_FILES)
        get_filename_component(_n "${_f}" NAME)
        list(APPEND _vx_found_ssl "${_n}")
    endforeach()

    # The licence obligation follows the BINARIES, not the architecture. The two
    # globs above are gated by neither Qt major nor word size, so keying this off
    # the -x64 names would let a 32-bit Qt 5 build (libssl-1_1.dll) or a Qt 6
    # build pointed at an OpenSSL dir ship the DLLs with no notice -- reopening
    # the very 4.4.2 gap this exists to close. OpenSSL 1.1.1's dual
    # OpenSSL/SSLeay licence requires reproducing the notice with binary
    # redistribution, so a missing notice is FATAL rather than OPTIONAL.
    if(WIN32 AND _vx_found_ssl)
        if(NOT OPENSSL_LICENSE_FILE)
            message(FATAL_ERROR
                "This package ships OpenSSL (${_vx_found_ssl}), whose licence requires the "
                "notice to be redistributed with the binaries. Point -DOPENSSL_LICENSE_FILE= "
                "at the OpenSSL source tree's LICENSE file.")
        endif()
        if(NOT EXISTS "${OPENSSL_LICENSE_FILE}")
            message(FATAL_ERROR
                "OPENSSL_LICENSE_FILE=${OPENSSL_LICENSE_FILE} does not exist.")
        endif()
        # LICENSE.OpenSSL lands at the package root, which package/prune-package.cmake
        # (bin/, include/, lib/, mkspecs/, cmark.exe) and the "no stray executable"
        # gate (*.exe only) both leave alone.
        install(FILES "${OPENSSL_LICENSE_FILE}" DESTINATION "${CMAKE_INSTALL_BINDIR}"
                RENAME "LICENSE.OpenSSL")
    endif()

    # Qt 5 on Windows has no Schannel fallback, so the packaged build MUST carry
    # the EXACT pair by name rather than merely "some lib*.dll".
    #
    # Default ON so CI is safe by default and a future workflow edit cannot
    # silently drop the gate; a contributor building Qt 5 locally without OpenSSL
    # opts out explicitly with -DVNOTE_REQUIRE_BUNDLED_OPENSSL=OFF. This runs at
    # CONFIGURE time (Packaging.cmake is included unconditionally), so without the
    # opt-out it would also block plain local builds that never package.
    #
    # The -x64 suffix is architecture-specific, hence the CMAKE_SIZEOF_VOID_P
    # guard: a 32-bit Qt 5 build produces libssl-1_1.dll / libcrypto-1_1.dll and
    # must not be killed by an error demanding names it can never produce. CI
    # only builds x64, so no 32-bit branch is provided -- but this check does not
    # claim jurisdiction over it either.
    #
    # IN_LIST needs CMP0057 NEW, already supplied by cmake_minimum_required(3.20).
    option(VNOTE_REQUIRE_BUNDLED_OPENSSL
           "Fail configuration when a Qt 5 Windows x64 build would ship without OpenSSL" ON)
    if(WIN32 AND (QT_DEFAULT_MAJOR_VERSION EQUAL 5) AND (CMAKE_SIZEOF_VOID_P EQUAL 8))
        if(VNOTE_REQUIRE_BUNDLED_OPENSSL)
            foreach(_need IN ITEMS libssl-1_1-x64.dll libcrypto-1_1-x64.dll)
                if(NOT _need IN_LIST _vx_found_ssl)
                    message(FATAL_ERROR
                        "Qt 5 on Windows has no Schannel TLS backend and MUST ship ${_need}. "
                        "OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR} "
                        "OPENSSL_EXTRA_LIB_DIR=${OPENSSL_EXTRA_LIB_DIR} yielded: ${_vx_found_ssl}. "
                        "Pass -DVNOTE_REQUIRE_BUNDLED_OPENSSL=OFF for a local build that does "
                        "not need working HTTPS.")
                endif()
            endforeach()
        else()
            message(WARNING
                "VNOTE_REQUIRE_BUNDLED_OPENSSL=OFF: this Qt 5 Windows build may ship without "
                "OpenSSL, in which case HTTPS (update check, image hosting) will not work.")
        endif()
    endif()

    set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)

    # NOTE: CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION is pinned in the top-level
    # CMakeLists.txt, before add_subdirectory(libs). It has to be set there
    # rather than here because cmark includes this same module earlier, and the
    # module defaults the destination to "bin" whenever it is unset.

    # InstallRequiredSystemLibraries is CMake-version-bound: for a toolset newer
    # than the running CMake (e.g. VS 18 / MSVC v145 under CMake 3.30) it mis-maps
    # MSVC_TOOLSET_VERSION to 143, looks for a non-existent "Microsoft.VC143.CRT"
    # folder under a "MSVC_REDIST_DIR-NOTFOUND" path, and emits a noisy "system
    # runtime library file does not exist" warning for every CRT DLL while
    # bundling nothing. Silence those warnings; the module still resolves the
    # UCRT / MFC pieces and, on a toolset it DOES understand, the VC CRT.
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_NO_WARNINGS TRUE)
    include(InstallRequiredSystemLibraries)

    # Because the warnings above are suppressed, a failure to resolve the UCRT
    # redist is SILENT here. On the Qt 5 / Windows 7 variant that is not cosmetic:
    # OpenSSL imports ucrtbase + the api-ms-win-crt-* apisets, which are OS
    # components on Windows 10+ but must be BUNDLED for Windows 7. Without this
    # assertion the omission would only surface in CI's post-extraction
    # dependency check -- at the last gate of a ~1 h release build, as a list of
    # missing apiset names that points nowhere near the real cause.
    if(WIN32 AND (QT_DEFAULT_MAJOR_VERSION EQUAL 5) AND (CMAKE_SIZEOF_VOID_P EQUAL 8)
       AND VNOTE_REQUIRE_BUNDLED_OPENSSL)
        set(_vx_have_ucrt FALSE)
        foreach(_f IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
            get_filename_component(_n "${_f}" NAME)
            if(_n MATCHES "^(ucrtbase\\.dll|api-ms-win-crt-.*\\.dll)$")
                set(_vx_have_ucrt TRUE)
                break()
            endif()
        endforeach()
        if(NOT _vx_have_ucrt)
            message(FATAL_ERROR
                "InstallRequiredSystemLibraries resolved no UCRT redistributable "
                "(CMAKE_INSTALL_UCRT_LIBRARIES is TRUE, but CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "
                "contains no ucrtbase.dll / api-ms-win-crt-*.dll). The Windows 7 package must "
                "bundle it: OpenSSL and vnote.exe both import those apisets, and Windows 7 has "
                "no in-box UCRT. Install the Windows SDK's UCRT redist on the build machine.")
        endif()
    endif()

    # Fallback ONLY when the module failed to resolve the VC C runtime (unknown
    # toolset): locate the real "Microsoft.VC*.CRT" redist folder from the
    # compiler path and install its DLLs ourselves. Gating on the module having
    # failed keeps it the sole CRT installer for known toolsets, so a machine
    # with several toolsets never gets two competing / mismatched install rules.
    if(MSVC AND (NOT DEFINED MSVC_CRT_DIR OR NOT EXISTS "${MSVC_CRT_DIR}"))
        # .../VC/Tools/MSVC/<ver>/bin/Host<arch>/<target-arch>/cl.exe
        get_filename_component(_vc_arch_dir "${CMAKE_CXX_COMPILER}" DIRECTORY) # .../<target-arch>
        get_filename_component(_vc_redist_arch "${_vc_arch_dir}" NAME)        # x64 / x86 / arm / arm64
        get_filename_component(_vc_root "${_vc_arch_dir}" DIRECTORY)          # .../Host<arch>
        get_filename_component(_vc_root "${_vc_root}" DIRECTORY)              # .../bin
        get_filename_component(_vc_root "${_vc_root}" DIRECTORY)              # .../<ver>
        get_filename_component(_vc_root "${_vc_root}" DIRECTORY)              # .../MSVC
        get_filename_component(_vc_root "${_vc_root}" DIRECTORY)              # .../Tools
        get_filename_component(_vc_root "${_vc_root}" DIRECTORY)              # .../VC

        file(GLOB _vc_crt_dirs
            "${_vc_root}/Redist/MSVC/*/${_vc_redist_arch}/Microsoft.VC*.CRT")
        if(_vc_crt_dirs)
            list(SORT _vc_crt_dirs COMPARE NATURAL)
            list(GET _vc_crt_dirs -1 _vc_crt_dir) # highest version
            file(GLOB _vc_crt_dlls "${_vc_crt_dir}/*.dll")
            install(FILES ${_vc_crt_dlls} DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL)
            message(STATUS "Bundling MSVC CRT from: ${_vc_crt_dir}")
        else()
            message(WARNING "MSVC CRT redist not found under ${_vc_root}/Redist"
                            " - the packaged app may require the VC++ redistributable")
        endif()
    endif()
endfunction()

set(CPACK_PACKAGE_VENDOR "VNoteX")
set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_CONTACT "Le Tan <tamlokveer@gmail.com>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${PROJECT_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/COPYING.LESSER")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

set(CPACK_PACKAGE_INSTALL_DIRECTORY "${PROJECT_NAME}")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}")

# Start menu entry on Windows
set(CPACK_PACKAGE_EXECUTABLES "vnote" "VNote")
# Desktop link on Windows
set(CPACK_CREATE_DESKTOP_LINKS "vnote")

set(CPACK_STRIP_FILES TRUE)

# WIX generator
set(CPACK_WIX_UPGRADE_GUID BA25F337-991A-4893-9D8A-AD5E89BAF5C4)
set(CPACK_WIX_PRODUCT_GUID BA25F337-991A-4893-9D8A-AD5E89BAF5C4)
set(CPACK_WIX_LICENSE_RTF "${PROJECT_SOURCE_DIR}/package/lgpl-3.0.rtf")
set(CPACK_WIX_PRODUCT_ICON "${CMAKE_CURRENT_LIST_DIR}/data/core/icons/vnote.ico")
set(CPACK_WIX_UI_BANNER "${PROJECT_SOURCE_DIR}/package/wix_banner.png")
set(CPACK_WIX_UI_DIALOG "${PROJECT_SOURCE_DIR}/package/wix_dialog.png")

#------------------------------------------------------------------------------
# include CPack, so we get target for packages
set(CPACK_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/BundleConfig.cmake")

add_custom_target(pack
                  COMMAND ${CMAKE_CPACK_COMMAND} "--config" "${CMAKE_BINARY_DIR}/BundleConfig.cmake" "--verbose"
                  COMMENT "Running CPACK. Please wait..."
                  DEPENDS vnote)
# CPack installs the upstream CLI before Windows package pruning removes it.
set(VX_PACK_DEPS lrelease cmark_exe)
if(VTEXTEDIT_ENABLE_TYPST)
    list(APPEND VX_PACK_DEPS vnote_typst_runtime prepare_typst_notices)
endif()
add_dependencies(pack ${VX_PACK_DEPS})

set(CPACK_GENERATOR)

set(CPACK_PACKAGE_ICON "${CMAKE_CURRENT_LIST_DIR}/data/core/logo/64x64/vnote.png")

if(WIN32)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${QT_BIN_DIR}" DOC "Path to the windeployqt utility")

    list(APPEND CPACK_GENERATOR ZIP)
    message(STATUS "Package generation - Windows - Zip")

    # cmark and QtKeychain install headers, import libs, CMake package configs
    # and a qmake .pri unconditionally, and neither can be switched off from
    # here. Strip them from the staging tree after CPack installs and before it
    # packages, so the shipped ZIP/MSI carry runtime files only. Packaging-time
    # only: a plain `cmake --install` is untouched.
    set(CPACK_PRE_BUILD_SCRIPTS "${PROJECT_SOURCE_DIR}/package/prune-package.cmake")

    if(WIN32 AND (QT_DEFAULT_MAJOR_VERSION GREATER 5))
        find_program(WIX_EXECUTABLE wix HINTS "${QT_BIN_DIR}" DOC "Path to the WiX utility")

        if (NOT WIX_EXECUTABLE-NOTFOUND)
            list(APPEND CPACK_GENERATOR WIX)
            message(STATUS "Package generation - Windows - WiX")
        endif()
    endif()

    windeployqt(vnote)
elseif(APPLE)
    # Manually copy resources. The bundle Info.plist is NOT copied here: it is
    # wired into the target through MACOSX_BUNDLE_INFO_PLIST (see
    # src/CMakeLists.txt), so the built bundle and the packaged bundle always
    # carry the same plist (including the NSServices declaration).
    # macOS packages the build bundle rather than install(TARGETS). Deploy the
    # required native dependency before Qt scans the bundle, then repair and
    # inspect actual linked names (including VTextEdit's versioned ABI filename).
    set(_vx_typst_bundle_script [=[
function(run_checked)
    execute_process(COMMAND ${ARGV} RESULT_VARIABLE result)
    if(NOT result STREQUAL "0")
        message(FATAL_ERROR "Bundle deployment failed (${result}): ${ARGV}")
    endif()
endfunction()
set(app "$<TARGET_BUNDLE_DIR:vnote>")
set(executable "$<TARGET_FILE:vnote>")
set(frameworks "${app}/Contents/Frameworks")
set(editor "${frameworks}/$<TARGET_SONAME_FILE_NAME:VTextEdit>")
set(native "${frameworks}/$<TARGET_FILE_NAME:VTextEditTypst>")
file(MAKE_DIRECTORY "${frameworks}")
run_checked("@CMAKE_COMMAND@" -E copy_if_different "$<TARGET_FILE:VTextEdit>" "${editor}")
run_checked("@CMAKE_COMMAND@" -E copy_if_different "$<TARGET_FILE:VTextEditTypst>" "${native}")
run_checked(/usr/bin/install_name_tool -id "@rpath/$<TARGET_SONAME_FILE_NAME:VTextEdit>" "${editor}")
run_checked(/usr/bin/install_name_tool -id "@rpath/$<TARGET_FILE_NAME:VTextEditTypst>" "${native}")
foreach(binary IN ITEMS "${executable}" "${editor}")
    execute_process(COMMAND /usr/bin/otool -arch all -L "${binary}"
        OUTPUT_VARIABLE linked RESULT_VARIABLE result)
    if(NOT result STREQUAL "0")
        message(FATAL_ERROR "Cannot inspect bundle dependency: ${binary}")
    endif()
    string(REPLACE "\n" ";" lines "${linked}")
    foreach(line IN LISTS lines)
        if(line MATCHES "^[ \t]+([^ \t]+/(libVTextEdit(\\.[0-9]+)*\\.dylib|libvtextedit_typst\\.1\\.dylib))[ \t]+\\(")
            set(old_name "${CMAKE_MATCH_1}")
            set(new_name "@rpath/${CMAKE_MATCH_2}")
            if(NOT old_name STREQUAL new_name)
                run_checked(/usr/bin/install_name_tool -change "${old_name}" "${new_name}" "${binary}")
            endif()
        endif()
    endforeach()
endforeach()
run_checked("@MACDEPLOYQT_EXECUTABLE@" "${app}" -always-overwrite -verbose=1)
foreach(binary IN ITEMS "${executable}" "${editor}" "${native}")
    execute_process(COMMAND /usr/bin/otool -arch all -l "${binary}"
        OUTPUT_VARIABLE commands RESULT_VARIABLE result)
    if(NOT result STREQUAL "0")
        message(FATAL_ERROR "Cannot inspect bundle rpaths: ${binary}")
    endif()
    string(REGEX MATCHALL "path [^\n]+ \\(offset [0-9]+\\)" rpaths "${commands}")
    list(REMOVE_DUPLICATES rpaths)
    foreach(entry IN LISTS rpaths)
        string(REGEX REPLACE "^path (.+) \\(offset [0-9]+\\)$" "\\1" rpath "${entry}")
        if(NOT rpath MATCHES "^(@rpath/|@loader_path|@executable_path|/System/Library/|/usr/lib/)")
            run_checked(/usr/bin/install_name_tool -delete_rpath "${rpath}" "${binary}")
        endif()
    endforeach()
    run_checked(/usr/bin/otool -arch all -L "${binary}")
endforeach()
execute_process(COMMAND /usr/bin/otool -arch all -L "${editor}"
    OUTPUT_VARIABLE linked RESULT_VARIABLE result)
if(NOT result STREQUAL "0" OR NOT linked MATCHES "@rpath/libvtextedit_typst\\.1\\.dylib")
    message(FATAL_ERROR "Packaged VTextEdit does not link the bundled Typst ABI: ${linked}")
endif()
]=])
    string(CONFIGURE "${_vx_typst_bundle_script}" _vx_typst_bundle_script @ONLY)
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/typst-bundle-$<CONFIG>.cmake"
        CONTENT "${_vx_typst_bundle_script}")
    set(VX_BUNDLE_CONTENTS_DIR $<TARGET_FILE_DIR:vnote>/..)
    add_custom_target(deploy
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${VX_EXTRA_RESOURCE_FILES_RCC} ${VX_BUNDLE_CONTENTS_DIR}/Resources
        COMMAND ${CMAKE_COMMAND} -E make_directory ${VX_BUNDLE_CONTENTS_DIR}/Resources/translations
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${VX_QM_FILES} ${VX_BUNDLE_CONTENTS_DIR}/Resources/translations
        COMMAND ${CMAKE_COMMAND} -E make_directory ${VX_BUNDLE_CONTENTS_DIR}/Resources/licenses/typst
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${VX_TYPST_NOTICES_DIR}" ${VX_BUNDLE_CONTENTS_DIR}/Resources/licenses/typst
        COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_BINARY_DIR}/typst-bundle-$<CONFIG>.cmake"
        COMMAND ${CMAKE_COMMAND} "-DVNOTE_APP_DIR=$<TARGET_BUNDLE_DIR:vnote>"
            -P "${PROJECT_SOURCE_DIR}/package/prune-macos-package.cmake"
        COMMENT "Deploying resources and native libraries into ${VX_BUNDLE_CONTENTS_DIR}"
        DEPENDS vnote lrelease vnote_typst_runtime prepare_typst_notices
    )
    add_dependencies(pack deploy)

    message(STATUS "MACDeployQtExecutable: ${MACDEPLOYQT_EXECUTABLE}")
    if (MACDEPLOYQT_EXECUTABLE)
        message(STATUS "Package generation - MacOS - DMG")

        list(APPEND CPACK_GENERATOR External)
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/CPackMacDeployQt.cmake.in "${CMAKE_BINARY_DIR}/CPackExternal.cmake" @ONLY)
        set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
        include(InstallRequiredSystemLibraries)
    endif()
else()
    # VX_TYPST_NOTICES_DIR is only defined when the Typst backend is built.
    # With the variable empty, "${VX_TYPST_NOTICES_DIR}/" degenerates to "/"
    # and CPack starts staging the whole filesystem root into
    # licenses/vnote/typst (seen as copies of /proc on the Qt 5.15 AppImage
    # leg). The Qt 5.15 / Windows 7 variant ships neither backend nor notices.
    if(VTEXTEDIT_ENABLE_TYPST)
        install(DIRECTORY "${VX_TYPST_NOTICES_DIR}/"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/vnote/typst")
    endif()
    message(STATUS "LinuxDeployExecutable: ${LINUXDEPLOY_EXECUTABLE}")
    if(LINUXDEPLOY_EXECUTABLE)
        message(STATUS "Package generation - Linux - AppImage")

        list(APPEND CPACK_GENERATOR External)
        set(VX_APPIMAGE_DEST_DIR "${CPACK_PACKAGE_DIRECTORY}/_CPack_Packages/Linux/External/AppImage")
        set(VX_APPIMAGE_DESKTOP_FILE "${VX_APPIMAGE_DEST_DIR}${CMAKE_INSTALL_PREFIX}/share/applications/vnote.desktop")
        # linuxdeploy aborts when a -l path is missing or its own dependencies
        # cannot be resolved. The OpenSSL 3 pair lives in /usr/local/lib64 only
        # on CI images that build it from source; append it only when present
        # so other toolchains (e.g. EL8's distro Qt 5.15 + system OpenSSL 1.1)
        # can run `pack` too. The GTK3 platform theme plugin ships with many Qt
        # builds (including EL8's), but bundling it also requires GTK3 itself:
        # opt out with VNOTE_DEPLOY_GTK3_THEME=OFF on toolchains without it.
        option(VNOTE_DEPLOY_GTK3_THEME
               "Let linuxdeploy bundle the GTK3 Qt platform theme into the AppImage" ON)
        set(VX_EXTRA_DEPLOY_LIBS "")
        if(VNOTE_DEPLOY_GTK3_THEME AND EXISTS "${QT_PLUGINS_DIR}/platformthemes/libqgtk3.so")
            string(APPEND VX_EXTRA_DEPLOY_LIBS " -l ${QT_PLUGINS_DIR}/platformthemes/libqgtk3.so")
        endif()
        if(EXISTS "/usr/local/lib64/libcrypto.so.3")
            string(APPEND VX_EXTRA_DEPLOY_LIBS " -l /usr/local/lib64/libcrypto.so.3")
        endif()
        if(EXISTS "/usr/local/lib64/libssl.so.3")
            string(APPEND VX_EXTRA_DEPLOY_LIBS " -l /usr/local/lib64/libssl.so.3")
        endif()
        configure_file(${CMAKE_CURRENT_LIST_DIR}/CPackLinuxDeployQt.cmake.in "${CMAKE_BINARY_DIR}/CPackExternal.cmake" @ONLY)
        set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
    endif()
endif()

include(CPack)
