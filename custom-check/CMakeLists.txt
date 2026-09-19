cmake_minimum_required(VERSION 3.16)
project(company_internal_comments LANGUAGES CXX)

find_package(LLVM CONFIG REQUIRED)
find_package(Clang CONFIG REQUIRED)

add_library(company_internal_comments MODULE
  src/CompanyInternalCommentsCheck.cpp
  src/CompanyInternalCommentsModule.cpp
)
target_include_directories(company_internal_comments PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${LLVM_INCLUDE_DIRS}
)
target_compile_features(company_internal_comments PRIVATE cxx_std_17)
target_compile_definitions(company_internal_comments PRIVATE ${LLVM_DEFINITIONS})
target_link_libraries(company_internal_comments PRIVATE clangTidy clangAST clangASTMatchers clangBasic clangLex)
set_target_properties(company_internal_comments PROPERTIES PREFIX "" OUTPUT_NAME "company-internal-comments")

add_custom_target(company_internal_comments_tests
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tests/run-tests.sh $<TARGET_FILE:company_internal_comments>
  DEPENDS company_internal_comments
  USES_TERMINAL
)
