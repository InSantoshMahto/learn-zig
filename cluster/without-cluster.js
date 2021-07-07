// @ts-check
'use strict'
import { createServer } from 'http'

const PORT = process.env.PORT || 3000
createServer((req, res) => {
  for (let i = 0; i < 10e6; i++) {
    //
  }
  res.writeHead(200)
  res.end('Hey NodeJS !\n')
}).listen(PORT)
