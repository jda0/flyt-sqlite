# INIT

  config      = require './config'
  fetch       = require './fetches'

  bcrypt      = require 'bcrypt'
  bodyParser  = require 'body-parser'
  express     = require 'express'
  mandrill    = require 'mandrill-api/mandrill'
  moment      = require 'moment'
  session     = require 'express-session'
  sqlite3     = require 'sqlite3'
  validator   = require 'validator'

  app         = express()

  app.use session
    secret: config.SECRET
    cookie:
      secure: false
    resave: true
    saveUninitialized: false
  
  appAPI      = express.Router()
  auth        = express.Router()
  authAPI     = express.Router()

  db          = new sqlite3.Database './nco.db'
  email       = new mandrill.Mandrill config.MANDRILL_KEY
  jsonParser  = bodyParser.json()

  keys        = {}


# AUTH

  auth.manageRedirect = (req, res, next) ->
    if req.session.expiry and Date.now() > req.session.expiry
      delete req.session.expiry
      delete req.session.user

    if not req.session.user
      return res.render 'auth.jade', glob: roles: Object.keys(config.ROLES), i: req.query.i, key: req.query.key

    next()
    
  auth.get '/', (req, res) ->
    return res.render 'auth.jade', glob: roles: Object.keys config.ROLES, i: req.query.i, key: req.query.key

  auth.get '/logout', (req, res) ->
    delete req.session.expiry
    delete req.session.user
    
    if req.session.pass
      delete req.session.pass

    return res.render 'auth.jade', glob:
      message: 'Successfully logged out'
      roles: Object.keys config.ROLES


