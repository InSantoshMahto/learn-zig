// @ts-nocheck
import cluster from 'cluster'
import http from 'http'
import os from 'os'

if (cluster.isPrimary) {
  // Keep track of http requests
  let numReqs = 0
  setInterval(() => {
    console.log(`numReqs = ${numReqs}`)
  }, 1000)

  // Count requests
  function messageHandler(msg) {
    if (msg.cmd && msg.cmd === 'notifyRequest') {
      numReqs += 1
    }
  }

  // Start workers and listen for messages containing notifyRequest
  const numCPUs = os.cpus().length
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork()
  }

  for (const id in cluster.workers) {
    cluster.workers[id].on('message', messageHandler)
  }
} else {
  // Worker processes have a http server.
  http.Server((_req, res) => {
    res.writeHead(200)
    res.end('hello world\n')

    // Notify primary about the request
    process.send({ cmd: 'notifyRequest' })
  }).listen(3000)
}
