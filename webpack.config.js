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
    user_search: path.resolve(__dirname, 'assets', 'js', 'user_search.js'),
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
            presets: [
              '@babel/preset-env',
              [
                '@babel/preset-react',
                {
                  pragma: "h",
                  pragmaFrag: "h",
                  runtime: "classic",
                }
              ],
            ]
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
      }),
    ],
  },
}

module.exports = config
