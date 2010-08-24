# - Try to find the Free Pascal Compiler
# Once done this will define
#
#  PASCAL_COMPILER - The FPC binary
#  PASCAL_COMPILER_FLAGS - A set of command-line arguments for FPC you can
#		   set "pascal_compiler_flags_cmn" to extend the list
#		   of flags before running find_package(FPC)
#
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#

# Copyright (c) 2010, Matthias Klumpp <matthias@nlinux.org>
#  and others.
#
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.

set(fpc_tryexe fpc)

find_program(fpc_executable ${fpc_tryexe})

if(fpc_executable)
	 exec_program(${fpc_executable} ARGS "-h" OUTPUT_VARIABLE fpc_output)
endif(fpc_executable)

message(STATUS "Check for working Pascal compiler: ${fpc_executable}")

set(noexecstack_flags "-k-z" "-knoexecstack")
set(checkdir "${CMAKE_CURRENT_BINARY_DIR}/check")
make_directory(${checkdir})

file(WRITE ${checkdir}/checkstack.pas "begin end.")

exec_program(${fpc_executable} ${checkdir}
	ARGS ${noexecstack_flags} checkstack.pas
	OUTPUT_VARIABLE noout
	RETURN_VALUE testnoexecstack
	)

if(${testnoexecstack})
	set (noexecstack_flags "")
endif(${testnoexecstack})

file(REMOVE ${checkdir})

if(APPLE)
	string(REGEX MATCH "[pP][pP][cC]+" powerpc_build "${CMAKE_OSX_ARCHITECTURES}")
	string(REGEX MATCH "[iI]386+" i386_build "${CMAKE_OSX_ARCHITECTURES}")
	string(REGEX MATCH "[xX]86_64+" x86_64_build "${CMAKE_OSX_ARCHITECTURES}")

	if(powerpc_build)
		set(powerpc_build "powerpc")
	endif()
endif(APPLE)


#PASCAL DETECTION SECTION
string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" fpc_ver "${fpc_output}")

if(fpc_ver)
	string(REGEX REPLACE "([0-9]+)\\.[0-9]+\\.[0-9]+" "\\1" fpc_vers_major "${fpc_ver}")
	string(REGEX REPLACE "[0-9]+\\.([0-9]+)\\.[0-9]+" "\\1" fpc_vers_minor "${fpc_ver}")
	string(REGEX REPLACE "[0-9]+\\.[0-9]+\\.([0-9]+)" "\\1" fpc_vers_patch "${fpc_ver}")
	message(STATUS "Check for working Pascal compiler: ${fpc_executable} -- works")
	message(STATUS "FPC version is: ${fpc_vers_major}.${fpc_vers_minor}")
	math(EXPR FPC_VERSION "${fpc_vers_major}*10000 + ${fpc_vers_minor}*100 + ${fpc_vers_patch}")
else()
	message(FATAL_ERROR "FPC compiler was not found!")
endif()

set(PASCAL_COMPILER ${fpc_executable})
set(PASCAL_COMPILER_FLAGS "-MObjFPC" "-Scghi" "-O1" "-gl" "-XX" "-vewnhi" "-l"
			  "-Fi${CMAKE_CURRENT_BINARY_DIR}"
			  "-FU${CMAKE_CURRENT_BINARY_DIR}"
			  ${noexecstack_flags} ${pascal_compiler_flags_cmn})
