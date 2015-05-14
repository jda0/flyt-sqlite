module.exports = config = {}

config.MANDRILL_EMAIL = ''
config.MANDRILL_KEY   = ''
config.SECRET         = ''

config.ACL_FLAGS =
  'READ'            : 1
  'ADD_REPORTS'     : 2
  'EDIT_REPORTS'    : 4
  'DELETE_REPORTS'  : 8
  'ADD_PEOPLE'      : 16
  'EDIT_PEOPLE'     : 32
  'VOID_PEOPLE'     : 64
  'ADD_GROUPINGS'   : 128
  'EDIT_GROUPINGS'  : 256
  'TRUST_USERS'     : 8192
  'VOID_USERS'      : 16384
  'SET_ACL'         : 32768

config.ROLES =
  'Read Only' : 1
  'Limited'   : 3
  'Moderator' : 8703
  'Admin'     : 65535

config.REPORT_TYPES = [
  'SeriousConcern'
  'MinorConcern'
  'Praise'
  'Award'
  'Event'
]