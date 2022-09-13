const { environment } = require('@rails/webpacker');

// This file is effectively the same as what you'd normally have
// inside webpack.config.js for a Node project.
//
// See also https://webpack.js.org/configuration/

// Ignore JS test files.
environment.loaders.append('ignore', {
  test: /\.test\.js$/,
  loader: 'ignore-loader',
});

environment.loaders.delete('nodeModules');

module.exports = environment;