# AUTH API

  authAPI.manageRedirect = (acl) ->
    return (req, res, next) ->
      console.log req.session.user, req.session.expiry
      
      #if req.session.expiry and Date.now() > req.session.expiry
      #  delete req.session.expiry
      #  delete req.session.user

      if not req.session.user
        return res.json error: 'logged_out'

      if acl and req.session.user.acl & acl is 0
        return res.json error: 'not_allowed'

      next()


  authAPI.post '/register', jsonParser, (req, res) ->
    if not (req.body.email and validator.isEmail req.body.email)
      return res.json error: 'bad_email'

    else if not (req.body.name and req.body.name.length >= 2 and
      req.body.name.split(' ').every (v) -> validator.isAlpha v)
        return res.json error: 'bad_name'

    else if not req.body.role or Object.keys(config.ROLES).indexOf(req.body.role) is -1
      return res.json error: 'bad_role'

    else
      db.run "INSERT INTO User (name, email, acl, pass2, trustee, bio, void)
        VALUES ('#{req.body.name}', '#{req.body.email}',
        #{config.ROLES[req.body.role] or 1}, NULL, NULL,
        '#{req.body.bio or ''}', NULL)"
      , (e) ->
        if e
          console.error 'db_error', e
          return res.json error: 'db_error', data: e
        
        else
          return res.json done: 'registered', data: uid: this.lastID


  authAPI.post '/getKey', jsonParser, (req, res) ->
    if not (req.body.email and validator.isEmail req.body.email)
      return res.json error: 'bad_email'

    else
      db.get "SELECT uid, name, trustee, pass2 FROM User WHERE email='#{req.body.email}'", (e, r) ->
        if e
          console.error 'db_error', e
          return res.json error: 'db_error', data: e
        
        else if not r
          return res.json error: 'unregistered'

        else if not r.trustee
          return res.json error: 'untrusted'
          
        else if r.pass2 and not req.session.pass
          return res.json error: 'password_required'
        
        else
          valid = '123456789ABCDEFGHIJKLMNPQRSTUVWXYZ'
          key = ''
          key += valid[Math.floor Math.random() * (valid.length - 1)] for [0...6]

          bcrypt.hash key, 10, (e, hash) ->
            if e
              console.error 'crypt_error', e
              return res.json error: 'crypt_error', data: e
            else
              if keys.length > 15
                for i in [0...keys.length]
                  if Date.now() > keys[i].expiry
                    delete keys[i]

              expiry = moment().add 1, 'days'

              keys[req.body.email] =
                hash: hash
                expiry: expiry.valueOf()

              app.render 'email.jade',
                logo: "#{req.protocol}://#{req.get 'host'}/static/asset/elogo.png"
                name: r.name.replace(/\ /g, '\u00a0')
                key: key
                expiry: expiry.format('ddd Do MMMM, ha [UTC]')
                link: "#{req.protocol}://#{req.get 'host'}/?i=#{encodeURIComponent req.body.email}&key=#{key}"

              , (er, render) ->
                if er
                  console.error 'render error', er

                edata =
                  text:        "Welcome back, #{r.name}.\n\n
                                Your key is #{key}, and is valid until #{moment().add(1, 'days').format 'ddd Do MMMM, ha'}.\n
                                You can enter the system directly here: #{req.protocol}://#{req.get 'host'}/auth?i=#{encodeURIComponent req.body.email}&key=#{key}\n\n
                                Kind regards,\n
                                Cpl Daly, Developer, Flyt"
                  from_name:    'nco'
                  from_email:   config.MANDRILL_EMAIL
                  to: [
                    name:       r.name
                    email:      req.body.email
                  ]
                  subject:      'Your Flyt key'
                  important:    false
                  tags:         ['tokens']

                if not er
                  edata.html = render

                  email.messages.send message: edata, (r) ->
                    console.log r
                    if r[0].status is 'sent'
                      if req.session.pass
                        delete req.session.pass

                      return res.json done: r[0]
                    
                    else
                      return res.json
                        error: 'send_error'
                        data: r[0].status + ' ' + r[0].reject_reason
                      , (e) ->
                        console.error 'send_error', e
                        return res.json error: 'send_error', data: e.message


  authAPI.post '/withKey', jsonParser, (req, res) ->
    if not (req.body.email and validator.isEmail req.body.email)
      return res.json error: 'bad_email'

    else if not (req.body.key and req.body.key.length is 6 and
      validator.isAlphanumeric req.body.key)
        return res.json error: 'bad_key'

    else if not keys[req.body.email]
      return res.json error: 'key_rejected'

    else if Date.now() > keys[req.body.email].expiry
      delete keys[req.body.email]
      return res.json error: 'key_rejected'

    else
      bcrypt.compare req.body.key, keys[req.body.email].hash, (e, match) ->
        if e
          console.error 'crypt_error', e
          return res.json error: 'crypt_error', date: e

        else if not match
          return res.json error: 'key_rejected'

        else
          db.get "SELECT * FROM User WHERE email='#{req.body.email}'", (e, r) ->
            if e
              console.error 'db_error', e
              res.json error: 'db_error', data: e

            else if not r
              return res.json error: 'unregistered'

            else if not r.trustee
              return res.json error: 'untrusted'

            else
              delete keys[req.body.email]
              
              req.session.expiry = moment().add(30, 'days').valueOf()
              req.session.user = r
              
              return res.json done: 'key_accepted'

  
  authAPI.post '/withPass', jsonParser, (req, res) ->
    if not (req.body.email and validator.isEmail req.body.email)
      return res.json error: 'bad_email'

    else if not (req.body.pass)
        return res.json error: 'bad_pass'

    else
      db.get "SELECT * FROM User WHERE email='#{req.body.email}'", (e, r) ->
        if e
          console.error 'db_error', data: e
        
        else if not r
          return res.json error: 'unregistered'
        
        else
          bcrypt.compare req.body.pass, r.pass2, (e, match) ->
            if e
              console.error 'crypt_error', e
              return res.json error: 'crypt_error', date: e

            else if not match
              return res.json error: 'pass_rejected'

            else
              req.session.pass = req.body.pass
              return res.json done: 'pass_accepted'


  authAPI.post '/entrust', jsonParser, authAPI.manageRedirect(config.ACL_FLAGS.TRUST_USERS), (req, res) ->
    db.run "SELECT uid FROM User WHERE uid='#{req.body.me}'", (e) ->
      if e
        console.error 'db_error', e
        return res.json error: 'db_error', data: e
      
      else if not @lastID
        return res.json error: 'me_not_found'
      
      else
        db.run "UPDATE User SET trustee='#{req.body.me}' WHERE uid='#{req.body.uid}'", (e) ->
          if e
            return res.json error: 'db_error', data: e
          else if not @lastID
            return res.json error: 'unregistered'
          else
            return res.json done: 'entrusted_account'


  authAPI.post '/logout', jsonParser, (req, res) ->
    delete req.session.expiry
    delete req.session.user
    if req.session.pass
      delete req.session.pass

    res.json done: 'logged_out'


