const cluster = require('cluster');
const http = require('http');
const os = require('os');

const NUM_CPUs = os.cpus().length;
const PORT = process.env.NODE_ENV || 3000;


if (cluster.isMaster) {
  console.log(`No. of CPU Core:- `, NUM_CPUs);
  console.log(`Master ${process.pid} is running`);

  // Fork workers.
  for (let i = 0; i < NUM_CPUs; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker, code, signal) => {
    console.log(`worker ${worker.process.pid} died`, code, signal);
  });
} else {
  // Workers can share any TCP connection
  // In this case it is an HTTP server
  http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.writeHead(200);
    res.end(JSON.stringify({
      message: 'Hey NodeJS !\n', data: {
        pid: process.pid,
        platform: process.platform,
        cpuUsage: process.cpuUsage()
      }
    }));
  }).listen(PORT);

  console.log(`Worker ${process.pid} started`);
}