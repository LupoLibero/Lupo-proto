module.exports = [
  {from: '/js/*',              to: 'static/js/*'},
  {from: '/images/*',          to: 'static/images/*'},
  {from: '/css/*',             to: 'static/css/*'},
  {from: '/fonts/*',           to: 'static/fonts/*'},
  {from: '/partials/*',        to: 'partials/*'},
  {from: '/vendor/*',          to: 'static/vendor/*'},
  {from: '/favicon.ico',       to: 'static/images/favicon.ico'},
  {from: '/',                  to: 'partials/index.html'},
  {from: '/index.html',        to: 'partials/index.html'},
  {from: '/get/:id',           to: '../../:id'},
  {from: '/:db/:id',               to: '../../../:db'},
  {from: '/:db/*',             to: '../../../:db/*'},
]