# APP API

  appAPI.post '/fetch', jsonParser, authAPI.manageRedirect(config.ACL_FLAGS.READ), (req, res) ->
    if not (req.body.q and fetches[req.body.q])
      return res.json error: 'bad_query'

    else if not req.body.config
      return res.json error: 'bad_config'

    else
      db.all fetches[req.body.q], req.body.config, (e, rs) ->
        if e
          return res.json error: 'db_error', data: e
        else
          return res.json done: 'fetched', data: rs

  appAPI.post '/addPerson', jsonParser, authAPI.manageRedirect(config.ACL_FLAGS.ADD_PERSON), (req, res) ->
    if not (req.body.name and req.body.name.length >= 2 and
      req.body.name.split(' ').every (v) -> validator.isAlpha v)
        return res.json error: 'bad_name'

    else if not (req.body.grouping and validator.isNumeric req.body.grouping)
      return res.json error: 'bad_grouping'

    else
      db.run "INSERT INTO Person (name, grouping)
        VALUES (#{req.body.name}, #{req.body.grouping})", (e, r) ->
          if e
            console.error 'db_error', e
            return res.json error: 'db_error', data: e
          
          else
            return res.json done: 'added_person', data: @lastID


  appAPI.post '/addGrouping', jsonParser, authAPI.manageRedirect(config.ACL_FLAGS.ADD_GROUPING), (req, res) ->
    if not (req.body.name and req.body.name.length >= 2 and
      req.body.name.split(' ').every (v) -> validator.isAlpha v)
        return res.json error: 'bad_name'

    else if not (req.body.colour and validator.isHexColor req.body.colour)
      return res.json error: 'bad_colour'

    else
      db.run "INSERT INTO Grouping (name, colour)
        VALUES (#{req.body.name}, #{req.body.colour})", (e, r) ->
          if e
            console.error 'db_error', e
            return res.json error: 'db_error', data: e
          
          else
            return res.json done: 'added_grouping', data: @lastID


  appAPI.post '/addReport', jsonParser, authAPI.manageRedirect(config.ACL_FLAGS.ADD_REPORTS), (req, res) ->
    if not (req.body.date and validator.isNumeric req.body.date)
      return res.json error: 'bad_date'

    else if not req.body.type or config.REPORT_TYPES.indexOf(req.body.type) is -1
      return res.json error: 'bad_type'

    else if not (req.body.type isnt 'Event' and
      req.body.people.every (v) -> return validator.isNumeric(v[0]) and
      (validator.isNumeric(v[1]) or not v[1]))
        return res.json error: 'bad_people'

    else
      r = null
      e2 = null
      db.exec 'PRAGMA foreign_keys = ON; BEGIN'
        .run "INSERT OR ROLLBACK INTO Report (date, type, body, author)
          VALUES (#{req.body.date}, #{req.body.type}, #{req.body.body or 'NULL'}, #{req.session.user.uid})",
          (e) ->
            if e
              e2 = e
            else
              r = @lastID
        .exec "INSERT OR ROLLBACK INTO ReportSubject (report, person, score)
          VALUES #{(for v in req.body.people
                     "(#{r}, #{v[0]}, #{v[1] or 'NULL'})").join ','}; COMMIT", (e) ->
            if e or e2
              return res.json error: 'db_error', data: if e2 then e2 else e
            else
              return res.json done: 'added_report', data: r



  ## TODO: /editReport, /deleteReport,
  ##       /voidPerson, /editPerson, /changeEmail,
  ##       /changeName, /changeACL, /changeBio,
  ##       /voidUser, PRAGMA foreign_keys = ON


# APP

  app.use '/auth', auth

  app.use '/api/app', appAPI
  app.use '/api/auth', authAPI

  app.use '/static', express.static 'public'

  app.get '/', auth.manageRedirect, (req, res) ->
    res.render 'app.jade', user: req.session.user

  app.listen process.env.PORT || 80