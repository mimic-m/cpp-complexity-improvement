#ifndef COMPANY_INTERNAL_COMMENTS_CHECK_H
#define COMPANY_INTERNAL_COMMENTS_CHECK_H

#include "clang-tidy/ClangTidyCheck.h"
#include "clang/Basic/SourceManager.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Regex.h"

namespace company {
namespace readability {

class CompanyInternalCommentsCheck : public clang::tidy::ClangTidyCheck {
public:
  CompanyInternalCommentsCheck(llvm::StringRef Name,
                               clang::tidy::ClangTidyContext *Context);

  void registerMatchers(clang::ast_matchers::MatchFinder *Finder) override;
  void check(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

private:
  bool hasAdjacentComment(clang::SourceLocation Location,
                          const clang::SourceManager &SourceManager) const;
  bool isComplexIf(const clang::IfStmt *Statement,
                   const clang::ASTContext &Context) const;
  bool isStateAssignment(const clang::BinaryOperator *Operator) const;
  bool isStateSetter(const clang::CallExpr *Call) const;
  bool isStateName(llvm::StringRef Name) const;
  void reportMissingComment(clang::SourceLocation Location,
                            llvm::StringRef Kind);

  bool RequireIfComment;
  bool RequireForComment;
  bool RequireWhileComment;
  bool RequireStateComment;
  bool IgnoreSimpleGuardClause;
  unsigned BooleanOperatorThreshold;
  unsigned MaxBlankLines;
  llvm::Regex StateNames;
  llvm::Regex StateSetters;
};

} // namespace readability
} // namespace company

#endif
