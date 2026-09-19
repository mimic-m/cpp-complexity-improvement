#include "CompanyInternalCommentsCheck.h"
#include "clang-tidy/ClangTidyModule.h"
#include "clang-tidy/ClangTidyModuleRegistry.h"

namespace company {
namespace readability {

class CompanyInternalCommentsModule : public clang::tidy::ClangTidyModule {
public:
  void addCheckFactories(clang::tidy::ClangTidyCheckFactories &Factories) override {
    Factories.registerCheck<CompanyInternalCommentsCheck>(
        "company-internal-comments");
  }
};

} // namespace readability
} // namespace company

static clang::tidy::ClangTidyModuleRegistry::Add<
    company::readability::CompanyInternalCommentsModule>
    X("company-internal-comments-module", "Adds company comment checks.");

volatile int CompanyInternalCommentsModuleAnchorSource = 0;
