#include "CompanyInternalCommentsCheck.h"

#include "clang/AST/ASTContext.h"
#include "clang/AST/Expr.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/ASTMatchers/ASTMatchFinder.h"

using namespace clang;
using namespace clang::ast_matchers;
using namespace clang::tidy;

namespace {

class BooleanOperatorVisitor
    : public RecursiveASTVisitor<BooleanOperatorVisitor> {
public:
  bool VisitBinaryOperator(const BinaryOperator *Operator) {
    if (Operator->isLogicalOp())
      ++Count;
    return true;
  }

  unsigned Count = 0;
};

} // namespace

namespace company {
namespace readability {

CompanyInternalCommentsCheck::CompanyInternalCommentsCheck(
    StringRef Name, ClangTidyContext *Context)
    : ClangTidyCheck(Name, Context),
      RequireIfComment(Options.get("RequireIfComment", true)),
      RequireForComment(Options.get("RequireForComment", true)),
      RequireWhileComment(Options.get("RequireWhileComment", true)),
      RequireStateComment(Options.get("RequireStateComment", true)),
      IgnoreSimpleGuardClause(Options.get("IgnoreSimpleGuardClause", true)),
      BooleanOperatorThreshold(
          Options.get("BooleanOperatorThreshold", 1U)),
      MaxBlankLines(Options.get("MaxBlankLines", 1U)),
        StateNames(Options.get("StateNamesRegex",
          "^(state|status|mode|phase|step|current_state|next_state|"
          "device_state|machine_state|seq_state|run_mode)$")),
        StateSetters(Options.get("StateSetterRegex",
          "^(set_state|change_state|transition_to|set_status|set_mode|"
          "change_mode)$")) {}

void CompanyInternalCommentsCheck::registerMatchers(MatchFinder *Finder) {
  Finder->addMatcher(ifStmt().bind("if"), this);
  Finder->addMatcher(forStmt().bind("for"), this);
  Finder->addMatcher(whileStmt().bind("while"), this);
  Finder->addMatcher(binaryOperator(isAssignmentOperator()).bind("assignment"),
                     this);
  Finder->addMatcher(callExpr(callee(functionDecl().bind("setter")))
                       .bind("setter_call"),
                   this);
}

void CompanyInternalCommentsCheck::check(const MatchFinder::MatchResult &Result) {
  if (const auto *Statement = Result.Nodes.getNodeAs<IfStmt>("if")) {
    if (RequireIfComment && isComplexIf(Statement, *Result.Context) &&
        !hasAdjacentComment(Statement->getBeginLoc(), *Result.SourceManager))
      reportMissingComment(Statement->getBeginLoc(), "complex if");
    return;
  }

  if (const auto *Statement = Result.Nodes.getNodeAs<ForStmt>("for")) {
    if (RequireForComment &&
      !hasAdjacentComment(Statement->getBeginLoc(), *Result.SourceManager))
      reportMissingComment(Statement->getBeginLoc(), "for");
    return;
  }

  if (const auto *Statement = Result.Nodes.getNodeAs<WhileStmt>("while")) {
    if (RequireWhileComment &&
      !hasAdjacentComment(Statement->getBeginLoc(), *Result.SourceManager))
      reportMissingComment(Statement->getBeginLoc(), "while");
    return;
  }

  if (!RequireStateComment)
    return;

  if (const auto *Assignment = Result.Nodes.getNodeAs<BinaryOperator>("assignment")) {
    if (isStateAssignment(Assignment) &&
        !hasAdjacentComment(Assignment->getBeginLoc(), *Result.SourceManager))
      reportMissingComment(Assignment->getBeginLoc(), "state assignment");
    return;
  }

  if (const auto *Call = Result.Nodes.getNodeAs<CallExpr>("setter_call")) {
    if (isStateSetter(Call) &&
      !hasAdjacentComment(Call->getBeginLoc(), *Result.SourceManager))
      reportMissingComment(Call->getBeginLoc(), "state setter");
  }
}

bool CompanyInternalCommentsCheck::isComplexIf(const IfStmt *Statement,
                                               const ASTContext &) const {
  if (!Statement->getCond())
    return false;

  BooleanOperatorVisitor Visitor;
  Visitor.TraverseStmt(const_cast<Expr *>(Statement->getCond()));
  if (Visitor.Count <= BooleanOperatorThreshold)
    return false;

  if (!IgnoreSimpleGuardClause)
    return true;

  const auto *Condition = Statement->getCond()->IgnoreParenImpCasts();
  const auto *Binary = dyn_cast<BinaryOperator>(Condition);
  return !(Binary && Binary->isComparisonOp());
}

bool CompanyInternalCommentsCheck::isStateAssignment(
    const BinaryOperator *Operator) const {
  if (!Operator->isAssignmentOp())
    return false;
  const auto *LHS = Operator->getLHS()->IgnoreParenImpCasts();
  if (const auto *Reference = dyn_cast<DeclRefExpr>(LHS))
    return isStateName(Reference->getName());
  if (const auto *Member = dyn_cast<MemberExpr>(LHS))
    return isStateName(Member->getMemberDecl()->getName());
  return false;
}

bool CompanyInternalCommentsCheck::isStateSetter(const CallExpr *Call) const {
  const auto *Declaration = Call->getDirectCallee();
  return Declaration && StateSetters.match(Declaration->getName());
}

bool CompanyInternalCommentsCheck::isStateName(StringRef Name) const {
  return StateNames.match(Name);
}

bool CompanyInternalCommentsCheck::hasAdjacentComment(
    SourceLocation Location, const SourceManager &SM) const {
  if (SM.isMacroBodyExpansion(Location) || SM.isMacroArgExpansion(Location))
    return true;

  FileID File;
  unsigned Offset = SM.getDecomposedLoc(SM.getExpansionLoc(Location)).second;
  File = SM.getDecomposedLoc(SM.getExpansionLoc(Location)).first;
  bool Invalid = false;
  StringRef Buffer = SM.getBufferData(File, &Invalid);
  if (Invalid || Offset > Buffer.size())
    return false;

  unsigned End = Offset;
  while (End > 0 && (Buffer[End - 1] == ' ' || Buffer[End - 1] == '\t' ||
                     Buffer[End - 1] == '\r' || Buffer[End - 1] == '\n'))
    --End;
  unsigned BlankLines = 0;
  for (unsigned I = End; I < Offset; ++I)
    if (Buffer[I] == '\n')
      ++BlankLines;
  if (BlankLines > MaxBlankLines)
    return false;

  if (End >= 2 && Buffer.substr(0, End).endswith("*/")) {
    size_t Start = Buffer.substr(0, End - 2).rfind("/*");
    return Start != StringRef::npos;
  }

  size_t LineStart = Buffer.substr(0, End).rfind('\n');
  LineStart = LineStart == StringRef::npos ? 0 : LineStart + 1;
  StringRef Line = Buffer.slice(LineStart, End).trim();
  return Line.startswith("//");
}

void CompanyInternalCommentsCheck::reportMissingComment(SourceLocation Location,
                                                         StringRef Kind) {
  diag(Location, "add a WHY comment before this %0") << Kind;
}

} // namespace readability
} // namespace company
