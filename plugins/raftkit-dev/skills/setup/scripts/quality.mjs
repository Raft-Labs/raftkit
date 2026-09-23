// The one definition of a quality gate script: test, lint or typecheck, alone
// or with a `:` or `.` suffix (test:unit, lint.ci). detect-toolchain.mjs reports
// only these, and merge-settings.mjs allowlists only these.
export const QUALITY = /^(lint|typecheck|test)([:.].*)?$/;
