void set_state(int);

void fail_cases(bool enabled, bool valid, int state) {
  if (enabled && valid) {
  }

  for (int i = 0; i < 3; ++i) {
  }

  while (enabled) {
    enabled = false;
  }

  state = 2;
  set_state(3);
}

void unrelated_comment(bool enabled, bool valid) {
  // This describes a previous operation.
  enabled = valid;
  if (enabled && valid) {
  }
}

void nested(bool outer, bool first, bool second) {
  // The outer condition does not describe the nested condition.
  if (outer) {
    if (first && second) {
    }
  }
}
