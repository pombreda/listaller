# CMakeLists to install Listaller's mime data

set (XDG_MIME_INSTALL_DIR "share/mime/packages")

find_program (LC_INTLTOOL_MERGE intltool-merge)
mark_as_advanced (LC_INTLTOOL_MERGE)

if (LC_INTLTOOL_MERGE STREQUAL "LC_INTLTOOL_MERGE-NOTFOUND")
	message (FATAL_ERROR "Intltool was not found! Please install it to continue!")
endif (LC_INTLTOOL_MERGE STREQUAL "LC_INTLTOOL_MERGE-NOTFOUND")

add_custom_target (merge-l10n ALL
	${LC_INTLTOOL_MERGE} -x ${CMAKE_SOURCE_DIR}/po
		${CMAKE_CURRENT_SOURCE_DIR}/listaller-ipk.xml.in
		${CMAKE_CURRENT_BINARY_DIR}/listaller-ipk.xml
	DEPENDS listaller-ipk.xml.in
	WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/listaller-ipk.xml
	DESTINATION ${XDG_MIME_INSTALL_DIR}
	COMPONENT data
)

#install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/listaller-ips.xml
#	DESTINATION share/mime/packages/
#	COMPONENT data)
