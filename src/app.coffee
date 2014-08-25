request = require('request')
express = require('express')
bodyParser = require('body-parser')
cookieParser = require('cookie-parser')
path = require('path')
passport = require('./passport')
config = require('./config')
fs = require('fs')

calculator = require("./routes/calculator")
sessions = require("./routes/sessions")(passport)
transactions = require("./routes/transactions")
users = require("./routes/users")(sessions)

session = require('express-session')
RedisStore = require('connect-redis')(session)
sessionStore = new RedisStore(require('./redis').host, ttl: 172800)

app = express()
app.enable('trust proxy')
app.engine('html', require('hogan-express'))
app.set('view engine', 'html')
app.set('views', __dirname + '/views')
app.use(express.static(__dirname + '/public'))
app.use(bodyParser.urlencoded({ extended: true}))
app.use(bodyParser.json())
app.use(bodyParser.json({ type: 'application/vnd.api+json' }))
app.use(cookieParser(config.secret))
app.use(session(resave: true, saveUninitialized: true, secret: config.secret, store: sessionStore, cookie: { maxAge: 1209600000 }, key: 'vanbtc.sid'))
app.use(passport.initialize())
app.use(passport.session())

authorize = (req, res, next) ->
  if req.params.user is req.user?.username or
    req.user?.username is 'admin'
      return next() 

  req.session.redirect = req.path
  res.redirect('/login')

cache = (req, res, next) ->
  unless req.path is '/login'
    res.setHeader "Cache-Control", "public, max-age=900"
  next()

fetchRates = ->
  file = 'public/js/rates.json'
  fs.truncate(file, 0, ->
    stream = fs.createWriteStream(file)

    r = request("https://api.bitcoinaverage.com/exchanges/all")
    r.on('data', (chunk) ->
      stream.write(chunk)
    )
    r.on('error', (error) ->
      console.log(error)
    )
  )

  setTimeout(fetchRates, 120000)
fetchRates()

app.get('/', cache, sessions.new)
app.get('/register', cache, users.new)
app.get('/ticker', cache, calculator.ticker)
app.get('/sweep', calculator.sweep)

app.get('/login', cache, sessions.new)
app.post('/login', sessions.create)
app.get('/logout', sessions.destroy)

app.get('/users/new', cache, users.new)
app.post('/users', users.create)

app.get('/:user/edit', authorize, users.edit)
app.post('/:user', authorize, users.update)

app.get('/:user/transactions.json', authorize, transactions.json)
app.post('/:user/transactions', transactions.create)
app.post('/transactions/:txid', transactions.update)
app.delete('/:user/transactions/:txid', transactions.delete)
app.get('/:user/report', authorize, transactions.index)

app.get('/:user.json', users.json)
app.get('/:user', cache, users.show)

app.use(require('connect-assets')(src: 'public'))

app.use((err, req, res, next) ->
  res.status(500)
  res.send('An error occurred');
  console.error(err.stack)
  res.end()
)

app.listen(3000)