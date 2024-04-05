import typescript from "@rollup/plugin-typescript";
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import pkg from './package.json' assert {type: 'json'};

// The parts of ethers that are problematic appear to tree shaken out, hence no
// externals here

export default [

	// CommonJS (for Node) and ES module (for bundlers) build.
	// (We could have three entries in the configuration array
	// instead of two, but it's quicker to generate multiple
	// builds from a single configuration where possible, using
	// an array for the `output` option, where we can specify
	// `file` and `format` for each target)
	{
		input: 'chaintrap/chaintrap.ts',
		output: [
			{ file: pkg.module, format: 'commonjs' }
		],
		plugins: [
      // the output can be commonjs, provided we let the typescript plugin work
      // with es
      typescript({module: "esnext"}),
      commonjs()
		]
	}
];
