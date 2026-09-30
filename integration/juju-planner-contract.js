/**
 * Stable request normalizer for the future 聚聚星 -> planner boundary.
 *
 * It intentionally does not call a map service, CloudBase, or a MoonBit
 * runtime.  The mini-program owns identity and consent; a server-side adapter
 * can pass this small, pseudonymous payload to the MoonBit decision core.
 */
function validWindow(window) {
  return window &&
    /^\d{4}-\d{2}-\d{2}$/.test(String(window.date || '')) &&
    Number.isInteger(window.startMinute) &&
    Number.isInteger(window.endMinute) &&
    window.startMinute >= 0 && window.endMinute <= 1440 &&
    window.startMinute < window.endMinute
}

function normalizeWindow(window) {
  if (!validWindow(window)) throw new Error('Invalid availability or option time window')
  return {
    date: String(window.date),
    startMinute: window.startMinute,
    endMinute: window.endMinute
  }
}

function normalizeMember(member) {
  const availability = Array.isArray(member && member.availability) ? member.availability : []
  const interests = Array.isArray(member && member.interests) ? member.interests : []
  const id = String(member && member.id || '').trim()
  if (!id) throw new Error('Each member needs a pseudonymous id')
  if (!availability.length) throw new Error(`Member ${id} has no availability`)
  return {
    id,
    availability: availability.map(normalizeWindow),
    interests: interests.map(item => String(item).trim()).filter(Boolean)
  }
}

function normalizeOption(option, memberCount) {
  const commuteMinutes = Array.isArray(option && option.venue && option.venue.commuteMinutes)
    ? option.venue.commuteMinutes
    : []
  const id = String(option && option.id || '').trim()
  const interest = String(option && option.interest || '').trim()
  const venueName = String(option && option.venue && option.venue.name || '').trim()
  if (!id || !interest || !venueName) throw new Error('Each option needs id, interest, and venue name')
  if (commuteMinutes.length !== memberCount) throw new Error(`Option ${id} needs one commute value per member`)
  return {
    id,
    window: normalizeWindow(option.window),
    interest,
    venue: {
      name: venueName,
      // null is preserved as unknown; it must never be coerced to a large cost.
      commuteMinutes: commuteMinutes.map(value => value === null ? null : Number(value))
    }
  }
}

function buildPlannerRequest(input = {}) {
  const members = (Array.isArray(input.members) ? input.members : []).map(normalizeMember)
  if (members.length < 2) throw new Error('A group decision needs at least two members')
  const options = (Array.isArray(input.options) ? input.options : [])
    .map(option => normalizeOption(option, members.length))
  if (!options.length) throw new Error('At least one activity option is required')
  const suppliedRules = input.rules || {}
  const rules = {
    minParticipants: Math.max(2, Number(suppliedRules.minParticipants || 2)),
    requiredMemberIds: Array.isArray(suppliedRules.requiredMemberIds)
      ? suppliedRules.requiredMemberIds.map(String)
      : [],
    requireEveryone: Boolean(suppliedRules.requireEveryone),
    maxTravelMinutes: Math.max(1, Number(suppliedRules.maxTravelMinutes || 45))
  }
  return { version: 'juju-planner-request/v1', members, options, rules }
}

module.exports = { buildPlannerRequest }
