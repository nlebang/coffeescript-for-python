fs = require 'fs'
path = require 'path'
child_process = require 'child_process'
CoffeeScript = require 'coffeescript'

dir = path.join __dirname, '..'
ext = '.md'

detick = (x) ->
  x.replace /^```.*\n/, ''
  .replace /[ ]*```$/, ''
oneLine = (x) ->
  x.replace /\n/g, '\\n'
indent = (x) ->
  x.replace /^|\n/g, '$&  '

files = (file for file in fs.readdirSync dir when file.endsWith ext)
for file in files
  md = fs.readFileSync (path.join dir, file), encoding: 'utf8'

  describe "CoffeeScript examples in #{file}", ->
    pattern = /```coffee[^]*?```/g
    while match = pattern.exec md
      cs = detick match[0]
      .replace /(\n\s*)\.\.\.(\s*\n)/g, '$1codeBlock$2'

      do (cs) ->
        test "Compiles: #{oneLine cs}", ->
          expect(CoffeeScript.compile cs)
          .toBeTruthy()

  describe "Python examples in #{file}", ->
    pattern = /```py[^]*?```/g
    while match = pattern.exec md
      py = detick match[0]
      .replace /\.\.\./g, 'pass'

      do (py) ->
        version = if py.match /print [^(]/ then 2 else 3
        describe "Compiles: #{oneLine py}", ->
          lines = py.split '\n'
          lines.push [''] # to force wrap-up
          group = []
          quotes = false
          quoteRe = /'''|"""/g
          for line, i in lines
            ## Always wrap-up on last line; otherwise continue when within
            ## quotes, on any indented line, and on except/finally/else/elif.
            if i < lines.length-1 and \
               (quotes or line.match /^( |except|finally|else|elif)/)
              group.push line
            else
              if group.length
                code = group.join('\n') + '\n'

                ## Handle abstract code blocks that need surrounding loop/def
                if code.match(/break|continue/) and not code.match /for|while/
                  code = 'while True:\n' + indent code
                if code.match(/return/) and not code.match /def/
                  code = 'def function():\n' + indent code

                arg = (code + '\n')
                .replace /[\\']/g, "\\$&"
                .replace /\n/g, "\\n"
                do (code, arg) ->
                  test "Compiles: #{oneLine code}", ->
                    python = child_process.spawnSync "python#{version}", [
                      '-c'
                      """
                        import codeop
                        if None is codeop.compile_command('#{arg}'):
                          raise RuntimeError('incomplete code')
                      """
                    ],
                      stdio: [null, null, 'pipe']
                    stderr = python.stderr.toString 'utf8'
                    #console.log "'#{arg}'" if stderr
                    expect(stderr).toBe('')
              group = []
              group.push line if line
            ## In either case, we pushed line to group (or line == '').
            ## Check for any quotes which will keep us in a group longer.
            while quoteRe.exec line
              quotes = not quotes
          undefined
