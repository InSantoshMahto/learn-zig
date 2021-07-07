// @ts-check
'use strict'
import cluster from 'cluster'
import http from 'http'
import os from 'os'

const numCPUs = os.cpus().length
const PORT = process.env.PORT || 3000

if (cluster.isPrimary) {
  console.log('No. of CPU Core:- ', numCPUs)
  console.log(`Primary ${process.pid} is running`)

  // Fork workers.
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork()
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`worker ${worker.process.pid} died`, code, signal)
  })
} else {
  // Workers can share any TCP connection
  // In this case it is an HTTP server
  http.createServer(async (req, res) => {
    for (let i = 0; i < 10e6; i++) {
      //
    }
    res.writeHead(200)
    res.end('Hey NodeJS !\n')
  }).listen(PORT)
  console.log(`Worker ${process.pid} started`)
}
