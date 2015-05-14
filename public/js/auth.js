(function() {
  var Login,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Login = (function() {
    function Login() {
      this.view = bind(this.view, this);
      this.controller = bind(this.controller, this);
      this.acg = bind(this.acg, this);
      this.man = bind(this.man, this);
      this.home = bind(this.home, this);
      this.ani = bind(this.ani, this);
    }

    Login.prototype.model = {
      state: m.prop('Eml'),
      enabled: m.prop(true),
      pEml: m.prop(''),
      pKey: m.prop(''),
      pSP2: m.prop(''),
      pNom: m.prop(''),
      pRol: m.prop(''),
      pBio: m.prop(''),
      vLgd: m.prop('')
    };

    Login.prototype.ani = function(s2) {
      var e, i, j, len, targets;
      m.redraw.strategy('none');
      targets = document.getElementById('mroot').querySelectorAll('[data-state]');
      i = targets.length;
      for (j = 0, len = targets.length; j < len; j++) {
        e = targets[j];
        if (e.getAttribute('data-state').indexOf(s2) === -1 || e.getAttribute('data-state').indexOf("!" + s2) === -1) {
          Velocity(e, 'slideUp', {
            complete: (function(_this) {
              return function() {
                if (--i === 0) {
                  _this.model.state(s2);
                  m.redraw();
                  return false;
                }
              };
            })(this)
          });
        } else {
          --i;
        }
      }
      if (i === 0) {
        this.model.state(s2);
        m.redraw();
      }
    };

    Login.prototype.home = function(e) {
      if (e) {
        e.preventDefault();
      }
      this.model.vLgd('');
      this.ani('Eml');
      return false;
    };

    Login.prototype.man = function(e) {
      var cbs, data, url;
      if (e) {
        e.preventDefault();
      }
      if (!e || !e.target.checkValidity || e.target.checkValidity()) {
        url = '';
        data = {};
        switch (this.model.state()) {
          case 'Eml':
            url = 'api/auth/getKey';
            data = {
              email: this.model.pEml()
            };
            if (this.model.pSP2() !== '') {
              data.pass2 = this.model.pSP2();
            }
            cbs = (function(_this) {
              return function() {
                _this.model.vLgd('Check your inbox for your key');
                _this.ani('Key');
                _this.model.enabled(true);
              };
            })(this);
            break;
          case 'Key':
            url = 'api/auth/withKey';
            data = {
              email: this.model.pEml(),
              key: this.model.pKey()
            };
            cbs = (function(_this) {
              return function() {
                _this.model.vLgd('Your key was accepted');
                window.location.href = '';
              };
            })(this);
            break;
          case 'SP2':
            url = 'api/auth/withPass';
            data = {
              email: this.model.pEml(),
              pass: this.model.pSP2()
            };
            cbs = (function(_this) {
              return function() {
                _this.ani('Eml');
                _this.man();
              };
            })(this);
            break;
          case 'Reg':
            url = 'api/auth/register';
            data = {
              email: this.model.pEml(),
              name: this.model.pNom(),
              role: this.model.pRol(),
              bio: this.model.pBio()
            };
            cbs = (function(_this) {
              return function() {
                _this.model.vLgd('Success! You will receive an email when your details have been verified');
              };
            })(this);
            break;
          default:
            throw 'BAD_ROUTE';
        }
        this.model.enabled(false);
        m.redraw();
        m.request({
          method: 'post',
          url: url,
          data: data
        }).then((function(_this) {
          return function(res) {
            if (res.error) {
              switch (res.error) {
                case 'unregistered':
                  _this.model.vLgd('Do you mind telling us some more about you?');
                  _this.ani('Reg');
                  break;
                case 'password_required':
                  _this.model.vLgd('Accessing your account requires your password');
                  _this.ani('SP2');
                  break;
                default:
                  _this.model.vLgd("There was an error: <strong>" + res.error + "<strong> " + (JSON.stringify(res.data)));
              }
              return _this.model.enabled(true);
            } else {
              return cbs();
            }
          };
        })(this));
        if (e) {
          return false;
        }
      }
    };

    Login.prototype.acg = function(e, init, c) {
      if (!init) {
        e.style.overflow = 'hidden';
        Velocity(e, 'slideDown', {
          complete: function() {
            return e.style.overflow = 'visible';
          }
        });
      }
    };

    Login.prototype.controller = function() {
      if (window.glob) {
        if (window.glob.i && window.glob.key) {
          this.ani('Key');
          this.model.pEml(window.glob.i);
          this.model.pKey(window.glob.key);
          delete window.glob.i;
          delete window.glob.key;
          this.man();
        }
        if (window.glob.message) {
          this.model.vLgd(window.glob.message);
        }
      }
      return {
        m: this.model
      };
    };

    Login.prototype.view = function(c) {
      var v;
      return m('form', {
        onsubmit: this.man
      }, !c.m.enabled() ? m('.spinp', m('svg.spinner[viewBox="0 0 16 16"]', m('title', 'Loading'), m('circle.path[cx="8"][cy="8"][r="7"]'))) : void 0, m('legend', m.trust(c.m.vLgd())), m('input[type="email"][placeholder="EMAIL ADDRESS"]', {
        oninput: m.withAttr('value', c.m.pEml),
        disabled: c.m.state() !== 'Eml',
        value: c.m.pEml()
      }), c.m.state() === 'Key' ? m('fieldset[data-state="Key"]', {
        config: this.acg
      }, m('input[type="text"][minlength="6"][maxlength="6"]', {
        oninput: m.withAttr('value', c.m.pKey),
        value: c.m.pKey()
      })) : void 0, c.m.state() === 'SP2' ? m('fieldset[data-state="SP2"]', {
        config: this.acg
      }, m('input[type="password"][placeholder="PASSWORD"]', {
        oninput: m.withAttr('value', c.m.pSP2),
        value: c.m.pSP2()
      })) : void 0, c.m.state() === 'Reg' ? m('fieldset[data-state="Reg"]', {
        config: this.acg
      }, m('input[type="text"][placeholder="NAME"]', {
        oninput: m.withAttr('value', c.m.pNom),
        value: c.m.pNom()
      }), m('select', {
        onchange: m.withAttr('value', c.m.pRol)
      }, m('optgroup', 'PERMISSIONS'), (function() {
        var j, len, ref, results;
        ref = window.glob.roles;
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          v = ref[j];
          results.push(m('option', v));
        }
        return results;
      })()), m('textarea[placeholder="BIO"]', {
        oninput: m.withAttr('value', c.m.pBio),
        value: c.m.pBio()
      })) : void 0, m('button[type="submit"]', {
        disabled: !c.m.enabled()
      }, 'SUBMIT'), c.m.state() !== 'Eml' ? m('button.small[data-state="!Eml"]', {
        disabled: !c.m.enabled(),
        onclick: this.home
      }, 'CANCEL') : void 0);
    };

    return Login;

  })();

  m.mount(document.getElementById('mroot'), new Login);

}).call(this);
