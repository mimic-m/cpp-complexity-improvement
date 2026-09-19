cmake_minimum_required(VERSION 3.16)
project(company_internal_comments LANGUAGES CXX)

find_package(LLVM CONFIG REQUIRED)
find_package(Clang CONFIG REQUIRED)
if(LLVM_PACKAGE_VERSION VERSION_LESS 18)
  message(FATAL_ERROR "LLVM/Clang 18 or newer is required")
endif()

find_program(BASH_EXECUTABLE NAMES bash)
if(NOT BASH_EXECUTABLE)
  message(FATAL_ERROR "bash is required to run the tests")
endif()
set(CLANG_TIDY_EXECUTABLE "${LLVM_TOOLS_BINARY_DIR}/clang-tidy" CACHE FILEPATH
  "clang-tidy from the same LLVM installation used to build the plugin")

add_library(company_internal_comments MODULE
  src/CompanyInternalCommentsCheck.cpp
  src/CompanyInternalCommentsModule.cpp
)
target_include_directories(company_internal_comments PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${LLVM_INCLUDE_DIRS}
  ${CLANG_INCLUDE_DIRS}
)
target_compile_features(company_internal_comments PRIVATE cxx_std_17)
target_compile_definitions(company_internal_comments PRIVATE ${LLVM_DEFINITIONS})
target_link_libraries(company_internal_comments PRIVATE clangTidy clangAST clangASTMatchers clangBasic clangLex)
set_target_properties(company_internal_comments PROPERTIES PREFIX "" OUTPUT_NAME "company-internal-comments")

add_custom_target(company_internal_comments_tests
  COMMAND "${BASH_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/run-tests.sh"
    $<TARGET_FILE:company_internal_comments> "${CLANG_TIDY_EXECUTABLE}"
  DEPENDS company_internal_comments
  USES_TERMINAL
  VERBATIM
)
