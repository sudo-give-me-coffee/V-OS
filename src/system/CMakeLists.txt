
if(NOT BUILDTOOLS STREQUAL "1")
	AddOn(
		root
		SHARED

		LIBS be_bootstrap rt dl pthread ${ZLIB_LIBRARIES}
	)
else()
AddOn(
	root
	SHARED

	LIBS be_build rt dl pthread ${ZLIB_LIBRARIES}
)
endif()

UsePrivateHeaders(root app kernel shared system libroot runtime_loader)

add_subdirectory(kernel_linux)
add_subdirectory(libroot)
