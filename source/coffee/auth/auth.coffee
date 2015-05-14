class Login
  model:
    state: m.prop 'Eml'
    enabled: m.prop true
    navigating: m.prop false

    pEml: m.prop ''
    pKey: m.prop ''
    pSP2: m.prop ''

    pNom: m.prop ''
    pRol: m.prop ''
    pBio: m.prop ''

    vLgd: m.prop ''

  ani: (s2) =>
    m.redraw.strategy 'none'

    targets = document.getElementById('mroot').querySelectorAll('[data-state]')
    i = targets.length
    
    for e in targets
      if e.getAttribute('data-state').indexOf(s2) is -1 or
        e.getAttribute('data-state').indexOf("!#{s2}") is -1
          Velocity e, 'slideUp', complete: =>
            if --i is 0
              @model.state s2
              m.redraw true
              return false
      else
        --i

    if i is 0
      @model.state s2
      m.redraw true
      
    return
    
  home: (e) =>
    if e
      e.preventDefault()
    
    @model.vLgd ''
    @ani 'Eml'
    return false
    
  man: (e) =>
    if e
      e.preventDefault()

    if (not e or not e.target.checkValidity or e.target.checkValidity()) and not @model.navigating()
      url = ''
      data = {}

      switch @model.state()
        when 'Eml'
          url   = 'api/auth/getKey'
          data  =
            email:  @model.pEml()
          if @model.pSP2() isnt ''
            data.pass2 = @model.pSP2()
          cbs   = =>
            @model.vLgd 'Check your inbox for your key'
            @ani 'Key'
            @model.enabled true
            return

        when 'Key'
          url   = 'api/auth/withKey'
          data  =
            email:  @model.pEml()
            key:    @model.pKey()
          cbs   = =>
            @model.vLgd 'Your key was accepted'
            @model.navigating true
            window.location.href = '/'
            return

        when 'SP2'
          url   = 'api/auth/withPass'
          data  =
            email:  @model.pEml()
            pass:   @model.pSP2()
          cbs   = =>
            @ani 'Eml'
            @man()
            return

        when 'Reg'
          url   = 'api/auth/register'
          data  =
            email:  @model.pEml()
            name:   @model.pNom()
            role:   @model.pRol()
            bio:    @model.pBio()
          cbs   = =>
            @model.vLgd 'Success! You will receive an email when your details have been verified'
            @ani 'Eml'
            @model.enabled true
            return
            
        else
          throw 'BAD_ROUTE'

      @model.enabled false
      m.redraw true
  
      m.request
        method: 'post'
        url: url
        data: data
      .then (res) =>
        if res.error
          switch res.error
            when 'unregistered'
              @model.vLgd 'Do you mind telling us some more about you?'
              @ani 'Reg'
            when 'password_required'
              @model.vLgd 'Accessing your account requires your password'
              @ani 'SP2'
            else
              @model.vLgd "There was an error: <strong>#{res.error}<strong> #{JSON.stringify(res.data) if res.data}"
          @model.enabled true
        else
          cbs()
  
      if e
        return false
    
      return
  
  acg: (e, init, c) =>
    if not init
      e.style.overflow = 'hidden'
      Velocity e, 'slideDown', complete: ->
        e.style.overflow = 'visible'
      
    return

  controller: =>
    if window.glob
      if window.glob.i and window.glob.key
        @ani 'Key'
        @model.pEml window.glob.i
        @model.pKey window.glob.key
        delete window.glob.i
        delete window.glob.key
        if history then history.pushState null, null, window.location.href.slice 0, window.location.href.indexOf '?'
        
        @man()
    
      if window.glob.message
        @model.vLgd window.glob.message

    return m: @model

  view: (c) =>
    m 'form[autocomplete="off"]', onsubmit: @man,
      if not c.m.enabled()
        m '.spinp',
          m 'svg.spinner[viewBox="0 0 16 16"]',
            m 'title', 'Loading'
            m 'circle.path[cx="8"][cy="8"][r="7"]'
    
      m 'legend', m.trust c.m.vLgd()

      m 'input[type="email"][placeholder="EMAIL ADDRESS"][autofocus]',
        oninput: m.withAttr 'value', c.m.pEml
        disabled: not c.m.enabled() or c.m.state() isnt 'Eml'
        value: c.m.pEml()

      if c.m.state() is 'Key'
        m 'fieldset[data-state="Key"]', config: @acg,
          m 'input[type="text"][minlength="6"][maxlength="6"][autofocus]',
            disabled: not c.m.enabled()
            oninput: m.withAttr 'value', c.m.pKey
            value: c.m.pKey()

      if c.m.state() is 'SP2'
        m 'fieldset[data-state="SP2"]', config: @acg,
          m 'input[type="password"][placeholder="PASSWORD"][autofocus]',
            disabled: not c.m.enabled()
            oninput: m.withAttr 'value', c.m.pSP2
            value: c.m.pSP2()

      if c.m.state() is 'Reg'
        m 'fieldset[data-state="Reg"]', config: @acg,
          m 'input[type="text"][placeholder="NAME"][autofocus]',
            disabled: not c.m.enabled()
            oninput: m.withAttr 'value', c.m.pNom
            value: c.m.pNom()

          m 'select', 
            onchange: m.withAttr('value', c.m.pRol)
            disabled: not c.m.enabled()
            
            m 'optgroup', 'PERMISSIONS'
            for v in window.glob.roles
              m 'option', v

          m 'textarea[placeholder="BIO"]',
            disabled: not c.m.enabled()
            oninput: m.withAttr 'value', c.m.pBio
            value: c.m.pBio()
            
      m 'button[type="submit"]', disabled: not c.m.enabled(), 'SUBMIT'
        
      if c.m.state() isnt 'Eml'
        m 'button.small[data-state="!Eml"]', disabled: not c.m.enabled(), onclick: @home, 'CANCEL'

m.mount document.getElementById('mroot'), new Login