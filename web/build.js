import esbuild from 'esbuild';
import inlineWorkerPlugin from 'esbuild-plugin-inline-worker';

const outFile = new URL('../Sources/SwiftyMonaco/_Resources/app.js', import.meta.url).pathname;
const isDev = process.env.NODE_ENV === 'development';
const isWatch = process.argv.includes('--watch');

const target = ['safari18'];

const optimizationOpts = {
  sourcemap: isDev ? 'inline' : false,
  minify: !isDev,
  legalComments: 'none',
};

const commonConfig = {
  bundle: true,
  outfile: outFile,
  format: 'iife',
  entryPoints: ['./src/index.js'],
  loader: {
    '.ttf': 'file',
  },
  target,
  ...optimizationOpts,
  plugins: [
    inlineWorkerPlugin({
      format: 'iife',
      target,
      ...optimizationOpts,
    }),
  ],
};

async function build() {
  if (isWatch) {
    const ctx = await esbuild.context(commonConfig);
    await ctx.watch();
    console.log('👀 Watching for changes...');
  } else {
    await esbuild.build(commonConfig);
    console.log(isDev ? '✅ Dev build complete (sourcemaps, not minified)' : '✅ Production build complete');
  }
}

build().catch((err) => {
  console.error('❌ Build failed:');
  console.error(err);
  process.exit(1);
});
