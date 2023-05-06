import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import pkg from './package.json' assert {type: 'json'};

export default [

	{
		input: {
			"index.d": '.local/out-tsc',
			"index": 'chaintrap/erc2535proxy.js'
		},
		output: {
			dir: 'dist'
		},
		plugins: [
			resolve({preferBuiltins:true}), // so Rollup can find `ms`
			commonjs() // so Rollup can convert `ms` to an ES module
		]
	},

	// browser-friendly UMD build
	{
		input: 'chaintrap/chaintrap.js',
		output: {
			name: 'chaintrap',
			file: pkg.browser,
			format: 'umd'
		},
		plugins: [
			resolve({preferBuiltins:true}), // so Rollup can find `ms`
			commonjs() // so Rollup can convert `ms` to an ES module
		]
	},

	// CommonJS (for Node) and ES module (for bundlers) build.
	// (We could have three entries in the configuration array
	// instead of two, but it's quicker to generate multiple
	// builds from a single configuration where possible, using
	// an array for the `output` option, where we can specify
	// `file` and `format` for each target)
	{
		input: 'chaintrap/chaintrap.js',
		external: ['ms'],
		output: [
			{ file: pkg.main, format: 'cjs' },
			{ file: pkg.module, format: 'es' }
		],
		plugins: [
			resolve({preferBuiltins:true}), // so Rollup can find `ms`
			commonjs() // so Rollup can convert `ms` to an ES module
		]
	}
];