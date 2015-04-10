## Add source code
add_files ${PROJ_DIR}/src/arp_reply.cpp
add_files ${PROJ_DIR}/src/icmp_server.cpp
add_files ${PROJ_DIR}/src/ip_handler.cpp
add_files ${PROJ_DIR}/src/loopback.cpp
add_files ${PROJ_DIR}/src/merge.cpp
add_files ${PROJ_DIR}/src/TcpHlsCore.cpp

## Add testbed files
add_files -tb ${PROJ_DIR}/src/TcpHlsCore_test.cpp
