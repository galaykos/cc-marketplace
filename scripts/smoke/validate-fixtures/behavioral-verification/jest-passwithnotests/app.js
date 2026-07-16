// Code file for the jest --passWithNoTests defect class. The behavioral gate
// classifies this as JS and resolves the package.json test script to verify it —
// the script uses --passWithNoTests, which the gate must refuse to trust.
module.exports = () => 42;
