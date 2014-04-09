
############################### Settings ##############################
queueNameFilter = /nigiri.server.message/i
apiPath = 'http://illum-qa-india:15672/api/'
intervalSeconds = 5
startAtCountLessThan = 100
stopAtCountGreaterThan = 116
#######################################################################


rest = require 'rest/'
pathPrefix = require 'rest/interceptor/pathPrefix'
errorCode = require 'rest/interceptor/errorCode'
mime = require 'rest/interceptor/mime'
basicAuth = require 'rest/interceptor/basicAuth'
service = "wuauserv"

serviceAlreadyRunning = 1056
serviceNotBeenStarted = 1062


client = rest.chain mime
             .chain errorCode, { code: 500 }
             .chain pathPrefix, { prefix: apiPath }
             .chain basicAuth, { username: 'guest', password: 'guest' };

handler = (idx, callback) ->
  (res) ->
    ct = 0
    ct += q.backing_queue_status.persistent_count for q in res.entity when queueNameFilter.test q.name
    console.log "At #{new Date()} #{q.vhost}/#{q.name}: #{q.backing_queue_status.persistent_count}    " for q in res.entity when queueNameFilter.test(q.name) and q.backing_queue_status.persistent_count
    callback null, ct

setCount = (ct) ->
  if ct < startAtCountLessThan
    ensureRunning ct
  if ct > stopAtCountGreaterThan
    ensureStopped ct

ensureRunning = (ct) ->
  console.log "  Start #{service} if it's not already running.  ct=" + ct
  runProcess "sc start #{service}", [serviceAlreadyRunning]

ensureStopped = (ct) ->
  console.log "  Stop #{service} if it's running.  ct=" + ct
  runProcess "sc stop #{service}", [serviceNotBeenStarted]

checkCount = () ->
  client(path:'queues').then handler("first", (err, ct) -> setCount ct)

runProcess = (command, ignoredStatuses) ->
  terminal = require('child_process').exec command
  exited = false
  output = ""

  terminal.stdout.on 'data',  (data) ->
    output += data

  terminal.on 'exit', (code) ->
    if -1 == ignoredStatuses.indexOf code
      console.log '     ' + output.replace /\r\n/g, ' '
      console.log '    child process exited with code ' + code
    exited = false



console.log "======================================================="
console.log "Monitoring #{queueNameFilter} on #{apiPath}"
console.log "  every #{intervalSeconds} seconds"
console.log "======================================================="
console.log "    Note: This must be run with elevated priviliges"
console.log "======================================================="

setInterval checkCount, intervalSeconds * 1000
