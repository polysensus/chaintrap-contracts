import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import pkg from './package.json' assert {type: 'json'};

const externalxx = ["ms", "ethers", "ethereum-cryptography"];

export default [

	// CommonJS (for Node) and ES module (for bundlers) build.
	// (We could have three entries in the configuration array
	// instead of two, but it's quicker to generate multiple
	// builds from a single configuration where possible, using
	// an array for the `output` option, where we can specify
	// `file` and `format` for each target)
	{
		input: 'chaintrap/chaintrap.js',
		external: externalxx,
		output: [
			{ file: pkg.main, format: 'es' },
			{ file: pkg.module, format: 'es' }
		],
		plugins: [
			resolve({preferBuiltins:true}), // so Rollup can find `ms`
			commonjs() // so Rollup can convert `ms` to an ES module
		]
	}
];