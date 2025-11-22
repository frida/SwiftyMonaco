const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const path = require('path');

module.exports = {
    entry: './src/index.js',
    devtool: 'source-map',
    output: {
        path: path.resolve(__dirname, '../Sources/SwiftyMonaco/_Resources'),
        filename: 'app.js',
        publicPath: ''
    },
    module: {
        rules: [
            {
                test: /\.css$/,
                use: [
                    'style-loader',
                    'css-loader'
                ]
            },
            {
                test: /\.ttf$/,
                use: ['file-loader']
            },
            {
                test: /\.worker\.js$/,
                loader: 'worker-loader',
                options: {
                    inline: 'no-fallback'
                },
            },
        ]
    },
    plugins: [
        new CleanWebpackPlugin(),
        new HtmlWebpackPlugin({
            title: 'Text Editor'
        })
    ]
};
