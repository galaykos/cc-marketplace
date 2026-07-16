// Code file the dead-flag fixture ships alongside demo-tool. It gives the gate a
// real runner target so the suite verdict is an honest "covered" and the ONLY
// defect the gate reports is the dead flag on the entrypoint.
module.exports = () => 'done';
