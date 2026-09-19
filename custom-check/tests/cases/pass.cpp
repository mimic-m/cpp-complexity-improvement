void set_state(int);

void pass_cases(bool enabled, bool valid, int state) {
  // Explain why this compound condition controls entry.
  if (enabled && valid) {
  }

  // Explain why every input is inspected.
  for (int i = 0; i < 3; ++i) {
  }

  // Explain the polling condition.
  while (enabled) {
    enabled = false;
  }

  // Explain the externally visible transition.
  state = 2;
  set_state(3);
}

void simple_guard(int *value) {
  if (value == nullptr)
    return;
}

void nolint_case(bool enabled, bool valid) {
  // NOLINTNEXTLINE(company-internal-comments)
  if (enabled && valid) {
  }
}
