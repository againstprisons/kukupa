const webpack = require('webpack')
const path = require('path')
const TerserPlugin = require('terser-webpack-plugin');

const config = {
  devtool: 'source-map',
  target: 'web',
  mode: 'production',

  entry: {
    index: path.resolve(__dirname, 'assets', 'js', 'index.js'),
    editor: path.resolve(__dirname, 'assets', 'js', 'editor.js'),
  },
 
  output: {
    path: path.resolve(__dirname, 'public'),
    filename: '[name].bundle.js'
  },

  module: {
    rules: [
      {
        test: /\.m?js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env']
          }
        }
      }
    ]
  },

  resolve: {
    modules: [
      path.resolve(__dirname, 'assets', 'js'),
      'node_modules',
    ],

    extensions: ['.mjs', '.js', '.json'],
  },

  optimization: {
    minimizer: [
      new TerserPlugin({
        parallel: true,
        sourceMap: true,
      }),
    ],
  },
}

module.exports = config
