void set_state(int);

void pass_cases(bool enabled, bool valid, int state) {
  // Explain why this compound condition controls entry.
  if (enabled && valid && state >= 0) {
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
  // Notify the controller after recording the local transition.
  set_state(3);
}

void simple_guard(int *value) {
  if (value == nullptr)
    return;
}

void nolint_case(bool enabled, bool valid, bool ready) {
  if (enabled && valid && ready) { // NOLINT(company-internal-comments)
  }
}

void below_threshold(bool enabled, bool valid) {
  if (enabled && valid) {
  }
}

struct Callable {
  void operator()() const;
  Callable operator+(const Callable &) const;
};

void operator_calls(Callable value) {
  value();
  (void)(value + value);
}
