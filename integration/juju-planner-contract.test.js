const assert = require('assert')
const { buildPlannerRequest } = require('./juju-planner-contract')

const request = buildPlannerRequest({
  members: [
    { id: 'u_a', availability: [{ date: '2026-10-10', startMinute: 1080, endMinute: 1260 }], interests: ['ai'] },
    { id: 'u_b', availability: [{ date: '2026-10-10', startMinute: 1140, endMinute: 1260 }], interests: ['robotics'] }
  ],
  options: [{
    id: 'campus-ai',
    window: { date: '2026-10-10', startMinute: 1140, endMinute: 1200 },
    interest: 'ai',
    venue: { name: '大学城校区', commuteMinutes: [12, null] }
  }],
  rules: { requiredMemberIds: ['u_a'] }
})

assert.strictEqual(request.version, 'juju-planner-request/v1')
assert.strictEqual(request.options[0].venue.commuteMinutes[1], null)
assert.throws(() => buildPlannerRequest({ members: request.members, options: [] }))
console.log('juju planner contract: ok')
